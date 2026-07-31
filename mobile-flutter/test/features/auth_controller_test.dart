import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mudbase_sdk/mudbase_sdk.dart';
import 'package:mudbase_showcase_ecommerce/core/auth_service.dart';
import 'package:mudbase_showcase_ecommerce/core/mudbase_exception.dart';
import 'package:mudbase_showcase_ecommerce/core/secure_token_storage.dart';
import 'package:mudbase_showcase_ecommerce/core/service_providers.dart';
import 'package:mudbase_showcase_ecommerce/features/auth/auth_controller.dart';

/// Stands in for a real 401: [AuthService.getSession] on cold start succeeds
/// (so the controller reaches a signed-in state), but [refreshSession] and
/// [logout] are scriptable per test so the retry-after-401 path in
/// [AuthController.callAuthorized] can be exercised without a live token
/// actually expiring (the real access token's TTL is far too long to wait
/// out in a unit test).
class _FakeAuthService extends AuthService {
  _FakeAuthService()
      : super(
          MudbaseSdk(basePathOverride: 'https://cloud.mudbase.dev'),
          'test-project',
        );

  int refreshCallCount = 0;
  bool refreshShouldFail = false;

  @override
  Future<Map<String, dynamic>> getSession(String token) async {
    return {
      'authenticated': true,
      'user': {
        'id': 'user_1',
        'email': 'test@example.test',
        'firstName': 'Test',
        'lastName': 'User',
        'customRole': 'customer',
        'emailVerified': true,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> refreshSession(String refreshToken) async {
    refreshCallCount++;
    if (refreshShouldFail) {
      throw const MudbaseException('Refresh token expired', 401);
    }
    return {'token': 'new-access-token', 'refreshToken': 'new-refresh-token'};
  }

  @override
  Future<void> logout(String token) async {}
}

class _FakeSecureTokenStorage extends SecureTokenStorage {
  String? token = 'old-access-token';
  String? refreshToken = 'old-refresh-token';
  bool cleared = false;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveSession({
    required String token,
    String? refreshToken,
  }) async {
    this.token = token;
    if (refreshToken != null) this.refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    cleared = true;
    token = null;
    refreshToken = null;
  }
}

void main() {
  group('AuthController.callAuthorized', () {
    late _FakeAuthService fakeAuth;
    late _FakeSecureTokenStorage fakeStorage;
    late ProviderContainer container;

    setUp(() async {
      fakeAuth = _FakeAuthService();
      fakeStorage = _FakeSecureTokenStorage();
      container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(fakeAuth),
        secureTokenStorageProvider.overrideWithValue(fakeStorage),
      ]);
      // Drives AuthController.build(): reads the stored token, confirms the
      // session via getSession, and lands in a signed-in state before any
      // test issues a call through callAuthorized.
      await container.read(authControllerProvider.future);
    });

    tearDown(() => container.dispose());

    test(
        'retries exactly once with a refreshed token after a 401, instead '
        'of surfacing it to the caller', () async {
      final notifier = container.read(authControllerProvider.notifier);
      var callCount = 0;

      final result = await notifier.callAuthorized<String>((token) async {
        callCount++;
        if (callCount == 1) {
          expect(token, 'old-access-token');
          throw const MudbaseException('Unauthorized', 401);
        }
        expect(token, 'new-access-token');
        return 'ok';
      });

      expect(result, 'ok');
      expect(callCount, 2);
      expect(fakeAuth.refreshCallCount, 1);
      expect(fakeStorage.token, 'new-access-token');
      expect(fakeStorage.refreshToken, 'new-refresh-token');
      expect(fakeStorage.cleared, isFalse);
      expect(container.read(authControllerProvider).value, isNotNull);
    });

    test(
        'deduplicates concurrent refreshes so two calls hitting a 401 at '
        'once only refresh once', () async {
      final notifier = container.read(authControllerProvider.notifier);

      final results = await Future.wait([
        notifier.callAuthorized<String>((token) async {
          if (token == 'old-access-token') {
            throw const MudbaseException('Unauthorized', 401);
          }
          return token;
        }),
        notifier.callAuthorized<String>((token) async {
          if (token == 'old-access-token') {
            throw const MudbaseException('Unauthorized', 401);
          }
          return token;
        }),
      ]);

      expect(results, ['new-access-token', 'new-access-token']);
      expect(fakeAuth.refreshCallCount, 1);
    });

    test(
        'clears the local session and rethrows the original 401 when the '
        'refresh token itself is rejected', () async {
      fakeAuth.refreshShouldFail = true;
      final notifier = container.read(authControllerProvider.notifier);

      await expectLater(
        () => notifier.callAuthorized<void>((token) async {
          throw const MudbaseException('Unauthorized', 401);
        }),
        throwsA(
          isA<MudbaseException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'Unauthorized'),
        ),
      );

      expect(fakeStorage.cleared, isTrue);
      expect(container.read(authControllerProvider).value, isNull);
    });

    test('does not attempt a refresh for a non-401 failure', () async {
      final notifier = container.read(authControllerProvider.notifier);

      await expectLater(
        () => notifier.callAuthorized<void>((token) async {
          throw const MudbaseException('Server error', 500);
        }),
        throwsA(
          isA<MudbaseException>()
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );

      expect(fakeAuth.refreshCallCount, 0);
      expect(fakeStorage.cleared, isFalse);
    });
  });
}
