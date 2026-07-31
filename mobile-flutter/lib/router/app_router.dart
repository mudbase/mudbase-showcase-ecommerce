import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_screen.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/cart/cart_screen.dart';
import '../features/catalog/catalog_screen.dart';
import '../features/catalog/product_detail_screen.dart';
import '../features/checkout/checkout_screen.dart';
import '../features/checkout/payment_status_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/orders/order_history_screen.dart';
import '../features/seller/seller_dashboard_screen.dart';
import '../features/seller/seller_product_form_screen.dart';
import '../features/shell/home_shell.dart';

/// Bridges Riverpod's [authControllerProvider] to go_router's
/// `refreshListenable` - go_router only re-evaluates `redirect` on
/// navigation or when this notifies, so a sign-in/sign-out that happens
/// without a navigation event (e.g. the splash-screen session bootstrap
/// resolving) still re-runs the redirect logic below.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(
          path: '/splash', builder: (context, state) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/catalog',
                builder: (context, state) => const CatalogScreen(),
                routes: [
                  GoRoute(
                    path: 'product/:slug',
                    builder: (context, state) => ProductDetailScreen(
                      slug: state.pathParameters['slug']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/cart',
                  builder: (context, state) => const CartScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                builder: (context, state) => const OrderHistoryScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => OrderDetailScreen(
                      orderId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/account',
                  builder: (context, state) => const AccountScreen()),
            ],
          ),
        ],
      ),
      GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen()),
      GoRoute(
        path: '/checkout/status/:token',
        builder: (context, state) => PaymentStatusScreen(
          token: state.pathParameters['token']!,
        ),
      ),
      GoRoute(
        path: '/seller',
        builder: (context, state) => const SellerDashboardScreen(),
        routes: [
          GoRoute(
            path: 'products/new',
            builder: (context, state) => const SellerProductFormScreen(),
          ),
          GoRoute(
            path: 'products/:id/edit',
            builder: (context, state) => SellerProductFormScreen(
              productId: state.pathParameters['id'],
            ),
          ),
        ],
      ),
    ],
  );
});

String? _redirect(Ref ref, GoRouterState state) {
  final authState = ref.read(authControllerProvider);
  final location = state.matchedLocation;
  final isAuthRoute = location == '/login' || location == '/register';

  if (authState.isLoading) {
    return location == '/splash' ? null : '/splash';
  }

  final user = authState.valueOrNull;
  if (user == null) {
    return isAuthRoute ? null : '/login';
  }

  if (isAuthRoute || location == '/splash') {
    return user.isSeller ? '/seller' : '/catalog';
  }

  final isSellerArea = location.startsWith('/seller');
  if (user.isSeller && !isSellerArea) return '/seller';
  if (!user.isSeller && isSellerArea) return '/catalog';
  return null;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
