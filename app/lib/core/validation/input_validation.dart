/// Validação de tudo o que o usuário digita, antes de qualquer chamada ao Firebase.
///
/// Regra do projeto (AGENTS.md): nada vai para o Auth, o Firestore, o Storage ou uma
/// Cloud Function sem ser validado no app E no servidor. Estas são as regras do app; as do
/// servidor estão em backend/functions/src/{users,sessions}/validation.ts, com as MESMAS mensagens.
/// Mudou uma? Mude a outra no mesmo PR.
///
/// Cada `validate…` devolve a mensagem de erro pronta para a tela, ou null se está tudo certo.
/// Cada `normalize…` devolve o valor como deve ser enviado.
library;

const int emailMax = 254;
const int emailLocalMax = 64;
// Senha nova (desde 10/11/2026): 8+ caracteres com maiúscula, minúscula e número. No servidor,
// a mesma regra é a política de senha do Firebase Auth (PASSWORD_POLICY em
// backend/functions/src/users/validation.ts): a senha nunca passa por uma Function.
const int passwordMin = 8;
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

/// O que falta na senha nova, na ordem em que a tela pede. Base do medidor e de
/// [validateNewPassword].
({bool length, bool upper, bool lower, bool number}) passwordChecks(String password) => (
      length: password.length >= passwordMin,
      upper: password.contains(RegExp(r'[A-Z]')),
      lower: password.contains(RegExp(r'[a-z]')),
      number: password.contains(RegExp(r'[0-9]')),
    );

/// Senha de quem está criando a conta: 8 a 128 caracteres, com maiúscula, minúscula e número.
String? validateNewPassword(String password) {
  if (password.isEmpty) return 'Informe a senha.';
  if (password.length > passwordMax) return 'A senha pode ter até $passwordMax caracteres.';
  final c = passwordChecks(password);
  if (!c.length) return 'Use uma senha com pelo menos $passwordMin caracteres.';
  if (!c.upper || !c.lower || !c.number) return 'Use letra maiúscula, minúscula e número na senha.';
  return null;
}

/// Senha de quem está entrando: só precisa estar preenchida. Quem criou a conta com a regra
/// antiga (6+ caracteres) continua entrando com a senha que tem.
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

/// A mesma frase do servidor (completeProfile / updateProfile) quando o @ já tem dono.
const String usernameTakenMessage = 'Esse nome de usuário já está em uso.';

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

final RegExp _birthDateTextPattern = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');

