<?php
/**
 * @var list<array<string, mixed>> $items
 * @var int $subtotalCents
 * @var bool $isCustomer
 * @var string $authMode
 */

use App\Http\Csrf;
use App\Support\Money;
use App\View;

$title = 'Checkout';
$currency = $items[0]['currency'] ?? 'USD';
?>

<?php if ($items === []): ?>
  <div class="empty-state"><p>Your cart is empty — add something before checking out.</p></div>
<?php else: ?>
  <div class="checkout-grid">
    <div>
      <h1>Checkout</h1>

      <?php if (!$isCustomer): ?>
        <?php if ($authMode === 'register'): ?>
          <p class="muted">
            Create an account to place this order — your cart carries over, and you'll be able to
            track it from Orders afterward.
          </p>
          <form method="post" action="/register">
            <?= Csrf::field() ?>
            <input type="hidden" name="redirectTo" value="/checkout">
            <div class="grid-2">
              <div class="field">
                <label for="firstName">First name</label>
                <input type="text" id="firstName" name="firstName" required>
              </div>
              <div class="field">
                <label for="lastName">Last name</label>
                <input type="text" id="lastName" name="lastName" required>
              </div>
            </div>
            <div class="field">
              <label for="email">Email</label>
              <input type="email" id="email" name="email" required>
            </div>
            <div class="field">
              <label for="password">Password</label>
              <input type="password" id="password" name="password" required minlength="8">
            </div>
            <div class="field">
              <label class="checkbox-row">
                <input type="checkbox" name="agreedToTerms">
                <span>I agree to the Terms of Service and Privacy Policy.</span>
              </label>
            </div>
            <button type="submit" class="btn btn--block">Create account</button>
          </form>
          <p class="muted">Already have an account? <a href="/checkout?mode=login">Sign in</a></p>
        <?php else: ?>
          <p class="muted">Sign in to continue — your cart carries over to your account.</p>
          <form method="post" action="/login">
            <?= Csrf::field() ?>
            <input type="hidden" name="redirectTo" value="/checkout">
            <div class="field">
              <label for="email">Email</label>
              <input type="email" id="email" name="email" required>
            </div>
            <div class="field">
              <label for="password">Password</label>
              <input type="password" id="password" name="password" required>
            </div>
            <button type="submit" class="btn btn--block">Sign in</button>
          </form>
          <p class="muted">New here? <a href="/checkout?mode=register">Create an account</a></p>
        <?php endif; ?>
      <?php else: ?>
        <form method="post" action="/checkout">
          <?= Csrf::field() ?>
          <div class="field">
            <label for="fullName">Full name</label>
            <input type="text" id="fullName" name="fullName" autocomplete="name" required>
          </div>
          <div class="field">
            <label for="line1">Address</label>
            <input type="text" id="line1" name="line1" autocomplete="address-line1" required>
          </div>
          <div class="field">
            <label for="line2">Apartment, suite, etc. (optional)</label>
            <input type="text" id="line2" name="line2" autocomplete="address-line2">
          </div>
          <div class="grid-2">
            <div class="field">
              <label for="city">City</label>
              <input type="text" id="city" name="city" autocomplete="address-level2" required>
            </div>
            <div class="field">
              <label for="region">State / region</label>
              <input type="text" id="region" name="region" autocomplete="address-level1" required>
            </div>
          </div>
          <div class="grid-2">
            <div class="field">
              <label for="postalCode">Postal code</label>
              <input type="text" id="postalCode" name="postalCode" autocomplete="postal-code" required>
            </div>
            <div class="field">
              <label for="country">Country</label>
              <input type="text" id="country" name="country" autocomplete="country-name" required>
            </div>
          </div>
          <button type="submit" class="btn btn--block">Continue to payment</button>
        </form>
      <?php endif; ?>
    </div>

    <div class="summary-box">
      <h2>Order summary</h2>
      <?php foreach ($items as $item): ?>
        <div class="summary-row">
          <span><?= View::escape($item['name']) ?> &times; <?= (int) $item['quantity'] ?></span>
          <span class="tabular"><?= Money::format((int) $item['priceCents'] * (int) $item['quantity'], (string) $item['currency']) ?></span>
        </div>
      <?php endforeach; ?>
      <div class="summary-row summary-row--total">
        <span>Total</span>
        <span class="tabular"><?= Money::format($subtotalCents, (string) $currency) ?></span>
      </div>
    </div>
  </div>
<?php endif; ?>
