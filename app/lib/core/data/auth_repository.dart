import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:clippo/core/data/user_profile.dart';
import 'package:clippo/core/firebase/firebase_setup.dart';
import 'package:clippo/core/validation/input_validation.dart';

/// Erro com uma mensagem pronta para mostrar na tela.
/// [field] diz qual campo do formulário marcar, quando houver
/// ([credentialsField] quando o erro vale para e-mail e senha juntos).
class AuthFailure implements Exception {
  static const String credentialsField = 'credentials';

  const AuthFailure(this.message, {this.field});

  final String message;
  final String? field;

  @override
  String toString() => message;
}

/// Tudo o que o app faz com conta e perfil passa por aqui.
///
/// As telas não falam direto com o Firebase: chamam estes métodos. Assim, quem mexe
/// numa tela não precisa saber como o Firebase funciona, e a regra fica num lugar só.
///
/// Todo método que envia dados valida antes (core/validation/input_validation.dart) e
/// lança [AuthFailure] sem chamar o Firebase se algo não passar. O servidor valida de novo.
class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: functionsRegion),
        _storage = (() => storage ?? FirebaseStorage.instance);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  /// O Storage só é aberto quando a foto sobe (os testes do login não precisam dele).
  final FirebaseStorage Function() _storage;

  /// Troca a foto do perfil: valida (tipo e tamanho, as regras do servidor), envia para
  /// `users/{uid}/avatar` no Storage e chama a Function setProfilePhoto, que grava o endereço no
  /// perfil e nas cópias. Devolve o endereço novo. [watchMyProfile] emite o perfil novo sozinho.
  Future<String?> setProfilePhoto(File file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthFailure('Entre na sua conta para trocar a foto.');
    final contentType = profilePhotoContentType(file.path);
    _check('photo', validateProfilePhoto(await file.length(), contentType));
    try {
      await _storage()
          .ref('users/$uid/avatar')
          .putFile(file, SettableMetadata(contentType: contentType));
    } on FirebaseException catch (e) {
      throw AuthFailure(
        e.code == 'unauthorized'
            ? 'Não foi possível enviar a foto. Use JPEG ou PNG de até 2 MB.'
            : 'Não foi possível enviar a foto. Confira a internet e tente de novo.',
        field: 'photo',
      );
    }
    final data = await _callPhoto(const {});
    return data['photoUrl'] as String?;
  }

  /// Tira a foto do perfil (a Function apaga do Storage e volta para as iniciais).
  Future<void> removeProfilePhoto() => _callPhoto(const {'remove': true});

  Future<Map<String, dynamic>> _callPhoto(Map<String, dynamic> payload) async {
    try {
      final result = await _functions.httpsCallable('setProfilePhoto').call<Map<String, dynamic>>(payload);
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const AuthFailure('Sem conexão. Confira a internet e tente de novo.', field: 'photo');
      }
      throw AuthFailure(e.message ?? 'Não foi possível trocar a foto.', field: 'photo');
    }
  }

  /// Emite o usuário logado (ou null) sempre que entra ou sai alguém.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    _check('email', validateEmail(email));
    _check('password', validateExistingPassword(password));
    try {
      await _auth.signInWithEmailAndPassword(email: normalizeEmail(email), password: password);
    } on FirebaseAuthException catch (e) {
      throw _translateAuthError(e);
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    _check('email', validateEmail(email));
    _check('password', validateNewPassword(password));
    try {
      await _auth.createUserWithEmailAndPassword(email: normalizeEmail(email), password: password);
    } on FirebaseAuthException catch (e) {
      throw _translateAuthError(e);
    }
  }

  /// "Esqueci a senha": o Firebase Auth manda um e-mail com o link para criar outra senha.
  ///
  /// Não diz se existe conta com o e-mail (quem pergunta não deve descobrir quem tem conta):
  /// "conta não encontrada" termina igual a "enviado". 🟡 Fluxo mínimo; o texto do e-mail e a
  /// tela de nova senha são os padrões do Firebase (docs/arquitetura.md › Decisões em aberto).
  Future<void> sendPasswordReset({required String email}) async {
    _check('email', validateEmail(email));
    try {
      await _auth.sendPasswordResetEmail(email: normalizeEmail(email));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return;
      throw _translateAuthError(e);
    }
  }

  /// Exclui a conta e os dados da pessoa (Function deleteMyAccount, LGPD) e sai do app.
  ///
  /// Nada digitado vai junto: o servidor exclui quem chamou. Lança [AuthFailure] com a frase
  /// da tela (ex.: sessão juntada que ainda trava a exclusão).
  Future<void> deleteMyAccount() async {
    try {
      await _functions.httpsCallable('deleteMyAccount').call<Map<String, dynamic>>(<String, dynamic>{});
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const AuthFailure('Sem conexão. Confira a internet e tente de novo.');
      }
      throw AuthFailure(e.message ?? 'Não foi possível excluir a conta. Tente de novo.');
    }
    await _auth.signOut();
  }

  Future<void> signOut() => _auth.signOut();

  /// Quanto a abertura do app espera o servidor antes de usar o que está guardado no celular.
  static const Duration profileCheckTimeout = Duration(seconds: 6);

  /// O perfil existe? Se não, a pessoa criou a conta mas ainda não completou o perfil.
  ///
  /// Sem internet, não espera o Firestore desistir sozinho (a abertura ficava parada): depois de
  /// [profileCheckTimeout], usa o perfil guardado no celular. Sem nada guardado (primeira vez
  /// neste aparelho), lança [ProfileOfflineException] para a tela pedir internet.
  Future<bool> hasProfile(String uid) async {
    final ref = _firestore.doc('users/$uid');
    try {
      final snap = await ref.get().timeout(profileCheckTimeout);
      return snap.exists;
    } on Object catch (e) {
      if (e is! TimeoutException && !(e is FirebaseException && e.code == 'unavailable')) rethrow;
      try {
        final cached = await ref.get(const GetOptions(source: Source.cache));
        if (cached.exists) return true;
      } on FirebaseException {
        // Nada guardado: cai no aviso de sem internet.
      }
      throw const ProfileOfflineException();
    }
  }

  /// O @ já é de outra pessoa? Lê só `usernames/{@}` (um @ exato, como a busca de Amigos), para
  /// "Complete seu perfil" avisar ao sair do campo, antes de enviar. Quem decide de verdade é a
  /// Function, na transação: entre esta leitura e o envio, outra pessoa pode pegar o @.
  /// Sem internet ou erro na leitura: false (não trava a pessoa; o envio confere de novo).
  Future<bool> isUsernameTaken(String raw) async {
    _check('username', validateUsername(raw));
    try {
      final lock = await _firestore.doc('usernames/${normalizeUsername(raw)}').get();
      final owner = lock.data()?['uid'] as String?;
      return owner != null && owner != _auth.currentUser?.uid;
    } on FirebaseException {
      return false;
    }
  }

  /// O perfil público de quem está logado, atualizado sozinho quando mudar
  /// (a Início usa para a saudação e o avatar do topo).
  ///
  /// Emite null enquanto o perfil não existe — quem criou a conta e ainda não
  /// completou o perfil cai em "Complete seu perfil" pelo AuthGate.
  Stream<UserProfile?> watchMyProfile() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream<UserProfile?>.value(null);
    return _firestore.doc('users/$uid').snapshots().map(
          (snap) => snap.exists ? UserProfile.fromMap(snap.id, snap.data() ?? const {}) : null,
        );
  }

  /// Chama a Cloud Function completeProfile (backend/functions/src/users/completeProfile.ts).
  /// [birthDate] no formato AAAA-MM-DD.
  Future<void> completeProfile({
    required String name,
    required String username,
    required String birthDate,
  }) async {
    _check('name', validateName(name));
    _check('username', validateUsername(username));
    _check('birthDate', validateBirthDate(DateTime.tryParse(birthDate)));
    try {
      await _functions.httpsCallable('completeProfile').call<Map<String, dynamic>>({
        'name': normalizeName(name),
        'username': normalizeUsername(username),
        'birthDate': birthDate,
      });
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final field = details is Map ? details['field'] as String? : null;
      throw AuthFailure(e.message ?? 'Não foi possível salvar seu perfil.', field: field);
    }
  }

  /// Chama a Cloud Function updateProfile (backend/functions/src/users/updateProfile.ts)
  /// para mudar o nome e/ou o @usuário na tela Perfil. Campo null = não mudar.
  ///
  /// Valida aqui antes (mesmas regras e mensagens do servidor). Não precisa atualizar a
  /// tela depois: [watchMyProfile] emite o perfil novo sozinho.
  Future<void> updateProfile({String? name, String? username}) async {
    if (name == null && username == null) {
      throw const AuthFailure('Informe o nome ou o nome de usuário.', field: 'name');
    }
    if (name != null) _check('name', validateName(name));
    if (username != null) _check('username', validateUsername(username));
    try {
      await _functions.httpsCallable('updateProfile').call<Map<String, dynamic>>({
        if (name != null) 'name': normalizeName(name),
        if (username != null) 'username': normalizeUsername(username),
      });
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final field = details is Map ? details['field'] as String? : null;
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw AuthFailure('Sem conexão. Confira a internet e tente de novo.', field: field);
      }
      throw AuthFailure(e.message ?? 'Não foi possível salvar seu perfil.', field: field);
    }
  }

  /// Barra o envio quando a validação do app encontrou um erro.
  static void _check(String field, String? error) {
    if (error != null) throw AuthFailure(error, field: field);
  }

  AuthFailure _translateAuthError(FirebaseAuthException e) {
    // Recusa da função de bloqueio validateNewAccount (backend), que hoje só confere o e-mail.
    if (e.code.contains('blocking') || (e.message ?? '').contains('BLOCKING_FUNCTION')) {
      return const AuthFailure('Esse e-mail não parece válido.', field: 'email');
    }
    switch (e.code) {
      case 'invalid-email':
        return const AuthFailure('Esse e-mail não parece válido.', field: 'email');
      case 'email-already-in-use':
        return const AuthFailure('Já existe uma conta com esse e-mail. Tente entrar.', field: 'email');
      case 'weak-password':
        return const AuthFailure('Use uma senha com pelo menos 8 caracteres.', field: 'password');
      case 'password-does-not-meet-requirements':
        // Política de senha do Firebase Auth (PASSWORD_POLICY no backend).
        return const AuthFailure('Use letra maiúscula, minúscula e número na senha.', field: 'password');
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return const AuthFailure('E-mail ou senha incorretos.', field: AuthFailure.credentialsField);
      case 'too-many-requests':
        return const AuthFailure('Muitas tentativas. Espere um pouco e tente de novo.');
      case 'network-request-failed':
        return const AuthFailure('Sem conexão. Confira a internet e tente de novo.');
      default:
        return AuthFailure('Algo deu errado (${e.code}). Tente de novo.');
    }
  }
}

AuthRepository? _authRepository;

/// Instância única usada pelo app. Só acesse depois de setupFirebase() (main.dart).
/// Provisório até a área de front-end escolher o gerenciamento de estado.
AuthRepository get authRepository => _authRepository ??= AuthRepository();

/// Retorna `true` somente quando o Firebase está inicializado e há alguém logado.
/// Nos testes de widget ou no catálogo sem login, devolve `false` sem lançar erro.
/// Sem internet e sem o perfil guardado no celular: a abertura não tem como saber se a conta já
/// tem perfil. A tela pede para conectar (só acontece na primeira vez num aparelho).
class ProfileOfflineException implements Exception {
  const ProfileOfflineException();
}

bool get isUserSignedIn {
  try {
    return authRepository.currentUser != null;
  } catch (_) {
    return false;
  }
}