/// A data digitada como "dd/mm/aaaa", ou null se não for uma data de verdade (ex.: 31/02/2001
/// ou "12/03"). O servidor recebe a mesma data em AAAA-MM-DD ([birthDateIso]).
DateTime? parseBirthDateText(String raw) {
  final match = _birthDateTextPattern.firstMatch(raw.trim());
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  // DateTime "conserta" 31/02 para 03/03: se mudou, a data não existe.
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// Data de nascimento digitada (campo "dd/mm/aaaa" do Complete seu perfil). Mesmas mensagens
/// de [validateBirthDate] e do `normalizeBirthDate` do servidor.
String? validateBirthDateText(String raw, {DateTime? today}) {
  if (raw.trim().isEmpty) return 'Informe a data de nascimento.';
  final date = parseBirthDateText(raw);
  if (date == null) return 'Data de nascimento inválida.';
  return validateBirthDate(date, today: today);
}

/// AAAA-MM-DD, o formato que a Function completeProfile recebe.
String birthDateIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// --- Sessão ----------------------------------------------------------------
// Espelho de backend/functions/src/sessions/validation.ts, com as MESMAS mensagens.
// São os campos que a pessoa confere na tela "Confirme a sessão" (produto.md › 4.5, estado D).

const int sessionNameMax = 50;
const int locationMax = 60;
const int highlightTitleMax = 50;

/// Uma sessão não pode durar mais que isso: acima disso é erro de relógio, não jogo.
const int sessionMaxHours = 12;

/// Participantes por sessão, contando o dono (R9).
const int participantsMax = 30;

/// Teto por sessão, para uma chamada não gravar o dia inteiro de uma vez.
const int highlightsMax = 200;

/// Um highlight tem ~30 s (R1); 120 s é folga para mudanças futuras do buffer.
const int highlightSecondsMax = 120;

final RegExp _entityIdPattern = RegExp(r'^[A-Za-z0-9_-]{6,64}$');

/// Ids gerados pelo app (o mesmo id chegando duas vezes é a mesma sessão ou lance).
String? validateEntityId(String raw) {
  if (!_entityIdPattern.hasMatch(raw)) {
    return 'Não foi possível salvar a sessão. Tente de novo.';
  }
  return null;
}

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

/// Corrigir data e horário de uma sessão salva: os lances ficam no mesmo momento dentro dela, então
/// a nova duração vai até o último, com 1 minuto de folga. Mesma regra e frase do servidor
/// (`checkPeriodFitsHighlights` em backend/functions/src/sessions/validation.ts).
String? validatePeriodFitsHighlights(Duration duration, Iterable<Duration> offsets) {
  var last = Duration.zero;
  for (final offset in offsets) {
    if (offset > last) last = offset;
  }
  if (last.inSeconds > duration.inSeconds + 60) {
    return 'A sessão precisa durar até o último lance. Confira o horário do fim.';
  }
  return null;
}

/// Participantes: o dono entra sempre (R9), sem repetidos.
List<String> normalizeParticipantIds(List<String> raw, {String? ownerId}) {
  final unique = <String>{
    if (ownerId != null && ownerId.isNotEmpty) ownerId,
    ...raw,
  };
  return unique.toList(growable: false);
}

String? validateParticipantIds(List<String> raw, {String? ownerId}) {
  for (final uid in raw) {
    if (uid.isEmpty) return 'Confira quem jogou com você.';
  }
  final unique = normalizeParticipantIds(raw, ownerId: ownerId);
  if (unique.length > participantsMax) {
    return 'Uma sessão pode ter até $participantsMax participantes.';
  }
  return null;
}

/// Título do lance. Vazio vira "Lance N" — ninguém precisa digitar na quadra.
String normalizeHighlightTitle(String? raw, int position) {
  final title = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  return title.isEmpty ? 'Lance $position' : title;
}

String? validateHighlightTitle(String? raw) {
  final title = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (title.length > highlightTitleMax) {
    return 'O nome do lance pode ter até $highlightTitleMax caracteres.';
  }
  return null;
}

/// Novo nome de um lance (renomear). Diferente do envio da sessão, vazio é erro: a pessoa
/// está escrevendo um nome. Espelha `normalizeHighlightRename` em
/// backend/functions/src/highlights/validation.ts.
String? validateHighlightRename(String? raw) {
  final title = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (title.isEmpty) return 'Dê um nome ao lance.';
  if (title.length > highlightTitleMax) {
    return 'O nome do lance pode ter até $highlightTitleMax caracteres.';
  }
  return null;
}

/// Ids da sessão e do lance ao renomear (espelha `normalizeHighlightRef` no servidor).
String? validateHighlightRef(String raw) =>
    _entityIdPattern.hasMatch(raw) ? null : 'Esse lance não foi encontrado. Tente de novo.';

/// Momento do lance dentro da sessão, com 1 min de folga para o arredondamento do corte.
String? validateHighlightOffset(int offsetSeconds, {required int sessionDurationSeconds}) {
  if (offsetSeconds < 0 || offsetSeconds > sessionDurationSeconds + 60) {
    return 'Confira o momento dos lances.';
  }
  return null;
}

/// Duração do trecho salvo pelo gesto (1 a [highlightSecondsMax] s).
String? validateHighlightDuration(int durationSeconds) {
  if (durationSeconds <= 0 || durationSeconds > highlightSecondsMax) {
    return 'Confira a duração dos lances.';
  }
  return null;
}

// --- Juntar sessões (D18) ----------------------------------------------------
// Espelho de backend/functions/src/sessions/validation.ts › parseMergeRequestId e
// MERGE_TOLERANCE_MINUTES, com as MESMAS mensagens.

/// Quanto as duas gravações podem estar afastadas no tempo e ainda serem "o mesmo jogo".
const int mergeToleranceMinutes = 30;

/// O id do pedido é `sessãoPrincipal__sessãoDeOrigem`.
const String mergeRequestSeparator = '__';

String? validateMergeRequestId(String raw) {
  final parts = raw.split(mergeRequestSeparator);
  if (parts.length != 2) return 'Esse pedido não existe mais.';
  for (final id in parts) {
    final error = validateEntityId(id);
    if (error != null) return error;
  }
  return null;
}

// --- Amigos (D16) ------------------------------------------------------------
// Espelho de backend/functions/src/friends/validation.ts. O @ que a pessoa digita
// usa [validateUsername], que já tem a cópia no servidor (users/validation.ts).

final RegExp _uidPattern = RegExp(r'^[A-Za-z0-9]{1,128}$');

/// Uid do Firebase Auth (não é digitado, mas o servidor confere e o app também).
String? validateUid(String raw) => _uidPattern.hasMatch(raw) ? null : 'Não encontramos essa pessoa.';
