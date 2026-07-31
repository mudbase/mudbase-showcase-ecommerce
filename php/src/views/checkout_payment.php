<?php
/**
 * @var string $token
 * @var array<string, mixed>|null $link
 * @var string $mudbaseUrl
 */

use App\View;

$title = 'Pay for your order';

$statusBadgeClass = static fn (string $status): string => match ($status) {
    'paid' => 'badge--success',
    'expired', 'cancelled' => 'badge--destructive',
    default => 'badge--warning',
};
?>

<div style="max-width:28rem;margin:0 auto">
  <h1 style="text-align:center">Pay for your order</h1>

  <div id="payment-panel" class="card payment-panel" style="padding:1.5rem">
    <?php if ($link === null): ?>
      <p class="muted">Payment link not found.</p>
    <?php else: ?>
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem">
        <strong>Complete your payment</strong>
        <span id="payment-status-badge" class="badge <?= $statusBadgeClass((string) ($link['status'] ?? 'pending')) ?>">
          <?= View::escape((string) ($link['status'] ?? 'pending')) ?>
        </span>
      </div>
      <div id="payment-status-body">
        <?php if (($link['status'] ?? null) === 'paid'): ?>
          <p style="color:hsl(var(--success))">Payment received — thank you!</p>
        <?php elseif (in_array($link['status'] ?? null, ['expired', 'cancelled'], true)): ?>
          <p style="color:hsl(var(--destructive))">This payment link is no longer active.</p>
        <?php else: ?>
          <p class="muted">Waiting for payment — this page updates automatically.</p>
          <dl>
            <div class="row"><span class="muted">Amount</span><span class="tabular"><?= View::escape((string) ($link['amount'] ?? '')) ?> <?= View::escape((string) ($link['currency'] ?? '')) ?></span></div>
            <div class="row"><span class="muted">Network</span><span><?= View::escape((string) ($link['network'] ?? '')) ?></span></div>
            <div class="row"><span class="muted">Send to</span><span class="address"><?= View::escape((string) ($link['address'] ?? '')) ?></span></div>
          </dl>
        <?php endif; ?>
      </div>
    <?php endif; ?>
  </div>
</div>

<?php if ($link !== null && !in_array($link['status'] ?? null, ['paid', 'expired', 'cancelled'], true)): ?>
<script>
(function () {
  "use strict";
  var token = <?= json_encode($token) ?>;
  var mudbaseUrl = <?= json_encode($mudbaseUrl) ?>;
  var intervalMs = 4000;

  function renderTerminal(status, body) {
    var badge = document.getElementById("payment-status-badge");
    if (badge) {
      badge.textContent = status;
      badge.className = "badge " + (status === "paid" ? "badge--success" : "badge--destructive");
    }
    var el = document.getElementById("payment-status-body");
    if (el) {
      el.innerHTML = body;
    }
  }

  function tick() {
    fetch(mudbaseUrl + "/api/payment-links/" + encodeURIComponent(token))
      .then(function (res) {
        if (!res.ok) { throw new Error("status " + res.status); }
        return res.json();
      })
      .then(function (body) {
        var link = body && body.link;
        if (!link) { return; }
        if (link.status === "paid") {
          renderTerminal("paid", '<p style="color:hsl(var(--success))">Payment received — thank you!</p>');
          return;
        }
        if (link.status === "expired" || link.status === "cancelled") {
          renderTerminal(link.status, '<p style="color:hsl(var(--destructive))">This payment link is no longer active.</p>');
          return;
        }
        setTimeout(tick, intervalMs);
      })
      .catch(function () {
        // Best-effort progressive enhancement — if this browser can't reach cloud.mudbase.dev
        // directly (network blip, CORS policy change), the server-rendered initial state stands
        // and a manual page reload re-checks status instead.
        setTimeout(tick, intervalMs);
      });
  }

  setTimeout(tick, intervalMs);
})();
</script>
<?php endif; ?>
