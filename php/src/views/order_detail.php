<?php
/**
 * @var array<string, mixed>|null $order
 * @var list<array<string, mixed>>|null $items
 * @var array<string, mixed>|null $address
 * @var string|null $error
 */

use App\Support\Money;
use App\View;

$title = 'Order';

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

$steps = [
    ['status' => 'pending', 'label' => 'Placed'],
    ['status' => 'paid', 'label' => 'Paid'],
    ['status' => 'shipped', 'label' => 'Shipped'],
    ['status' => 'delivered', 'label' => 'Delivered'],
];
?>

<?php if ($order === null): ?>
  <div class="empty-state">
    <p><?= $error !== null ? View::escape($error) : "This order couldn't be found." ?></p>
  </div>
<?php else:
  $orderStatus = (string) $order['orderStatus'];
  $effectiveStatus = $orderStatus === 'awaiting_payment' ? 'pending' : $orderStatus;
  $currentIndex = -1;
  foreach ($steps as $i => $step) {
      if ($step['status'] === $effectiveStatus) {
          $currentIndex = $i;
      }
  }
?>
  <div style="display:flex;align-items:center;justify-content:space-between">
    <div>
      <h1>Order #<?= strtoupper(substr((string) $order['_id'], -6)) ?></h1>
      <p class="muted"><?= Money::formatDate((string) $order['createdAt']) ?></p>
    </div>
    <span class="badge <?= $statusBadge($orderStatus) ?>"><?= $statusLabel($orderStatus) ?></span>
  </div>

  <?php if ($orderStatus === 'cancelled'): ?>
    <p style="color:hsl(var(--destructive))">This order was cancelled.</p>
  <?php else: ?>
    <ol class="timeline">
      <?php foreach ($steps as $i => $step): $done = $i <= $currentIndex; ?>
        <li>
          <span class="timeline__step <?= $done ? 'done' : '' ?>"><?= $done ? '&#10003;' : $i + 1 ?></span>
          <span class="<?= $done ? '' : 'muted' ?>"><?= View::escape($step['label']) ?></span>
          <?php if ($i < count($steps) - 1): ?><span class="timeline__bar <?= $done ? 'done' : '' ?>"></span><?php endif; ?>
        </li>
      <?php endforeach; ?>
    </ol>
  <?php endif; ?>

  <hr style="border:none;border-top:1px solid hsl(var(--border));margin:1.5rem 0">

  <h2>Items</h2>
  <table>
    <thead>
      <tr><th>Item</th><th class="text-right">Qty</th><th class="text-right">Price</th><th class="text-right">Total</th></tr>
    </thead>
    <tbody>
      <?php foreach (($items ?? []) as $item): ?>
        <tr>
          <td><?= View::escape($item['name']) ?></td>
          <td class="text-right tabular"><?= (int) $item['quantity'] ?></td>
          <td class="text-right tabular"><?= Money::format((int) $item['priceCents'], (string) $order['currency']) ?></td>
          <td class="text-right tabular"><?= Money::format((int) $item['priceCents'] * (int) $item['quantity'], (string) $order['currency']) ?></td>
        </tr>
      <?php endforeach; ?>
    </tbody>
  </table>
  <div style="display:flex;justify-content:space-between;font-weight:600;margin-top:0.75rem">
    <span>Total</span>
    <span class="tabular"><?= Money::format((int) $order['subtotalCents'], (string) $order['currency']) ?></span>
  </div>

  <?php if ($address !== null): ?>
    <h2 style="margin-top:1.5rem">Shipping to</h2>
    <p class="muted">
      <?= View::escape($address['fullName'] ?? '') ?><br>
      <?= View::escape($address['line1'] ?? '') ?><?= !empty($address['line2']) ? ', ' . View::escape($address['line2']) : '' ?><br>
      <?= View::escape($address['city'] ?? '') ?>, <?= View::escape($address['region'] ?? '') ?> <?= View::escape($address['postalCode'] ?? '') ?><br>
      <?= View::escape($address['country'] ?? '') ?>
    </p>
  <?php endif; ?>

  <?php if (!empty($order['paymentLinkToken']) && ($order['paymentStatus'] ?? null) !== 'paid'): ?>
    <a class="btn" style="margin-top:1rem" href="/checkout/<?= urlencode((string) $order['paymentLinkToken']) ?>">Complete payment</a>
  <?php endif; ?>
<?php endif; ?>
