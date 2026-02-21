class AuthSession {
  final String accessToken;
  final String email;
  final DateTime createdAt;

  const AuthSession({
    required this.accessToken,
    required this.email,
    required this.createdAt,
  });
}

