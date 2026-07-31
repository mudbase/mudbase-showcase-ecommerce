<?php
/**
 * @var list<array<string, mixed>> $orders
 * @var string|null $ordersError
 * @var list<array<string, mixed>> $products
 * @var string|null $productsError
 */

use App\Http\Csrf;
use App\Support\Money;
use App\View;

$title = 'Seller dashboard';
?>

<section>
  <h1>Orders</h1>
  <p class="muted">Updates automatically every few seconds — see README "Known limitations" (no realtime push in this reimplementation).</p>
  <div id="seller-order-queue" data-fragment-url="/seller/orders-fragment">
    <?= View::renderPartial('partials/seller_order_queue', ['orders' => $orders, 'ordersError' => $ordersError]) ?>
  </div>
</section>

<section style="margin-top:3rem">
  <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:1rem">
    <h2 style="margin:0">Products</h2>
    <a class="btn" href="/seller/products/new">Add product</a>
  </div>

  <?php if ($productsError !== null): ?>
    <p class="flash flash--error"><?= View::escape($productsError) ?></p>
  <?php elseif ($products === []): ?>
    <div class="empty-state">
      <p>No products listed yet.</p>
      <a class="btn" href="/seller/products/new">Add your first product</a>
    </div>
  <?php else: ?>
    <div class="card" style="overflow-x:auto">
      <table>
        <thead>
          <tr><th>Name</th><th class="text-right">Price</th><th class="text-right">Stock</th><th>Status</th><th></th></tr>
        </thead>
        <tbody>
          <?php foreach ($products as $product):
            $percentOff = Money::discountPercent((int) $product['priceCents'], isset($product['compareAtPriceCents']) ? (int) $product['compareAtPriceCents'] : null);
          ?>
            <tr>
              <td><?= View::escape($product['name']) ?></td>
              <td class="text-right tabular">
                <?php if ($percentOff !== null): ?>
                  <span class="muted" style="text-decoration:line-through;font-size:0.8rem"><?= Money::format((int) $product['compareAtPriceCents'], (string) $product['currency']) ?></span>
                <?php endif; ?>
                <?= Money::format((int) $product['priceCents'], (string) $product['currency']) ?>
              </td>
              <td class="text-right tabular"><?= (int) $product['stock'] ?></td>
              <td><span class="badge <?= !empty($product['isActive']) ? 'badge--success' : '' ?>"><?= !empty($product['isActive']) ? 'Active' : 'Hidden' ?></span></td>
              <td style="text-align:right;white-space:nowrap">
                <a class="btn btn--ghost btn--sm" href="/seller/products/<?= urlencode((string) $product['_id']) ?>/edit">Edit</a>
                <form method="post" action="/seller/products/<?= urlencode((string) $product['_id']) ?>/delete" style="display:inline" onsubmit="return confirm('Delete this product? This can\'t be undone.');">
                  <?= Csrf::field() ?>
                  <button type="submit" class="btn btn--ghost btn--sm">Delete</button>
                </form>
              </td>
            </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
    </div>
  <?php endif; ?>
</section>

<script src="/assets/seller-poll.js"></script>
