import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_service.dart';
import '../../core/secure_token_storage.dart';
import '../../core/service_providers.dart';
import '../../models/mudbase_user.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, MudbaseUser?>(AuthController.new);

/// Owns the current session: bootstraps it from secure storage on cold
/// start, and drives login/register/logout. `state.value == null` means
/// "signed out" - the router's redirect logic (see `router/app_router.dart`)
/// reads this directly to gate every screen behind auth, and to send
/// `customRole == 'seller'` accounts to the seller area instead of the
/// storefront.
///
/// The token itself is intentionally kept out of Riverpod state (it would
/// have no UI reason to trigger a rebuild, and every rebuild dependent on
/// this provider would otherwise re-run whenever the token rotates). It
/// lives in a private field and in [SecureTokenStorage]; repositories read
/// it via [requireToken].
class AuthController extends AsyncNotifier<MudbaseUser?> {
  String? _token;

  AuthService get _authService => ref.read(authServiceProvider);
  SecureTokenStorage get _tokenStorage => ref.read(secureTokenStorageProvider);

  @override
  Future<MudbaseUser?> build() async {
    final storedToken = await _tokenStorage.readToken();
    if (storedToken == null) return null;
    try {
      final json = await _authService.getSession(storedToken);
      final userJson = json['user'] as Map<String, dynamic>?;
      final authenticated = json['authenticated'] as bool? ?? true;
      if (!authenticated || userJson == null) {
        await _tokenStorage.clear();
        return null;
      }
      _token = storedToken;
      return MudbaseUser.fromJson(userJson);
    } on Exception {
      // An expired/revoked token, or the server being briefly unreachable,
      // both resolve to "signed out" rather than a hard startup crash - the
      // login screen is always a safe fallback.
      await _tokenStorage.clear();
      return null;
    }
  }

  String requireToken() {
    final token = _token;
    if (token == null) {
      throw StateError('requireToken() called with no active session.');
    }
    return token;
  }

  Future<void> registerCustomer({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required bool agreedToTerms,
  }) async {
    final json = await _authService.registerWithRole(
      role: 'customer',
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      agreedToTerms: agreedToTerms,
    );
    await _applySession(json);
  }

  Future<void> login({required String email, required String password}) async {
    final json = await _authService.login(email: email, password: password);
    await _applySession(json);
  }

  Future<void> logout() async {
    final token = _token;
    if (token != null) {
      // Best-effort - AuthService.logout() already swallows a 401 (already
      // revoked), and the local sign-out below must happen regardless of
      // whether the server revoke succeeds.
      try {
        await _authService.logout(token);
      } on Exception {
        // Ignored - see comment above.
      }
    }
    _token = null;
    await _tokenStorage.clear();
    state = const AsyncData(null);
  }

  Future<void> _applySession(Map<String, dynamic> json) async {
    final token = json['token'] as String?;
    final userJson = json['user'] as Map<String, dynamic>?;
    if (token == null || userJson == null) {
      throw const FormatException(
        'The server did not return a session for this account.',
      );
    }
    _token = token;
    await _tokenStorage.saveSession(
      token: token,
      refreshToken: json['refreshToken'] as String?,
    );
    state = AsyncData(MudbaseUser.fromJson(userJson));
  }
}
