import 'package:intl/intl.dart';

/// `priceCents` is an integer minor-unit amount (matches the Mudbase
/// `products`/`orders` collection schema) - never a floating-point major
/// unit, to avoid rounding drift on money.
String formatMoney(int cents, String currencyCode) {
  final major = cents / 100;
  final format = NumberFormat.currency(
    // The catalog's `currency` field is a plain string (e.g. "USD"), not
    // guaranteed to be a valid ISO 4217 code `intl` recognizes as a locale
    // symbol - fall back to prefixing the raw code rather than throwing.
    customPattern: '¤#,##0.00',
    symbol: _currencySymbolOrCode(currencyCode),
  );
  return format.format(major);
}

String _currencySymbolOrCode(String currencyCode) {
  switch (currencyCode.toUpperCase()) {
    case 'USD':
      return r'$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    default:
      return '$currencyCode ';
  }
}

int? discountPercent(int priceCents, int? compareAtPriceCents) {
  if (compareAtPriceCents == null || compareAtPriceCents <= priceCents) {
    return null;
  }
  final percent =
      ((compareAtPriceCents - priceCents) / compareAtPriceCents) * 100;
  return percent.round();
}

String formatDate(DateTime dateTime) {
  return DateFormat.yMMMd().add_jm().format(dateTime.toLocal());
}

String shortOrderId(String id) {
  final tail = id.length > 6 ? id.substring(id.length - 6) : id;
  return tail.toUpperCase();
}
