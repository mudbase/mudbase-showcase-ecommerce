package dev.mudbase.showcase.ecommerce.domain;

/** One step in the order fulfillment timeline shown on the order detail page. */
public record OrderTimelineStep(String label, boolean done) {}
