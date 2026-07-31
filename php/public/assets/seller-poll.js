/**
 * Short-poll replacement for the reference app's Socket.IO realtime order queue (see
 * src/hooks/useOrdersLive.ts). A plain server-rendered PHP page has no persistent WebSocket
 * connection to subscribe with, so instead this fetches the same order-queue markup the page
 * rendered with and swaps it in every few seconds — new/updated orders show up without a manual
 * refresh, just not push-instant. Documented as a known limitation in README.
 */
(function () {
  "use strict";

  var POLL_INTERVAL_MS = 5000;
  var container = document.getElementById("seller-order-queue");
  if (!container) {
    return;
  }

  var fragmentUrl = container.getAttribute("data-fragment-url");
  if (!fragmentUrl) {
    return;
  }

  var isFetching = false;

  function poll() {
    if (isFetching || document.hidden) {
      return;
    }
    isFetching = true;

    fetch(fragmentUrl, { credentials: "same-origin" })
      .then(function (response) {
        if (!response.ok) {
          throw new Error("Fragment request failed: " + response.status);
        }
        return response.text();
      })
      .then(function (html) {
        container.innerHTML = html;
      })
      .catch(function () {
        // Silently skip this tick — the next poll will retry. A transient network blip here
        // shouldn't interrupt whatever the seller is doing on the page.
      })
      .finally(function () {
        isFetching = false;
      });
  }

  setInterval(poll, POLL_INTERVAL_MS);
})();
