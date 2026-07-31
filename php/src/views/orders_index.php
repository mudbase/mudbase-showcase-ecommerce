<?php
/**
 * @var list<array<string, mixed>> $orders
 * @var string|null $error
 */

use App\Support\Money;
use App\View;

$title = 'Your orders';

$statusBadge = static fn (string $status): string => match ($status) {
    'delivered', 'paid' => 'badge--success',
    'cancelled' => 'badge--destructive',
    'awaiting_payment', 'pending' => 'badge--warning',
    default => '',
};
$statusLabel = static fn (string $status): string => match ($status) {
    'awaiting_payment' => 'Awaiting payment',
    default => ucfirst($status),
};
?>

<h1>Your orders</h1>

<?php if ($error !== null): ?>
  <p class="flash flash--error"><?= View::escape($error) ?></p>
<?php elseif ($orders === []): ?>
  <div class="empty-state"><p>No orders yet.</p></div>
<?php else: ?>
  <ul class="list-rows">
    <?php foreach ($orders as $order): ?>
      <li>
        <a class="row-link" href="/orders/<?= urlencode((string) $order['_id']) ?>">
          <div>
            <p style="margin:0;font-weight:600">Order #<?= strtoupper(substr((string) $order['_id'], -6)) ?></p>
            <p class="muted" style="margin:0"><?= Money::formatDate((string) $order['createdAt']) ?></p>
          </div>
          <div style="display:flex;align-items:center;gap:1rem">
            <span class="tabular"><?= Money::format((int) $order['subtotalCents'], (string) $order['currency']) ?></span>
            <span class="badge <?= $statusBadge((string) $order['orderStatus']) ?>"><?= $statusLabel((string) $order['orderStatus']) ?></span>
          </div>
        </a>
      </li>
    <?php endforeach; ?>
  </ul>
<?php endif; ?>
