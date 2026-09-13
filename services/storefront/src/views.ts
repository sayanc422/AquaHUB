import type { CategoryView, ProductSummary, ProductDetail, Range } from './catalog-client.js';

const esc = (s: unknown): string =>
  String(s ?? '').replace(/[&<>"']/g, c =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));

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
  <div class="card-head">
    <span class="name">${esc(p.name)}</span>
    ${p.livestock ? '<span class="tag live">LIVE</span>' : ''}
  </div>
  <p class="summary">${esc(p.summary)}</p>
  <span class="price">${esc(money(p))}</span>
</a>`;

export function categoryPage(nav: CategoryView[], current: CategoryView, products: ProductSummary[]) {
  return layout(current.name, nav, `
    <h1>${esc(current.name)}</h1>
    <p class="lede">${esc(current.description)}</p>
    <section class="grid">${products.map(card).join('')}</section>`);
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
