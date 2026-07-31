package dev.mudbase.showcase.ecommerce.service;

import dev.mudbase.showcase.ecommerce.domain.PaymentLink;

/** Outcome of asking the checkout proxy to create a Payment Link for an order. */
public sealed interface PaymentLinkCreationResult {

  record Created(PaymentLink link) implements PaymentLinkCreationResult {}

  /** The org isn't KYC-approved yet - an honest, expected state, not an error to log loudly. */
  record KycRequired(String message) implements PaymentLinkCreationResult {}

  record Failed(String message) implements PaymentLinkCreationResult {}
}
