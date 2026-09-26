import type {
  CategoryPage, CategoryView, TreeNode, ProductSummary, ProductDetail, Range,
} from './catalog-client.js';

/**
 * What every page's frame needs from the catalog: the category tree for the
 * sidebar and top bar, and the product names the search box suggests.
 * Fetched and cached once in `server.ts`, not per view.
 */
export interface Chrome {
  tree: TreeNode[];
  suggestions: string[];
}

/** Where a page sits, so the frame can open the sidebar to it and keep the
 *  search box showing what was searched. */
interface Place {
  here?: string;
  query?: string;
  scope?: string;
}

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

/** The slugs from a root down to `slug`, or empty if it is not in the tree. */
function pathTo(tree: TreeNode[], slug: string | undefined): string[] {
  if (!slug) return [];
  for (const n of tree) {
    if (n.slug === slug) return [n.slug];
    const below = pathTo(n.children, slug);
    if (below.length) return [n.slug, ...below];
  }
  return [];
}

/**
 * The category sidebar.
 *
 * Native `<details>`: a click on a section's name opens its subsections in
 * place, with no page load and no JavaScript (ADR 0005). Only the deepest
 * sections are links, so the tree is walked in the sidebar and the one page
 * load is the one that shows fish. Every branch also leads with an
 * "All Cichlids" link to the whole subtree at once, for the customer who
 * knows the kind of fish but not the lake.
 *
 * Open on render: the path to the page being viewed (or to the section a
 * search was narrowed to), so the sidebar shows where the customer is; the
 * first section when there is no such place; and any branch that is the only way on from its
 * parent (Live Fishes -> Freshwater, beside a Saltwater that is not open yet),
 * because a click that can only go one way is a click the customer should not
 * have to make.
 *
 * The photo on hover is a preview, not a link: it lives inside the row, so it
 * cannot be clicked separately, and it is `loading="lazy"` inside a
 * `display:none` box, so the forty photographs are not fetched until someone
 * actually hovers.
 */
function sidebar(tree: TreeNode[], here: string | undefined, scope: string | undefined): string {
  // A search narrowed to one section opens that section, without marking it
  // as the current page -- the customer is on a results page, not in it.
  const open = new Set(pathTo(tree, here ?? scope));
  if (!open.size && tree[0]) open.add(tree[0].slug);

  const peek = (n: TreeNode) => n.imageKey
    ? `<span class="peek" aria-hidden="true"><img src="${esc(IMAGE_BASE)}/${esc(n.imageKey)}" alt=""
         loading="lazy" decoding="async" onerror="this.remove()"><b>${esc(n.name)}</b></span>`
    : '';
  const count = (n: TreeNode) =>
    n.totalProducts > 0 ? `<span class="side-count">${n.totalProducts}</span>` : '';

  const node = (n: TreeNode): string => {
    if (!n.browsable) {
      return `<li><span class="side-link side-soon">${esc(n.name)}<span class="side-count">soon</span></span></li>`;
    }
    const current = n.slug === here ? ' aria-current="page"' : '';
    if (!n.children.length) {
      return `<li><a class="side-link" href="/c/${esc(n.slug)}"${current}>${esc(n.name)}${count(n)}${peek(n)}</a></li>`;
    }
    const onward = n.children.filter(c => c.browsable);
    if (onward.length === 1 && onward[0]!.children.length && open.has(n.slug)) open.add(onward[0]!.slug);
    const all = n.totalProducts > 0 ? `/c/${esc(n.slug)}?all=1` : `/c/${esc(n.slug)}`;
    return `<li><details${open.has(n.slug) ? ' open' : ''}>
      <summary class="side-link">${esc(n.name)}${count(n)}${peek(n)}</summary>
      <ul><li><a class="side-link side-all" href="${all}"${current}>All ${esc(n.name)}</a></li>${
        n.children.map(node).join('')}</ul>
    </details></li>`;
  };

  return `<aside class="side" aria-label="Shop by category">
    <p class="side-title">Browse the shop</p>
    <ul class="side-tree">${tree.map(node).join('')}</ul>
  </aside>`;
}

