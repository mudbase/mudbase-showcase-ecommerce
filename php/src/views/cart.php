<?php
/**
 * @var list<array<string, mixed>> $items
 * @var int $subtotalCents
 */

use App\Http\Csrf;
use App\Support\Money;
use App\View;

$title = 'Cart';
$currency = $items[0]['currency'] ?? 'USD';
?>

<div class="checkout-grid">
  <div>
    <h1>Your cart</h1>

    <?php if ($items === []): ?>
      <div class="empty-state"><p>Your cart is empty.</p></div>
    <?php else: ?>
      <?php foreach ($items as $item): ?>
        <div class="cart-line">
          <div class="cart-line__thumb">
            <?php if (!empty($item['imageUrl'])): ?>
              <img src="<?= View::escape($item['imageUrl']) ?>" alt="<?= View::escape($item['name']) ?>">
            <?php endif; ?>
          </div>
          <div class="cart-line__name">
            <p style="margin:0;font-weight:600"><?= View::escape($item['name']) ?></p>
            <p class="muted tabular" style="margin:0"><?= Money::format((int) $item['priceCents'], (string) $item['currency']) ?></p>
          </div>
          <form method="post" action="/cart/update" class="qty-form">
            <?= Csrf::field() ?>
            <input type="hidden" name="productId" value="<?= View::escape((string) $item['productId']) ?>">
            <input type="number" name="quantity" min="0" value="<?= (int) $item['quantity'] ?>">
            <button type="submit" class="btn btn--outline btn--sm">Update</button>
          </form>
          <p class="tabular" style="width:5.5rem;text-align:right;font-weight:600;margin:0">
            <?= Money::format((int) $item['priceCents'] * (int) $item['quantity'], (string) $item['currency']) ?>
          </p>
          <form method="post" action="/cart/remove">
            <?= Csrf::field() ?>
            <input type="hidden" name="productId" value="<?= View::escape((string) $item['productId']) ?>">
            <button type="submit" class="btn btn--ghost btn--sm" aria-label="Remove <?= View::escape($item['name']) ?>">Remove</button>
          </form>
        </div>
      <?php endforeach; ?>
    <?php endif; ?>
  </div>

  <div class="summary-box">
    <h2>Order summary</h2>
    <div class="summary-row">
      <span class="muted">Subtotal</span>
      <span class="tabular"><?= Money::format($subtotalCents, (string) $currency) ?></span>
    </div>
    <div class="summary-row summary-row--total">
      <span>Total</span>
      <span class="tabular"><?= Money::format($subtotalCents, (string) $currency) ?></span>
    </div>
    <?php if ($items === []): ?>
      <button class="btn btn--block" disabled>Checkout</button>
    <?php else: ?>
      <a class="btn btn--block" href="/checkout">Checkout</a>
    <?php endif; ?>
  </div>
</div>
