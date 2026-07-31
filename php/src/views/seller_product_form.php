<?php
/**
 * @var array<string, mixed>|null $product
 * @var string $formAction
 * @var string $heading
 * @var string|null $error
 */

use App\Http\Csrf;
use App\Support\Json;
use App\View;

$title = $heading;
$galleryUrls = $product !== null ? Json::parseField($product['galleryJson'] ?? null, []) : [];
?>

<h1><?= View::escape($heading) ?></h1>

<?php if ($error !== null): ?>
  <p class="flash flash--error"><?= View::escape($error) ?></p>
<?php else: ?>
  <form method="post" action="<?= View::escape($formAction) ?>" style="max-width:32rem">
    <?= Csrf::field() ?>
    <div class="field">
      <label for="name">Name</label>
      <input type="text" id="name" name="name" value="<?= View::escape($product['name'] ?? '') ?>" required>
    </div>
    <div class="field">
      <label for="description">Description</label>
      <textarea id="description" name="description" rows="5"><?= View::escape($product['description'] ?? '') ?></textarea>
    </div>
    <div class="grid-2">
      <div class="field">
        <label for="priceCents">Price (cents)</label>
        <input type="number" id="priceCents" name="priceCents" min="0" value="<?= (int) ($product['priceCents'] ?? 0) ?>" required>
      </div>
      <div class="field">
        <label for="stock">Stock</label>
        <input type="number" id="stock" name="stock" min="0" value="<?= (int) ($product['stock'] ?? 0) ?>" required>
      </div>
    </div>
    <div class="field">
      <label for="compareAtPriceCents">Compare-at price (cents)</label>
      <input type="number" id="compareAtPriceCents" name="compareAtPriceCents" min="0" placeholder="Leave blank for no discount"
        value="<?= isset($product['compareAtPriceCents']) ? (int) $product['compareAtPriceCents'] : '' ?>">
      <p class="field-hint">Set this higher than the price to show a strikethrough &amp; discount badge in the catalog.</p>
    </div>
    <div class="field">
      <label for="category">Category</label>
      <input type="text" id="category" name="category" value="<?= View::escape($product['category'] ?? '') ?>">
    </div>
    <div class="field">
      <label for="currency">Currency</label>
      <input type="text" id="currency" name="currency" value="<?= View::escape($product['currency'] ?? 'USD') ?>" required>
    </div>
    <div class="field">
      <label for="imageUrl">Main image URL</label>
      <input type="url" id="imageUrl" name="imageUrl" placeholder="https://…" value="<?= View::escape($product['imageUrl'] ?? '') ?>">
      <p class="field-hint">
        Mudbase file uploads require an owner/admin/developer system role, which project end-users
        (sellers included) don't have — see README "Known limitations". Paste a hosted image URL for now.
      </p>
    </div>
    <div class="field">
      <label for="galleryUrls">Additional photos (one URL per line, up to 8)</label>
      <textarea id="galleryUrls" name="galleryUrls" rows="4" placeholder="https://…"><?= View::escape(implode("\n", $galleryUrls)) ?></textarea>
    </div>
    <div class="field">
      <label class="checkbox-row">
        <input type="checkbox" name="isActive" <?= ($product === null || !empty($product['isActive'])) ? 'checked' : '' ?>>
        <span>Visible in the catalog</span>
      </label>
    </div>
    <button type="submit" class="btn">Save product</button>
  </form>
<?php endif; ?>
