<?php
/**
 * @var list<array<string, mixed>> $orders
 * @var string|null $ordersError
 *
 * Rendered both inline (seller_dashboard.php, first page load) and standalone as the short-poll
 * fragment (SellerController::ordersFragment) — see public/assets/seller-poll.js.
 */

use App\Http\Csrf;
use App\Support\Money;
use App\View;

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
$nextStatus = ['paid' => 'shipped', 'shipped' => 'delivered'];
?>

<?php if ($ordersError !== null): ?>
  <p class="flash flash--error"><?= View::escape($ordersError) ?></p>
<?php elseif ($orders === []): ?>
  <div class="empty-state"><p>No orders yet — they'll appear here once one comes in.</p></div>
<?php else: ?>
  <ul class="list-rows">
    <?php foreach ($orders as $order): $next = $nextStatus[$order['orderStatus']] ?? null; ?>
      <li>
        <div style="min-width:0">
          <a href="/orders/<?= urlencode((string) $order['_id']) ?>" style="font-weight:600;text-decoration:none">
            Order #<?= strtoupper(substr((string) $order['_id'], -6)) ?>
          </a>
          <p class="muted" style="margin:0">
            <?= View::escape($order['shippingName'] ?? 'Guest') ?> &middot; <?= Money::formatDate((string) $order['createdAt']) ?>
          </p>
        </div>
        <span class="tabular"><?= Money::format((int) $order['subtotalCents'], (string) $order['currency']) ?></span>
        <span class="badge <?= $statusBadge((string) $order['orderStatus']) ?>"><?= $statusLabel((string) $order['orderStatus']) ?></span>
        <?php if ($next !== null): ?>
          <form method="post" action="/seller/orders/<?= urlencode((string) $order['_id']) ?>/advance">
            <?= Csrf::field() ?>
            <button type="submit" class="btn btn--outline btn--sm">Mark <?= $next ?></button>
          </form>
        <?php endif; ?>
      </li>
    <?php endforeach; ?>
  </ul>
<?php endif; ?>
