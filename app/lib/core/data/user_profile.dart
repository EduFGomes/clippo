
/// O perfil público de um usuário: o documento `users/{uid}`
/// (docs/arquitetura.md › Modelo de dados).
///
/// O e-mail não está aqui de propósito: ele fica só no Firebase Auth.
/// A data de nascimento também não: é privada, mora em `userPrivate/{uid}`.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.username,
    this.photoUrl,
    this.sessionCount = 0,
    this.highlightCount = 0,
    this.friendCount = 0,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    final stats = data['stats'] as Map<String, dynamic>? ?? const {};
    return UserProfile(
      uid: uid,
      name: data['name'] as String? ?? '',
      username: data['username'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      sessionCount: (stats['sessions'] as num?)?.toInt() ?? 0,
      highlightCount: (stats['highlights'] as num?)?.toInt() ?? 0,
      friendCount: (stats['friends'] as num?)?.toInt() ?? 0,
    );
  }

  final String uid;
  final String name;

  /// Sem o "@" na frente: é assim que fica guardado.
  final String username;
  final String? photoUrl;

  /// Contadores mostrados no Perfil. Mantidos por gatilho, nunca pelo app.
  final int sessionCount;
  final int highlightCount;
  final int friendCount;

  /// Como a saudação da Início chama a pessoa ("Boa noite, Gustavo").
  String get firstName => name.trim().split(' ').first;
}
