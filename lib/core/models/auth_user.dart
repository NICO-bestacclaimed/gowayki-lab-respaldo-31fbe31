class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.isAnonymous = false,
    this.providers = const [],
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool isAnonymous;
  final List<String> providers;
}
