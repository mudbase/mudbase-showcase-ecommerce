// Polls this app's own /checkout/{token}/status JSON endpoint (itself a
// thin server-side proxy to Mudbase's public payment-link read) until the
// link reaches a terminal status. Mirrors web/src/hooks/usePaymentLinkStatus.ts.
(function () {
  const panel = document.querySelector("[data-payment-panel]");
  if (!panel) return;

  const POLL_INTERVAL_MS = 4000;
  const statusUrl = panel.getAttribute("data-status-url");
  const badge = panel.querySelector("[data-status-badge]");
  const message = panel.querySelector("[data-status-message]");
  const pendingDetails = panel.querySelector("[data-pending-details]");
  const amountField = panel.querySelector('[data-field="amount"]');
  const networkField = panel.querySelector('[data-field="network"]');
  const addressField = panel.querySelector('[data-field="address"]');

  function render(link) {
    badge.textContent = link.status;

    if (link.status === "paid") {
      message.innerHTML = '<span class="status-paid">Payment received — thank you!</span>';
      pendingDetails.style.display = "none";
    } else if (link.status === "expired" || link.status === "cancelled") {
      message.innerHTML = '<span class="status-dead">This payment link is no longer active.</span>';
      pendingDetails.style.display = "none";
    } else {
      message.innerHTML = '<span class="status-pending">Waiting for payment — this page updates automatically.</span>';
      pendingDetails.style.display = "";
      if (amountField) amountField.textContent = `${link.amount ?? ""} ${link.currency ?? ""}`.trim();
      if (networkField) networkField.textContent = link.network ?? "";
      if (addressField) addressField.textContent = link.address ?? "";
    }
  }

  async function tick() {
    try {
      const res = await fetch(statusUrl, { headers: { Accept: "application/json" } });
      if (!res.ok) return scheduleNext();
      const body = await res.json();
      if (!body.link) return scheduleNext();
      render(body.link);
      if (body.link.status === "pending") scheduleNext();
    } catch (_err) {
      scheduleNext();
    }
  }

  function scheduleNext() {
    setTimeout(tick, POLL_INTERVAL_MS);
  }

  scheduleNext();
})();
