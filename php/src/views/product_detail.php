<?php
/**
 * @var array<string, mixed>|null $product
 * @var list<string> $images
 * @var string|null $error
 */

use App\Http\Csrf;
use App\Support\Money;
use App\View;

$title = $product['name'] ?? 'Product';
?>

<?php if ($product === null): ?>
  <div class="empty-state">
    <p><?= $error !== null ? View::escape($error) : "This product isn't available anymore." ?></p>
  </div>
<?php else:
  $percentOff = Money::discountPercent((int) $product['priceCents'], isset($product['compareAtPriceCents']) ? (int) $product['compareAtPriceCents'] : null);
  $activeIndex = isset($_GET['photo']) ? max(0, min(count($images) - 1, (int) $_GET['photo'])) : 0;
  $activeImage = $images[$activeIndex] ?? null;
  $currentPath = '/products/' . urlencode((string) $product['slug']);
  $outOfStock = (int) ($product['stock'] ?? 0) <= 0;
?>
  <div class="product-detail">
    <div>
      <div class="product-detail__gallery">
        <?php if ($activeImage !== null): ?>
          <img src="<?= View::escape($activeImage) ?>" alt="<?= View::escape($product['name']) ?>">
        <?php else: ?>
          <div style="width:100%;height:100%;display:flex;align-items:center;justify-content:center" class="muted">No image</div>
        <?php endif; ?>
      </div>
      <?php if (count($images) > 1): ?>
        <div class="product-detail__thumbs">
          <?php foreach ($images as $i => $image): ?>
            <a href="<?= $currentPath ?>?photo=<?= $i ?>">
              <img src="<?= View::escape($image) ?>" alt="Photo <?= $i + 1 ?>" style="<?= $i === $activeIndex ? 'outline:2px solid hsl(var(--primary))' : '' ?>">
            </a>
          <?php endforeach; ?>
        </div>
      <?php endif; ?>
    </div>

    <div>
      <?php if (!empty($product['category'])): ?>
        <span class="badge" style="margin-bottom:0.5rem"><?= View::escape($product['category']) ?></span>
      <?php endif; ?>
      <?php if ($percentOff !== null): ?>
        <span class="badge badge--warning" style="margin-bottom:0.5rem"><?= $percentOff ?>% off</span>
      <?php endif; ?>
      <h1><?= View::escape($product['name']) ?></h1>
      <div style="display:flex;align-items:baseline;gap:0.6rem;margin-bottom:1rem">
        <span class="tabular" style="font-size:1.4rem;font-weight:700"><?= Money::format((int) $product['priceCents'], (string) $product['currency']) ?></span>
        <?php if ($percentOff !== null): ?>
          <span class="product-card__compare tabular"><?= Money::format((int) $product['compareAtPriceCents'], (string) $product['currency']) ?></span>
        <?php endif; ?>
      </div>

      <?php if (!empty($product['description'])): ?>
        <p style="white-space:pre-line"><?= View::escape($product['description']) ?></p>
      <?php endif; ?>

      <form method="post" action="/cart/add">
        <?= Csrf::field() ?>
        <input type="hidden" name="productId" value="<?= View::escape((string) $product['_id']) ?>">
        <input type="hidden" name="name" value="<?= View::escape((string) $product['name']) ?>">
        <input type="hidden" name="priceCents" value="<?= (int) $product['priceCents'] ?>">
        <input type="hidden" name="currency" value="<?= View::escape((string) $product['currency']) ?>">
        <input type="hidden" name="imageUrl" value="<?= View::escape($product['imageUrl'] ?? '') ?>">
        <input type="hidden" name="redirectTo" value="<?= View::escape($currentPath) ?>">
        <div class="quantity-row">
          <label for="quantity" class="muted" style="margin:0">Qty</label>
          <select id="quantity" name="quantity" <?= $outOfStock ? 'disabled' : '' ?>>
            <?php for ($q = 1; $q <= max(1, min(10, (int) ($product['stock'] ?? 1))); $q++): ?>
              <option value="<?= $q ?>"><?= $q ?></option>
            <?php endfor; ?>
          </select>
          <button type="submit" class="btn" <?= $outOfStock ? 'disabled' : '' ?>>
            <?= $outOfStock ? 'Out of stock' : 'Add to cart' ?>
          </button>
        </div>
      </form>

      <p class="muted"><?= $outOfStock ? 'Currently out of stock' : ((int) $product['stock']) . ' in stock' ?></p>
    </div>
  </div>
<?php endif; ?>
