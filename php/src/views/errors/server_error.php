<?php
/** @var string $message */

use App\View;

$title = 'Something went wrong';
?>
<div class="empty-state">
  <h1>Something went wrong</h1>
  <p><?= View::escape($message) ?></p>
  <a class="btn" href="/">Back to the catalog</a>
</div>