/**
 * The one search box, on every page.
 *
 * A plain GET form, so a search is a URL a customer can bookmark or send, and
 * it works with JavaScript off. The section picker narrows it to one part of
 * the shop -- "wood" in Aquarium Supplies means hardscape -- and defaults to
 * everything.
 *
 * The suggestions are a `<datalist>`: the browser's own type-ahead, no script.
 * The cost is that it offers every product name whatever section is picked,
 * because narrowing it as the picker changes would take JavaScript; and it
 * ships every name on every page, which is a few KB at ~70 products and would
 * want replacing with a real suggest endpoint somewhere in the thousands.
 */
function searchBox(chrome: Chrome, place: Place): string {
  const sections = chrome.tree.filter(r => r.browsable).map(r =>
    `<option value="${esc(r.slug)}"${r.slug === place.scope ? ' selected' : ''}>${esc(r.name)}</option>`);
  return `<form class="search" action="/search" method="get" role="search">
    <select name="in" aria-label="Search in">
      <option value="">Everything</option>${sections.join('')}
    </select>
    <input type="search" name="q" list="search-suggest" maxlength="100" autocomplete="off"
           placeholder="Search fish, plants, supplies…" aria-label="Search the shop"
           value="${esc(place.query ?? '')}">
    <button type="submit" aria-label="Search"><svg viewBox="0 0 20 20" width="17" height="17"
      aria-hidden="true"><circle cx="8.5" cy="8.5" r="6" fill="none" stroke="currentColor"
      stroke-width="2"/><path d="M13 13l5 5" stroke="currentColor" stroke-width="2"
      stroke-linecap="round"/></svg></button>
    <datalist id="search-suggest">${chrome.suggestions.map(n => `<option value="${esc(n)}">`).join('')}</datalist>
  </form>`;
}

function layout(title: string, chrome: Chrome, body: string, place: Place = {}): string {
  return `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)} &middot; AquaShop</title>
<link rel="stylesheet" href="/static/styles.css">
</head><body>
<header class="top">
  <div class="top-inner">
  <a class="brand" href="/">Aqua<span>Shop</span></a>
  ${searchBox(chrome, place)}
  <!-- Checkbox-hack menu toggle: no client-side JavaScript (ADR 0005), and it
       has to precede nav in the DOM for the ":checked ~ nav" sibling
       selector that opens it on a phone to work at all. The same checkbox
       also reveals the category sidebar on a phone, via :has(). -->
  <input type="checkbox" id="nav-toggle" class="nav-toggle-input">
  <label for="nav-toggle" class="nav-toggle" aria-label="Menu">&#9776;</label>
  <!-- Roots only. The hover dropdown that used to hang off each one is gone:
       the sidebar shows the same tree, all of it, and two menus offering the
       same sections is one too many. -->
  <nav>${chrome.tree.map(c => c.browsable
      ? `<a href="/c/${esc(c.slug)}">${esc(c.name)}</a>`
      : `<span class="nav-soon">${esc(c.name)}</span>`).join('')}
       <!-- Not a catalogue category, so it cannot come from the nav data, but
            it is one of the shop's main offers and belongs beside the ones
            that are. Anchored to the home page rather than given a page of its
            own: the form is four fields, and a page whose only content is four
            fields is a redirect with extra steps. -->
       <a class="nav-cta" href="/#custom-tank">Custom tank build</a></nav>
  </div>
</header>
<div class="shell">
${sidebar(chrome.tree, place.here, place.scope)}
<main>${body}</main>
</div>
<footer>Local development build. Livestock ships only inside a safe weather window.</footer>
</body></html>`;
}

/**
 * A product card. `showPrice` is false on the homepage shelf on purpose --
 * those six or seven products are "here's what we carry", not a price list,
 * and the price belongs to the moment a customer has actually narrowed down
 * to a section (`/c/malawi` and below), where `categoryPage` passes `true`.
 * Same card, same data, one thing withheld until it's the right page for it.
 */
