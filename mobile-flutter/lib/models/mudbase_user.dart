/// The authenticated end-user. Parsed from raw JSON rather than the bundled
/// Dart SDK's generated `User`/`LoginLocalUser200ResponseUser` models -
/// those only type `id`/`email`/`firstName`/`lastName`/`role`/
/// `emailVerified` and silently drop `customRole`/`isAnonymous` on
/// deserialization (confirmed by reading the generated model/serializer
/// source under `mudbase-sdk/dart/lib/src/model/`), even though the live
/// Multi-Role feature returns both. `customRole` is exactly the field this
/// app gates the seller area on, so it cannot be dropped - see README
/// "Known limitations".
class MudbaseUser {
  const MudbaseUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.customRole,
    required this.emailVerified,
  });

  factory MudbaseUser.fromJson(Map<String, dynamic> json) {
    return MudbaseUser(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      customRole: json['customRole'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
    );
  }

  final String id;
  final String email;
  final String firstName;
  final String lastName;

  /// The Multi-Role application role: `"customer"` or `"seller"`. Null for
  /// an account that predates the Multi-Role feature being enabled on the
  /// project, which this app treats the same as `"customer"` (see
  /// [isSeller]).
  final String? customRole;
  final bool emailVerified;

  bool get isSeller => customRole == 'seller';

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? email : name;
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
    this.refreshToken,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const FormatException('Auth response did not include a token');
    }
    final userJson = json['user'] as Map<String, dynamic>?;
    if (userJson == null) {
      throw const FormatException('Auth response did not include a user');
    }
    return AuthSession(
      token: token,
      refreshToken: json['refreshToken'] as String?,
      user: MudbaseUser.fromJson(userJson),
    );
  }

  final String token;
  final String? refreshToken;
  final MudbaseUser user;
}
