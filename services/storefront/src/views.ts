import type {
  CategoryPage, CategoryView, ProductSummary, ProductDetail, Range,
} from './catalog-client.js';

const esc = (s: unknown): string =>
  String(s ?? '').replace(/[&<>"']/g, c =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));

/**
 * Where images are served from.
 *
 * The catalog stores a key (`species/demasoni.jpg`); this composes the URL.
 * In the cluster it stays `/static`; in the AWS target it becomes a CloudFront
 * distribution, and that is a ConfigMap change rather than a data migration.
 */
const IMAGE_BASE = (process.env.IMAGE_BASE_URL ?? '/static').replace(/\/$/, '');

/**
 * A photograph, or an honest gap where one goes.
 *
 * `loading="lazy"` and an explicit aspect ratio, so a page of forty fish does
 * not fetch forty images and does not reflow as each one lands.
 *
 * Two ways there can be no picture, and both land on the same placeholder:
 *
 *   * **no key** -- most of the catalogue is not photographed yet;
 *   * **a key whose file is missing** -- the catalog names a photograph that
 *     has not been taken, or has not been uploaded to the CDN yet.
 *
 * The second is handled in the browser because only the browser knows: the
 * storefront cannot see a CDN's contents, and checking would mean a request per
 * image on every render. A page full of broken-image icons reads as a broken
 * site; a page of quiet placeholders reads as an incomplete catalogue, which is
 * the truth.
 */
const photo = (key: string | null, alt: string, ratio: string) =>
  key
    ? `<img class="shot" style="aspect-ratio:${ratio}" src="${esc(IMAGE_BASE)}/${esc(key)}"
          alt="${esc(alt)}" loading="lazy" decoding="async"
          onerror="this.removeAttribute('src');this.classList.add('shot-none');this.alt=''">`
    : `<span class="shot shot-none" style="aspect-ratio:${ratio}" aria-hidden="true"></span>`;

const money = (p: ProductSummary) =>
  p.currency === 'INR' ? `\u20B9${Number(p.price).toFixed(2)}` : `${p.currency} ${p.price}`;

const range = (r: Range, unit: string) => `${r.min}\u2013${r.max}${unit}`;

function layout(title: string, nav: CategoryView[], body: string): string {
  return `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)} &middot; AquaShop</title>
<link rel="stylesheet" href="/static/styles.css">
</head><body>
<header class="top">
  <a class="brand" href="/">Aqua<span>Shop</span></a>
  <nav>${nav.map(c => `<a href="/c/${esc(c.slug)}">${esc(c.name)}</a>`).join('')}</nav>
</header>
<main>${body}</main>
<footer>Local development build. Livestock ships only inside a safe weather window.</footer>
</body></html>`;
}

const card = (p: ProductSummary) => `
<a class="card" href="/p/${esc(p.slug)}">
  ${photo(p.imageKey, p.name, '4/3')}
  <div class="card-head">
    <span class="name">${esc(p.name)}</span>
    ${p.livestock ? '<span class="tag live">LIVE</span>' : ''}
  </div>
  <p class="summary">${esc(p.summary)}</p>
  <span class="price">${esc(money(p))}</span>
</a>`;

/**
 * A section tile.
 *
 * A section that is announced but not stocked renders as an inert `<span>`
 * rather than a dead `<a>`: a link that goes nowhere is worse than no link,
 * and a customer who clicks it learns nothing. The count comes from the
 * subtree, because a "Cichlids" tile holding six fish two levels down should
 * say six, not nothing.
 */
const tile = (c: CategoryView) => {
  const count = c.browsable
    ? (c.totalProducts > 0
        ? `${c.totalProducts} in stock`
        : (c.childCount > 0 ? `${c.childCount} sections` : 'Nothing stocked yet'))
    : 'Coming soon';
  const inner = `
    ${photo(c.imageKey, c.name, '16/9')}
    <span class="name">${esc(c.name)}</span>
    <p class="summary">${esc(c.teaser ?? c.description ?? '')}</p>
    <span class="count">${esc(count)}</span>`;
  return c.browsable
    ? `<a class="tile" href="/c/${esc(c.slug)}">${inner}</a>`
    : `<span class="tile soon" aria-disabled="true">${inner}</span>`;
};

/**
 * The trail back to the shop front.
 *
 * Six levels deep, a customer without this has no idea where they are and no
 * way up except the browser's back button.
 */
const crumbs = (trail: CategoryView[], here: string) => `
<nav class="trail" aria-label="Breadcrumb">
  <a href="/">Shop</a>
  ${trail.map(c => `<span>/</span><a href="/c/${esc(c.slug)}">${esc(c.name)}</a>`).join('')}
  <span>/</span><b>${esc(here)}</b>
</nav>`;

export function categoryPage(
  nav: CategoryView[], page: CategoryPage, products: ProductSummary[], showingAll: boolean,
) {
  const c = page.category;
  const hasSections = page.children.length > 0;

  // The escape hatch. Without it the deepest fish in the shop is five correct
  // guesses away from the front door.
  const shortcut = hasSections && c.totalProducts > 0
    ? (showingAll
        ? `<p class="shortcut"><a href="/c/${esc(c.slug)}">Back to sections</a></p>`
        : `<p class="shortcut">${c.totalProducts} in stock across ${page.children.length}
             section${page.children.length > 1 ? 's' : ''}.
             <a href="/c/${esc(c.slug)}?all=1">Browse all ${c.totalProducts}</a></p>`)
    : '';

  const sections = hasSections && !showingAll
    ? `<section class="tiles">${page.children.map(tile).join('')}</section>`
    : '';

  const listing = products.length
    ? `<section class="grid">${products.map(card).join('')}</section>`
    : (hasSections ? '' : `<p class="empty">Nothing stocked here yet. Tell us what you are
         looking for and we will source it on the next import.</p>`);

  return layout(c.name, nav, `
    ${crumbs(page.breadcrumb, c.name)}
    <h1>${esc(c.name)}</h1>
    <p class="lede">${esc(c.description ?? c.teaser ?? '')}</p>
    ${shortcut}
    ${sections}
    ${listing}`);
}

export function homePage(nav: CategoryView[], featured: ProductSummary[]) {
  return layout('Home', nav, `
    <h1>Freshwater livestock, plants and hardscape</h1>
    <p class="lede">Every living animal we sell carries a full care profile. Read it before you buy.</p>
    <section class="grid">${featured.map(card).join('')}</section>`);
}

export function productPage(nav: CategoryView[], d: ProductDetail) {
  const p = d.product;
  const s = d.species;
  const care = s ? `
    <section class="care">
      <h2>Care profile</h2>
      <p class="sci">${esc(s.scientificName)}</p>
      <dl>
        <div><dt>Adult size</dt><dd>${esc(s.maxSizeCm)} cm</dd></div>
        <div><dt>Minimum tank</dt><dd>${esc(s.minTankLitres)} L</dd></div>
        <div><dt>Minimum group</dt><dd>${esc(s.minGroupSize)}</dd></div>
        <div><dt>Temperature</dt><dd>${esc(range(s.temperatureC, ' \u00B0C'))}</dd></div>
        <div><dt>pH</dt><dd>${esc(range(s.ph, ''))}</dd></div>
        <div><dt>Hardness</dt><dd>${esc(range(s.dgh, ' dGH'))}</dd></div>
        <div><dt>Temperament</dt><dd>${esc(s.temperament.toLowerCase().replace('_', '-'))}</dd></div>
        <div><dt>Care level</dt><dd>${esc(s.careLevel.toLowerCase())}</dd></div>
        <div><dt>Diet</dt><dd>${esc(s.diet.toLowerCase())}</dd></div>
        <div><dt>Plant safe</dt><dd>${s.plantSafe ? 'yes' : 'no'}</dd></div>
      </dl>
      <p class="notes">${esc(s.careNotes)}</p>
    </section>` : '';

  return layout(p.name, nav, `
    <article class="detail">
      <h1>${esc(p.name)} ${p.livestock ? '<span class="tag live">LIVE</span>' : ''}</h1>
      <p class="lede">${esc(p.summary)}</p>
      <p class="price big">${esc(money(p))}</p>
      <p class="sku">SKU ${esc(p.sku)}</p>
      ${care}
    </article>`);
}

export function errorPage(nav: CategoryView[], status: number, message: string) {
  return layout('Error', nav, `<h1>${status}</h1><p class="lede">${esc(message)}</p>`);
}