const card = (p: ProductSummary, showPrice = true, where?: string) => `
<a class="card" href="/p/${esc(p.slug)}">
  ${photo(p.imageKey, p.name, '4/3')}
  <div class="card-body">
    ${where ? `<span class="where">${esc(where)}</span>` : ''}
    <div class="card-head">
      <span class="name">${esc(p.name)}</span>
      ${p.livestock ? '<span class="tag live">LIVE</span>' : ''}
    </div>
    <p class="summary">${esc(p.summary)}</p>
    ${showPrice ? `<span class="price">${esc(money(p))}</span>` : ''}
  </div>
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
    <div class="tile-body">
      <span class="name">${esc(c.name)}</span>
      <p class="summary">${esc(c.teaser ?? c.description ?? '')}</p>
      <span class="count">${esc(count)}</span>
    </div>`;
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
  chrome: Chrome, page: CategoryPage, products: ProductSummary[], showingAll: boolean,
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
    ? `<section class="grid">${products.map(p => card(p)).join('')}</section>`
    : (hasSections ? '' : `<p class="empty">Nothing stocked here yet. Tell us what you are
         looking for and we will source it on the next import.</p>`);

  return layout(c.name, chrome, `
    ${crumbs(page.breadcrumb, c.name)}
    <h1>${esc(c.name)}</h1>
    <p class="lede">${esc(c.description ?? c.teaser ?? '')}</p>
    ${shortcut}
    ${sections}
    ${listing}`, { here: c.slug });
}

/**
 * What a rejected submission has to carry back to the form.
 *
 * Server-rendered, so a validation failure means re-rendering the whole page.
 * Without the typed-in values the customer loses the paragraph they just wrote
 * because they mistyped their phone number, which is the fastest way to make
 * someone not bother a second time.
 */
export interface InquiryFormState {
  error?: string;
  message?: string;
  email?: string;
  phone?: string;
}

/**
 * The custom tank-setup enquiry form.
 *
 * A plain HTML form doing a full-page POST, with no client-side JavaScript —
 * the same decision as the rest of the site (ADR 0005). It works with
 * JavaScript off, it needs no fetch wrapper, and the failure states are just
 * pages.
 *
 * `required` and `type="email"` are the browser's own checks and are worth
 * having because they catch the mistake before a round trip; they are not
 * trusted. The BFF checks again, and order-service checks again after that,
 * because the only validation that counts is the one nearest the database.
 */
const inquiryForm = (state: InquiryFormState) => `
<section class="inquiry" id="custom-tank">
  <h2>Tell us the tank you want</h2>
  <p class="lede">
    Describe the setup and the stocking you have in mind — size, water, plants, the fish you
    want living together — and we will price it, tell you honestly what will not work, and
    come back to you.
  </p>
  ${state.error ? `<p class="form-error" role="alert">${esc(state.error)}</p>` : ''}
  <form method="post" action="/inquiries" class="inquiry-form">
    <label for="message">Your tank, in your own words</label>
    <textarea id="message" name="message" rows="7" maxlength="4000" required
      placeholder="e.g. 120 litres, planted, soft water. I would like a school of cardinal tetras, some otocinclus, and a centrepiece fish that will leave shrimp alone."
      >${esc(state.message ?? '')}</textarea>

    <div class="inquiry-contact">
      <div>
        <label for="email">Email</label>
        <input id="email" name="email" type="email" maxlength="190" required
               autocomplete="email" value="${esc(state.email ?? '')}">
      </div>
      <div>
        <label for="phone">Phone</label>
        <input id="phone" name="phone" type="tel" maxlength="24" required
               autocomplete="tel" value="${esc(state.phone ?? '')}">
      </div>
    </div>

    <button type="submit">Send this to the shop</button>
    <p class="fineprint">
      Your email, phone number and message are encrypted before they are stored, and are used
      only to answer this enquiry. We do not show them anywhere on this site.
    </p>
  </form>
</section>`;

/**
 * The page after a successful submission.
 *
 * Reached by redirect, not rendered from the POST, so a refresh does not send
 * the enquiry twice. The reference is shown because it is the only handle the
 * customer has on the thing they just sent — and it is safe to show, because
 * there is no endpoint that turns it back into their details.
 */
export function inquiryThanksPage(chrome: Chrome, reference: string | null) {
  return layout('Enquiry received', chrome, `
    <section class="thanks">
      <h1>That is with the shop.</h1>
      <p class="lede">
        Someone who keeps fish will read it and come back to you on the email or phone number
        you left. If what you have asked for will not work as described, we will say so —
        that is the point of asking first.
      </p>
      ${reference ? `<p class="sku">Reference ${esc(reference)}</p>` : ''}
      <p><a class="nav-cta" href="/">Back to the shop</a></p>
    </section>`);
}

