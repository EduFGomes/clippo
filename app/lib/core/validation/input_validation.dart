/// Validação de tudo o que o usuário digita, antes de qualquer chamada ao Firebase.
///
/// Regra do projeto (AGENTS.md): nada vai para o Auth, o Firestore, o Storage ou uma
/// Cloud Function sem ser validado no app E no servidor. Estas são as regras do app; as do
/// servidor estão em backend/functions/src/users/validation.ts, com as MESMAS mensagens.
/// Mudou uma? Mude a outra no mesmo PR.
///
/// Cada `validate…` devolve a mensagem de erro pronta para a tela, ou null se está tudo certo.
/// Cada `normalize…` devolve o valor como deve ser enviado.
library;

const int emailMax = 254;
const int emailLocalMax = 64;
const int passwordMin = 6; // mínimo do Firebase Auth
const int passwordMax = 128;
const int nameMax = 50;
const int usernameMin = 3;
const int usernameMax = 20;

final RegExp _emailPattern =
    RegExp(r'^[a-z0-9._%+-]+@(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$');
final RegExp _usernamePattern = RegExp(r'^[a-z0-9._]+$');

/// Sem espaços nas pontas e em minúsculas.
String normalizeEmail(String raw) => raw.trim().toLowerCase();

/// Formato nome@dominio.tld. O Firebase Auth aceita "nome@g"; esta regra não.
String? validateEmail(String raw) {
  final email = normalizeEmail(raw);
  if (email.isEmpty) return 'Informe seu e-mail.';
  final local = email.split('@').first;
  final valid = email.length <= emailMax &&
      local.length <= emailLocalMax &&
      _emailPattern.hasMatch(email) &&
      !local.startsWith('.') &&
      !local.endsWith('.') &&
      !email.contains('..');
  return valid ? null : 'Esse e-mail não parece válido.';
}

/// Senha de quem está criando a conta.
String? validateNewPassword(String password) {
  if (password.isEmpty) return 'Informe a senha.';
  if (password.length < passwordMin) return 'Use uma senha com pelo menos $passwordMin caracteres.';
  if (password.length > passwordMax) return 'A senha pode ter até $passwordMax caracteres.';
  return null;
}

/// Senha de quem está entrando: só precisa estar preenchida.
String? validateExistingPassword(String password) => password.isEmpty ? 'Informe a senha.' : null;

String? validatePasswordConfirmation(String password, String confirmation) {
  if (confirmation.isEmpty) return 'Repita a senha.';
  return confirmation == password ? null : 'As senhas não são iguais.';
}

/// Tira espaços das pontas e junta espaços repetidos.
String normalizeName(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');

String? validateName(String raw) {
  final name = normalizeName(raw);
  if (name.isEmpty) return 'Informe seu nome.';
  if (name.length > nameMax) return 'O nome pode ter até $nameMax caracteres.';
  return null;
}

/// Sem "@", minúsculo, sem espaços nas pontas.
String normalizeUsername(String raw) => raw.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();

/// Letras a–z, números, "_" e "."; 3 a 20 caracteres; sem ponto no começo, no fim ou repetido.
String? validateUsername(String raw) {
  final username = normalizeUsername(raw);
  if (username.isEmpty) return 'Escolha um nome de usuário.';
  if (username.length < usernameMin || username.length > usernameMax) {
    return 'O nome de usuário precisa ter de $usernameMin a $usernameMax caracteres.';
  }
  if (!_usernamePattern.hasMatch(username)) return 'Use só letras sem acento, números, "_" e ".".';
  if (username.startsWith('.') || username.endsWith('.') || username.contains('..')) {
    return 'O ponto não pode ficar no começo, no fim ou repetido.';
  }
  return null;
}

/// Data de nascimento: obrigatória, de 1900 até hoje.
String? validateBirthDate(DateTime? date, {DateTime? today}) {
  if (date == null) return 'Informe a data de nascimento.';
  final now = today ?? DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  if (day.isAfter(DateTime(now.year, now.month, now.day)) || date.year < 1900) {
    return 'Data de nascimento inválida.';
  }
  return null;
}

// --- Sessão ----------------------------------------------------------------
// Espelho de backend/functions/src/sessions/validation.ts, com as MESMAS mensagens.
// São os campos que a pessoa confere na tela "Confirme a sessão" (produto.md › 4.5, estado D).

const int sessionNameMax = 50;
const int locationMax = 60;

/// Uma sessão não pode durar mais que isso: acima disso é erro de relógio, não jogo.
const int sessionMaxHours = 12;

/// Tira espaços das pontas e junta espaços repetidos.
String normalizeSessionName(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');

String? validateSessionName(String raw) {
  final name = normalizeSessionName(raw);
  if (name.isEmpty) return 'Dê um nome para a sessão.';
  if (name.length > sessionNameMax) {
    return 'O nome da sessão pode ter até $sessionNameMax caracteres.';
  }
  return null;
}

/// O local é opcional: sem GPS e sem digitar, a sessão fica sem local.
String? normalizeLocation(String? raw) {
  final label = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  return label.isEmpty ? null : label;
}

String? validateLocation(String? raw) {
  final label = normalizeLocation(raw);
  if (label == null) return null;
  if (label.length > locationMax) return 'O local pode ter até $locationMax caracteres.';
  return null;
}

/// Início e fim da gravação. O fim vem depois do início, a sessão não dura mais que
/// [sessionMaxHours] e nada termina no futuro (com 5 min de folga para o relógio adiantado).
String? validateSessionPeriod(DateTime? startedAt, DateTime? endedAt, {DateTime? now}) {
  if (startedAt == null || endedAt == null) return 'Confira a data e a hora da sessão.';
  if (!endedAt.isAfter(startedAt)) return 'O fim da sessão precisa vir depois do início.';
  if (endedAt.difference(startedAt).inSeconds > sessionMaxHours * 3600) {
    return 'Uma sessão pode durar até $sessionMaxHours horas.';
  }
  final limit = (now ?? DateTime.now()).add(const Duration(minutes: 5));
  if (endedAt.isAfter(limit)) return 'A sessão não pode terminar no futuro.';
  return null;
}
