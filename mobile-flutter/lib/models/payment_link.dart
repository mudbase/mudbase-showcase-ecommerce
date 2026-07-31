enum PaymentLinkStatus {
  pending('pending'),
  paid('paid'),
  expired('expired'),
  cancelled('cancelled');

  const PaymentLinkStatus(this.wireValue);

  final String wireValue;

  static PaymentLinkStatus fromWire(String? value) {
    return PaymentLinkStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => PaymentLinkStatus.pending,
    );
  }

  bool get isTerminal => this != PaymentLinkStatus.pending;
}

/// The public, unauthenticated projection of a Mudbase Payment Link -
/// mirrors the web app's `PublicPaymentLink` (`src/lib/mudbase-server.ts`).
/// Fetched from `GET /api/payment-links/:token` directly against
/// `cloud.mudbase.dev`, no auth required.
class PaymentLink {
  const PaymentLink({
    required this.token,
    required this.currency,
    required this.network,
    required this.address,
    required this.status,
    this.amount,
    this.description,
    this.expiresAt,
  });

  factory PaymentLink.fromJson(Map<String, dynamic> json) {
    return PaymentLink(
      token: json['token'] as String? ?? '',
      amount: json['amount'] as String?,
      currency: json['currency'] as String? ?? '',
      network: json['network'] as String? ?? '',
      address: json['address'] as String? ?? '',
      description: json['description'] as String?,
      status: PaymentLinkStatus.fromWire(json['status'] as String?),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.tryParse(json['expiresAt'] as String),
    );
  }

  final String token;
  final String? amount;
  final String currency;
  final String network;
  final String address;
  final String? description;
  final PaymentLinkStatus status;
  final DateTime? expiresAt;
}
