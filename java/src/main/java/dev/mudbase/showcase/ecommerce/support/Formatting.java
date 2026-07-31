package dev.mudbase.showcase.ecommerce.support;

import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.Currency;
import java.util.Locale;
import java.util.regex.Pattern;

/** Formatting helpers shared by domain objects and templates - mirrors src/lib/utils.ts. */
public final class Formatting {

  private static final Pattern NON_ALPHANUMERIC = Pattern.compile("[^a-z0-9]+");
  private static final Pattern LEADING_TRAILING_DASH = Pattern.compile("(^-|-$)");
  private static final DateTimeFormatter DISPLAY_DATE =
      DateTimeFormatter.ofPattern("MMM d, yyyy 'at' h:mm a", Locale.US);

  private Formatting() {}

  public static String formatMoney(long cents, String currency) {
    double amount = cents / 100.0;
    String symbol;
    try {
      symbol = Currency.getInstance(currency == null ? "USD" : currency).getSymbol(Locale.US);
    } catch (IllegalArgumentException e) {
      symbol = (currency == null ? "USD" : currency) + " ";
    }
    return symbol + String.format(Locale.US, "%,.2f", amount);
  }

  public static String formatDate(String iso) {
    if (iso == null || iso.isBlank()) {
      return "";
    }
    try {
      return OffsetDateTime.parse(iso).format(DISPLAY_DATE);
    } catch (DateTimeParseException e) {
      return iso;
    }
  }

  public static String slugify(String value) {
    if (value == null) {
      return "";
    }
    String slug = value.toLowerCase(Locale.US).trim();
    slug = NON_ALPHANUMERIC.matcher(slug).replaceAll("-");
    slug = LEADING_TRAILING_DASH.matcher(slug).replaceAll("");
    return slug;
  }

  /** Percentage off, or null when there is no active discount. */
  public static Integer discountPercent(long priceCents, Long compareAtPriceCents) {
    if (compareAtPriceCents == null || compareAtPriceCents <= priceCents) {
      return null;
    }
    return (int) Math.round((1 - (double) priceCents / compareAtPriceCents) * 100);
  }

  public static String shortOrderNumber(String documentId) {
    if (documentId == null || documentId.isBlank()) {
      return "";
    }
    String tail = documentId.length() > 6 ? documentId.substring(documentId.length() - 6) : documentId;
    return tail.toUpperCase(Locale.US);
  }
}
