<?php
/**
 * @var list<array<string, mixed>> $products
 * @var list<string> $categories
 * @var string|null $selectedCategory
 * @var string|null $error
 */

use App\Support\Json;
use App\Support\Money;
use App\View;

$title = null;
?>

<div style="margin-bottom:2rem">
  <h1>Commonwealth Goods</h1>
  <p class="muted" style="max-width:40rem">
    Every product, order, cart, and payment on this page is served by a real Mudbase project — no
    custom backend. Browse as a guest; sign in when you're ready to check out.
  </p>
</div>

<?php if ($error !== null): ?>
  <p class="flash flash--error"><?= View::escape($error) ?></p>
<?php elseif ($categories !== []): ?>
  <div class="category-filters">
    <a href="/" class="<?= $selectedCategory === null ? 'is-active' : '' ?>">All</a>
    <?php foreach ($categories as $category): ?>
      <a href="/?category=<?= urlencode($category) ?>" class="<?= $selectedCategory === $category ? 'is-active' : '' ?>">
        <?= View::escape($category) ?>
      </a>
    <?php endforeach; ?>
  </div>
<?php endif; ?>

<?php if ($error === null && $products === []): ?>
  <div class="empty-state">
    <p><?= $selectedCategory !== null ? 'No products in "' . View::escape($selectedCategory) . '" yet.' : 'No products listed yet — check back soon.' ?></p>
  </div>
<?php elseif ($error === null): ?>
  <div class="product-grid">
    <?php foreach ($products as $product):
      $percentOff = Money::discountPercent((int) $product['priceCents'], isset($product['compareAtPriceCents']) ? (int) $product['compareAtPriceCents'] : null);
      $outOfStock = (int) ($product['stock'] ?? 0) <= 0;
    ?>
      <a class="product-card card" href="/products/<?= urlencode((string) $product['slug']) ?>">
        <div class="product-card__image">
          <?php if (!empty($product['imageUrl'])): ?>
            <img src="<?= View::escape($product['imageUrl']) ?>" alt="<?= View::escape($product['name']) ?>" loading="lazy">
          <?php else: ?>
            <span class="muted" style="font-size:0.85rem">No image</span>
          <?php endif; ?>
          <div class="product-card__badges">
            <?php if ($outOfStock): ?><span class="badge">Out of stock</span><?php endif; ?>
            <?php if ($percentOff !== null): ?><span class="badge badge--warning"><?= $percentOff ?>% off</span><?php endif; ?>
          </div>
        </div>
        <div class="product-card__body">
          <p class="product-card__category"><?= View::escape($product['category'] ?? 'General') ?></p>
          <h3><?= View::escape($product['name']) ?></h3>
        </div>
        <div class="product-card__price">
          <strong class="tabular"><?= Money::format((int) $product['priceCents'], (string) $product['currency']) ?></strong>
          <?php if ($percentOff !== null): ?>
            <span class="product-card__compare tabular"><?= Money::format((int) $product['compareAtPriceCents'], (string) $product['currency']) ?></span>
          <?php endif; ?>
        </div>
      </a>
    <?php endforeach; ?>
  </div>
<?php endif; ?>
