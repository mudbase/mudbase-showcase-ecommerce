// Small vanilla-JS image carousel for the product detail page — no bundler,
// no framework. Mirrors the interaction shape of the reference app's
// ImageCarousel.tsx (prev/next buttons + dot navigation), minus autoplay.
(function () {
  const root = document.querySelector("[data-carousel]");
  if (!root) return;

  const images = Array.from(root.querySelectorAll("img"));
  const dots = Array.from(document.querySelectorAll("[data-carousel-dot]"));
  const prevBtn = root.querySelector("[data-carousel-prev]");
  const nextBtn = root.querySelector("[data-carousel-next]");
  let index = 0;

  function show(nextIndex) {
    index = (nextIndex + images.length) % images.length;
    images.forEach((img, i) => img.classList.toggle("active", i === index));
    dots.forEach((dot, i) => dot.classList.toggle("active", i === index));
  }

  if (prevBtn) prevBtn.addEventListener("click", () => show(index - 1));
  if (nextBtn) nextBtn.addEventListener("click", () => show(index + 1));
  dots.forEach((dot, i) => dot.addEventListener("click", () => show(i)));
})();
