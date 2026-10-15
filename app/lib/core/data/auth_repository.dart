import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

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

  Future<void> signOut() => _auth.signOut();

  /// O perfil existe? Se não, a pessoa criou a conta mas ainda não completou o perfil.
  Future<bool> hasProfile(String uid) async {
    final snap = await _firestore.doc('users/$uid').get();
    return snap.exists;
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
        return const AuthFailure('Use uma senha com pelo menos 6 caracteres.', field: 'password');
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