export function homePage(
  chrome: Chrome, featured: ProductSummary[], inquiry: InquiryFormState = {},
) {
  // The sections first, then a handful of stock beneath them.
  //
  // The route has always fetched both and this view rendered only the second
  // half, so the shop front was a flat alphabetical product list with the
  // sections reachable from the nav bar alone. That is the opposite of how the
  // catalogue is built: it is a tree six levels deep precisely so a customer
  // can arrive knowing "I want a cichlid" and walk down to one. Six products in
  // alphabetical order gives them nowhere to start.
  //
  // Same `tile` as every other level of the tree, so a COMING_SOON section is
  // greyed out here exactly as Saltwater is one level down.
  //
  // The enquiry form sits directly under the sections, above the stock shelf.
  // It is one of the shop's main offers rather than an afterthought, and a
  // customer who wants a whole tank built should not have to scroll past six
  // fish to find where to ask. It is also where the page goes back to when a
  // submission is rejected, which is why `homePage` takes the form state.
  return layout('Home', chrome, `
    <section class="hero">
      <h1>Freshwater livestock, plants and hardscape</h1>
      <p class="lede">Every living animal we sell carries a full care profile. Read it before you buy.</p>
    </section>
    <h2 class="section-label">Shop by category</h2>
    <section class="tiles">${chrome.tree.map(tile).join('')}</section>
    ${inquiryForm(inquiry)}
    <h2 class="section-label">In the shop now</h2>
    <section class="grid">${featured.map(p => card(p, false)).join('')}</section>`);
}

export function productPage(chrome: Chrome, d: ProductDetail) {
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

  return layout(p.name, chrome, `
    <article class="detail">
      ${photo(p.imageKey, p.name, '4/3')}
      <h1>${esc(p.name)} ${p.livestock ? '<span class="tag live">LIVE</span>' : ''}</h1>
      <p class="lede">${esc(p.summary)}</p>
      <p class="price big">${esc(money(p))}</p>
      <p class="sku">SKU ${esc(p.sku)}</p>
      ${care}
    </article>`, { here: p.categorySlug });
}

export function errorPage(chrome: Chrome, status: number, message: string) {
  return layout('Error', chrome, `<h1>${status}</h1><p class="lede">${esc(message)}</p>`);
}

/** Every category's name by slug, for labelling a search result with where it lives. */
function namesBySlug(tree: TreeNode[], into = new Map<string, string>()): Map<string, string> {
  for (const n of tree) { into.set(n.slug, n.name); namesBySlug(n.children, into); }
  return into;
}

/**
 * Search results.
 *
 * Each card says which section the product is filed in, because a search
 * across the whole shop mixes a Malawi cichlid with a pleco with a bag of
 * food, and the section is what tells a customer which one they meant.
 *
 * An empty result says where it looked, and offers the one next step that
 * might work: the whole shop if it was narrowed, otherwise asking the shop to
 * source it -- which is a real offer here, not a dead end dressed up.
 */
export function searchPage(
  chrome: Chrome, query: string, scope: TreeNode | undefined, results: ProductSummary[],
) {
  const where = scope ? `in ${scope.name}` : 'across the whole shop';
  const names = namesBySlug(chrome.tree);

  const body = results.length
    ? `<p class="lede">${results.length} result${results.length === 1 ? '' : 's'} ${esc(where)}.</p>
       <section class="grid">${results.map(p => card(p, true, names.get(p.categorySlug))).join('')}</section>`
    : `<p class="empty">Nothing ${esc(where)} matches that.
         ${scope
           ? `<a href="/search?q=${encodeURIComponent(query)}">Search the whole shop instead</a>, or`
           : ''}
         <a href="/#custom-tank">tell us what you are looking for</a> and we will source it on the next import.</p>`;

  return layout(`Search: ${query}`, chrome, `
    <h1>&ldquo;${esc(query)}&rdquo;</h1>
    ${body}`, { query, scope: scope?.slug });
}
