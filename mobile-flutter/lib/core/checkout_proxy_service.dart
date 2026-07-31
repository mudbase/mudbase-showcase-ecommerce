import 'package:dio/dio.dart';
import 'package:mudbase_sdk/mudbase_sdk.dart';

import '../config/env_config.dart';
import '../models/payment_link.dart';
import 'mudbase_exception.dart';

/// Result of asking the web app's checkout proxy to create a Payment Link.
sealed class CheckoutPayLinkResult {
  const CheckoutPayLinkResult();
}

class CheckoutPayLinkSuccess extends CheckoutPayLinkResult {
  const CheckoutPayLinkSuccess(this.token);
  final String token;
}

class CheckoutPayLinkFailure extends CheckoutPayLinkResult {
  const CheckoutPayLinkFailure(
      {required this.message, required this.isKycRequired});
  final String message;

  /// True when the proxy returned `403 { reason: "kyc_required" }` - the
  /// org's Payment Links are gated on KYC approval, re-checked live on every
  /// creation call. This is a real, expected state to show honestly (see
  /// build-plan.md "Payment Flow"), never something to paper over with a
  /// fake success.
  final bool isKycRequired;
}

/// Creating a Mudbase Payment Link requires a live org owner/admin bearer
/// token - there is no API-key path for it, and a project end-user's token
/// (what this mobile app holds) can never carry an org role. So checkout
/// never calls `POST /api/orgs/:orgId/payment-links` itself; it instead
/// POSTs to the already-deployed web app's own Route Handler
/// (`/api/checkout/pay-link`), which holds that merchant credential
/// server-side and creates the link on the customer's behalf. See README
/// "Known limitations".
class CheckoutProxyService {
  const CheckoutProxyService(this._sdk);

  final MudbaseSdk _sdk;

  Future<CheckoutPayLinkResult> createPaymentLink({
    required String orderId,
    required String amount,
    required String currency,
    required String network,
    required String redirectUrl,
  }) async {
    try {
      final response = await _sdk.dio.post<dynamic>(
        '${EnvConfig.checkoutProxyBaseUrl}/api/checkout/pay-link',
        data: {
          'orderId': orderId,
          'amount': amount,
          'currency': currency,
          'network': network,
          'redirectUrl': redirectUrl,
        },
        options: Options(contentType: 'application/json'),
      );
      final body = response.data;
      final link = body is Map<String, dynamic> ? body['link'] : null;
      final token =
          link is Map<String, dynamic> ? link['token'] as String? : null;
      if (token == null || token.isEmpty) {
        return const CheckoutPayLinkFailure(
          message: "The payment link couldn't be created. Please try again.",
          isKycRequired: false,
        );
      }
      return CheckoutPayLinkSuccess(token);
    } on DioException catch (error) {
      final body = error.response?.data;
      final reason =
          body is Map<String, dynamic> ? body['reason'] as String? : null;
      final message = body is Map<String, dynamic>
          ? (body['error'] as String? ??
              "Couldn't start payment. Please try again.")
          : "Couldn't start payment. Please try again.";
      return CheckoutPayLinkFailure(
        message: message,
        isKycRequired: reason == 'kyc_required',
      );
    }
  }

  /// Public, unauthenticated read against `cloud.mudbase.dev` directly - no
  /// merchant credential involved, matches the web app's
  /// `usePaymentLinkStatus`.
  Future<PaymentLink> getPaymentLinkStatus(String token) async {
    try {
      final response = await _sdk.dio.get<dynamic>('/api/payment-links/$token');
      final body = response.data;
      final link = body is Map<String, dynamic> ? body['link'] : null;
      if (link is! Map<String, dynamic>) {
        throw const MudbaseException('Payment link not found.', 0);
      }
      return PaymentLink.fromJson(link);
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }
}
