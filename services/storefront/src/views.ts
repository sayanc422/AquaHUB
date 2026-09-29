import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import type {
  CategoryPage, CategoryView, TreeNode, ProductSummary, ProductDetail, Range,
} from './catalog-client.js';
import type { Assessment, Band, Finding, Verdict } from './advisor-client.js';

/**
 * What every page's frame needs from the catalog: the category tree for the
 * sidebar and top bar, the product names the search box suggests, and the
 * product list itself -- which the shop front's shelf, the tank checker's
 * name-to-SKU lookup and the enquiry prefill all read, so it is fetched once
 * in `server.ts`'s cache rather than once per feature.
 */
export interface Chrome {
  tree: TreeNode[];
  suggestions: string[];
  products: ProductSummary[];
}

/** Where a page sits, so the frame can open the sidebar to it and keep the
 *  search box showing what was searched. */
interface Place {
  here?: string;
  query?: string;
  scope?: string;
  /** Full-bleed content rendered between the header and the sidebar shell. */
  hero?: string;
  description?: string;
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
 * Whether card-sized WebP copies exist beside the photographs.
 *
 * The storefront image sets this (Dockerfile) because its build stage writes
 * them; a bare `npm run dev` checkout has none, and a srcset pointing at files
 * that do not exist would put a placeholder on every card. A CDN move has to
 * carry `variants/` with it -- the same promise as the keys themselves.
 */
const VARIANTS = process.env.IMAGE_VARIANTS === '1';

/**
 * The stylesheet's content hash, appended to its URL.
 *
 * It lets `server.ts` serve CSS as `immutable` for a year: a changed file is a
 * changed URL, so no browser ever holds a stale one, and an unchanged one is
 * never re-requested -- not even the 304 revalidation every page view paid
 * before (`max-age=0` was the default).
 */
const here = dirname(fileURLToPath(import.meta.url));
const CSS_VERSION = createHash('sha1')
  .update(readFileSync(join(here, '..', 'public', 'styles.css')))
  .digest('hex').slice(0, 10);

interface PhotoOptions {
  /** The `sizes` attribute: how wide this slot is at each breakpoint. */
  sizes?: string;
  /** Above the fold: fetch now, and first. */
  eager?: boolean;
  /**
   * A `view-transition-name`, so this photo morphs into the next page's.
   * Carried as `--vt` and switched on by the stylesheet only where it is
   * wanted (the card under the pointer, the product page's hero): every named
   * element is snapshotted on every navigation, and a "browse all" page has
   * 149 cards.
   */
  morph?: string;
}

/**
 * A photograph, or an honest gap where one goes.
 *
 * Lazy by default and with an explicit aspect ratio, so a page of forty fish
 * does not fetch forty images and does not reflow as each one lands. With
 * variants on, the browser picks a 480 or 960 px WebP for the slot and only
 * the product page's hero ever reaches for the original.
 *
 * Two ways there can be no picture, and both land on the same placeholder:
 *
 *   * **no key** -- the catalog has no photograph for this product yet;
 *   * **a key whose file is missing** -- the catalog names a photograph that
 *     has not been taken, or has not been uploaded to the CDN yet.
 *
 * The second is handled in the browser because only the browser knows: the
 * storefront cannot see a CDN's contents, and checking would mean a request per
 * image on every render. A page full of broken-image icons reads as a broken
 * site; a page of quiet placeholders reads as an incomplete catalogue, which is
 * the truth.
 */
function photo(key: string | null, alt: string, ratio: string, o: PhotoOptions = {}): string {
  const morph = o.morph ? `;--vt:${o.morph}` : '';
  if (!key) {
    return `<span class="shot shot-none" style="aspect-ratio:${ratio}${morph}" aria-hidden="true"></span>`;
  }
  const src = `${IMAGE_BASE}/${key}`;
  const srcset = VARIANTS && key.endsWith('.jpg')
    ? ` srcset="${esc([480, 960].map(w =>
        `${IMAGE_BASE}/variants/${w}/${key.replace(/\.jpg$/, '.webp')} ${w}w`).join(', '))}, ${esc(src)} 1600w"
        sizes="${esc(o.sizes ?? '(max-width: 640px) 92vw, 360px')}"`
    : '';
  return `<img class="shot" style="aspect-ratio:${ratio}${morph}" src="${esc(src)}"${srcset}
      alt="${esc(alt)}" ${o.eager ? 'fetchpriority="high"' : 'loading="lazy"'} decoding="async"
      onerror="this.removeAttribute('srcset');this.removeAttribute('src');this.classList.add('shot-none');this.alt=''">`;
}

/** A slug as a `view-transition-name`: an ident, unique per product. */
const morphName = (slug: string) => `p-${slug.replace(/[^a-z0-9-]/gi, '')}`;

const money = (p: ProductSummary) =>
  p.currency === 'INR'
    ? `₹${Number(p.price).toLocaleString('en-IN', { minimumFractionDigits: 0, maximumFractionDigits: 2 })}`
    : `${p.currency} ${p.price}`;

const range = (r: Range, unit: string) => `${r.min}–${r.max}${unit}`;

/** NOT_NEEDED -> "not needed": enum names are the contract, words are the page's job. */
const words = (e: string) => e.toLowerCase().replace(/_/g, ' ');

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

/** Any category in the tree, by slug. */
function findNode(tree: TreeNode[], slug: string): TreeNode | undefined {
  for (const n of tree) {
    if (n.slug === slug) return n;
    const below = findNode(n.children, slug);
    if (below) return below;
  }
  return undefined;
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
 * cannot be clicked separately, and it is `loading="lazy"` inside a box that
 * is `display:none` until the row is hovered, so the forty photographs are not
 * fetched until someone actually hovers. That last clause was written before
 * it was true -- the box used to be `visibility:hidden`, which lazy-loading
 * ignores; see the `.peek` rule in styles.css.
 */
function sidebar(tree: TreeNode[], here: string | undefined, scope: string | undefined): string {
  // A search narrowed to one section opens that section, without marking it
  // as the current page -- the customer is on a results page, not in it.
  const open = new Set(pathTo(tree, here ?? scope));
  if (!open.size && tree[0]) open.add(tree[0].slug);

  const peek = (n: TreeNode) => n.imageKey
    ? `<span class="peek" aria-hidden="true"><img src="${esc(IMAGE_BASE)}/${esc(
        VARIANTS ? `variants/480/${n.imageKey.replace(/\.jpg$/, '.webp')}` : n.imageKey)}" alt=""
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

  // The checkbox and its label are the phone and tablet version: a
  // "Browse categories" bar above the page that opens the same tree. Hidden
  // on desktop, where the sidebar is always there. Its own checkbox rather
  // than the menu's, because a customer looking for a fish should not have to
  // guess that the categories live behind the ☰.
  return `<input type="checkbox" id="side-toggle" class="side-toggle-input">
  <label for="side-toggle" class="side-toggle">Browse categories</label>
  <aside class="side" aria-label="Shop by category">
    <p class="side-title">Browse the shop</p>
    <ul class="side-tree">${tree.map(node).join('')}</ul>
    <a class="side-tool" href="/compatibility">${icons.check}<span>Will they live together?<small>Check a tank before you buy</small></span></a>
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
 * ships every name on every page -- ~7 KB at 220 products, ~1.5 KB once
 * compressed -- which would want replacing with a real suggest endpoint
 * somewhere in the thousands.
 */
function searchBox(chrome: Chrome, place: Place): string {
  const sections = chrome.tree.filter(r => r.browsable).map(r =>
    `<option value="${esc(r.slug)}"${r.slug === place.scope ? ' selected' : ''}>${esc(r.name)}</option>`);
  return `<form class="search" action="/search" method="get" role="search">
    <select name="in" aria-label="Search in">
      <option value="">Everything</option>${sections.join('')}
    </select>
    <input type="search" name="q" list="search-suggest" maxlength="100" autocomplete="off"
           placeholder="Search the shop" aria-label="Search the shop"
           value="${esc(place.query ?? '')}">
    <button type="submit" aria-label="Search">${icons.search}</button>
    <datalist id="search-suggest">${chrome.suggestions.map(n => `<option value="${esc(n)}">`).join('')}</datalist>
  </form>`;
}

/**
 * Speculation rules: the browser fetches a page while the cursor is still on
 * its way to the link, and fully renders it once the button is down, so the
 * click itself lands on a page that is already there.
 *
 * This is the one `<script>` element on the site, and it is not client-side
 * JavaScript in the sense ADR 0005 rules out -- it is a JSON declaration the
 * browser reads, with no code, no state and no build step. A browser that does
 * not support it (Firefox, Safari today) ignores it and the site is exactly
 * what it was. `moderate` prefetch and `conservative` prerender, not
 * `eager`: every speculation is a real request to the catalog, and a page
 * nobody opens is load the cluster pays for.
 */
const SPECULATION = JSON.stringify({
  prefetch: [{ where: { and: [{ href_matches: '/*' }, { not: { href_matches: '/static/*' } }] }, eagerness: 'moderate' }],
  prerender: [{ where: { href_matches: '/p/*' }, eagerness: 'conservative' }],
});

function layout(title: string, chrome: Chrome, body: string, place: Place = {}): string {
  return `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>${esc(title)} &middot; AquaShop</title>
<meta name="description" content="${esc(place.description ?? 'Freshwater fish, invertebrates and live plants, each with a full care profile, and an honest answer about whether they will live together before you buy.')}">
<meta name="theme-color" content="#e9f3f8" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#03121f" media="(prefers-color-scheme: dark)">
<link rel="preload" href="/static/fonts/fraunces-latin-wght-normal.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="/static/styles.css?v=${CSS_VERSION}">
<link rel="icon" href="data:image/svg+xml,${encodeURIComponent(FAVICON)}">
<script type="speculationrules">${SPECULATION}</script>
</head><body>
<a class="skip" href="#main">Skip to content</a>
<header class="top">
  <div class="top-inner">
  <a class="brand" href="/" aria-label="AquaShop, home">${icons.mark}<span>Aqua<em>Shop</em></span></a>
  ${searchBox(chrome, place)}
  <!-- Checkbox-hack menu toggle: no client-side JavaScript (ADR 0005), and it
       has to precede nav in the DOM for the ":checked ~ nav" sibling
       selector that opens it on a phone to work at all. -->
  <input type="checkbox" id="nav-toggle" class="nav-toggle-input">
  <label for="nav-toggle" class="nav-toggle" aria-label="Menu"><span></span></label>
  <!-- Roots only. The sidebar shows the same tree, all of it, and two menus
       offering the same sections is one too many. -->
  <nav>${chrome.tree.map(c => c.browsable
      ? `<a href="/c/${esc(c.slug)}">${esc(c.name)}</a>`
      : `<span class="nav-soon">${esc(c.name)}</span>`).join('')}
       <a href="/compatibility">Tank checker</a>
       <!-- Not a catalogue category, so it cannot come from the nav data, but
            it is one of the shop's main offers and belongs beside the ones
            that are. -->
       <a class="nav-cta" href="/#custom-tank">Custom tank build</a></nav>
  </div>
</header>
${place.hero ?? ''}
<div class="shell">
${sidebar(chrome.tree, place.here, place.scope)}
<main id="main">${body}</main>
</div>
${footer(chrome)}
</body></html>`;
}

/**
 * The shop's contact details, from the environment rather than the template,
 * so a real number replacing the placeholder is a manifest change, not a build.
 *
 * WhatsApp because that is how Indian customers actually ask a fish shop a
 * question; email for anything with a photo or an invoice attached. A value
 * that is still the placeholder (fewer than 10 digits -- "+91 XXXXX XXXXX" has
 * none) renders as plain text, not a link: a wa.me link to a number nobody owns
 * looks like it works and silently goes nowhere, which is worse than no link.
 */
const WHATSAPP = process.env.CONTACT_WHATSAPP ?? '+91 XXXXX XXXXX';
const EMAIL = process.env.CONTACT_EMAIL ?? 'contact@example.com';
const WHATSAPP_GREETING = 'Hi AquaShop, I have a question about ';
const waDigits = WHATSAPP.replace(/\D/g, '');

/** A wa.me link with a message typed in, or null while the number is a placeholder. */
const whatsappHref = (text: string) =>
  waDigits.length >= 10 ? `https://wa.me/${waDigits}?text=${encodeURIComponent(text)}` : null;

function footer(chrome: Chrome): string {
  const waHref = whatsappHref(WHATSAPP_GREETING);
  const wa = waHref
    ? `<a class="contact-link" href="${esc(waHref)}" target="_blank" rel="noopener">${icons.chat}<span>WhatsApp<small>${esc(WHATSAPP)}</small></span></a>`
    : `<span class="contact-link contact-unset">${icons.chat}<span>WhatsApp<small>${esc(WHATSAPP)}</small></span></span>`;
  const mail = EMAIL.includes('@')
    ? `<a class="contact-link" href="mailto:${esc(EMAIL)}">${icons.mail}<span>Email<small>${esc(EMAIL)}</small></span></a>`
    : `<span class="contact-link contact-unset">${icons.mail}<span>Email<small>${esc(EMAIL)}</small></span></span>`;
  return `<footer class="deep">
  <div class="deep-inner">
    <section class="contact" id="contact" aria-labelledby="contact-h">
      <p class="eyebrow">Talk to someone who keeps fish</p>
      <h2 id="contact-h">Contact us</h2>
      <p>Questions about a fish, a tank or an order? Message us &mdash; we reply during shop hours.</p>
      <div class="contact-links">${wa}${mail}</div>
    </section>
    <nav class="foot-nav" aria-label="Footer">
      <div><h3>Shop</h3>${chrome.tree.filter(r => r.browsable)
        .map(r => `<a href="/c/${esc(r.slug)}">${esc(r.name)}</a>`).join('')}</div>
      <div><h3>Plan a tank</h3>
        <a href="/compatibility">Will they live together?</a>
        <a href="/#custom-tank">Custom tank build</a>
        <a href="/search?q=beginner">Beginner-friendly fish</a></div>
    </nav>
  </div>
  <p class="footnote">Livestock leaves Monday to Wednesday only, before the 14:00 courier &mdash; never into a weekend depot.</p>
</footer>`;
}

const icons = {
  mark: `<svg class="mark" viewBox="0 0 32 32" width="28" height="28" aria-hidden="true"><path fill="currentColor"
    d="M4 16c3.6-5 8-7.5 13-7.5 4.2 0 7.4 1.8 9.6 4.2L31 9.5v13l-4.4-3.2C24.4 21.7 21.2 23.5 17 23.5c-5 0-9.4-2.5-13-7.5z"/>
    <circle cx="11" cy="15" r="1.6" fill="var(--mark-eye)"/></svg>`,
  search: `<svg viewBox="0 0 20 20" width="17" height="17" aria-hidden="true"><circle cx="8.5" cy="8.5" r="6"
    fill="none" stroke="currentColor" stroke-width="2"/><path d="M13 13l5 5" stroke="currentColor" stroke-width="2"
    stroke-linecap="round"/></svg>`,
  check: `<svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true"><path fill="none" stroke="currentColor"
    stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" d="M3 12c2-3 5-5 8-5s6 2 8 5c-2 3-5 5-8 5s-6-2-8-5z"/>
    <path fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" d="M8.5 12l2 2 4-4"/></svg>`,
  profile: `<svg viewBox="0 0 24 24" width="26" height="26" aria-hidden="true"><rect x="4" y="3" width="16" height="18" rx="2.5"
    fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M8 8h8M8 12h8M8 16h5" stroke="currentColor"
    stroke-width="1.7" stroke-linecap="round"/></svg>`,
  van: `<svg viewBox="0 0 24 24" width="26" height="26" aria-hidden="true"><path fill="none" stroke="currentColor"
    stroke-width="1.7" stroke-linejoin="round" d="M2.5 6.5h11v9h-11zM13.5 9.5h4l3 3v3h-7z"/><circle cx="6.5" cy="17"
    r="1.8" fill="none" stroke="currentColor" stroke-width="1.7"/><circle cx="17" cy="17" r="1.8" fill="none"
    stroke="currentColor" stroke-width="1.7"/></svg>`,
  chat: `<svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true"><path fill="none"
    stroke="currentColor" stroke-width="1.8" stroke-linejoin="round" d="M12 3a9 9 0 0 0-7.8 13.5L3 21l4.6-1.2A9 9 0 1 0 12 3z"/>
    <path fill="currentColor" d="M8.7 7.8c.2-.4.5-.4.7-.4h.5c.2 0 .4 0 .5.4l.7 1.7c.1.2.1.4 0 .6l-.5.6c-.1.1-.2.3 0 .5.4.7 1 1.4 1.7 1.9.3.2.6.4.9.5.2.1.4 0 .5-.1l.6-.7c.1-.2.3-.2.5-.1l1.6.8c.2.1.4.2.4.3 0 .3 0 1-.4 1.4-.4.5-1.3.9-2 .8-.8-.1-2.3-.6-3.7-1.9-1.4-1.3-2.2-2.8-2.4-3.6-.2-.8.2-1.8.4-2.3z"/></svg>`,
  mail: `<svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true"><rect x="3" y="5" width="18" height="14"
    rx="2" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M3.5 6.5l8.5 6.5 8.5-6.5" fill="none"
    stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>`,
  arrow: `<svg viewBox="0 0 20 20" width="16" height="16" aria-hidden="true"><path d="M4 10h11M11 5.5 15.5 10 11 14.5"
    fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
};

const FAVICON = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="8" fill="#062033"/><path fill="#3fe0b0" d="M5 16c3.3-4.4 7.2-6.6 11.6-6.6 3.7 0 6.5 1.6 8.4 3.7L28.5 10v12L25 18.9c-1.9 2.1-4.7 3.7-8.4 3.7C12.2 22.6 8.3 20.4 5 16z"/></svg>`;

/**
 * A product card. `showPrice` is false on the homepage shelf on purpose --
 * those products are "here's what we carry", not a price list, and the price
 * belongs to the moment a customer has actually narrowed down to a section
 * (`/c/malawi` and below), where `categoryPage` passes `true`. Same card, same
 * data, one thing withheld until it's the right page for it.
 *
 * The photograph carries the product's `view-transition-name`, and so does the
 * product page's hero: in a browser with cross-document view transitions the
 * card's photo grows into the page's, which is the single thing on this site
 * that most makes it feel like an app without being one.
 */
const card = (p: ProductSummary, showPrice = true, where?: string) => `
<a class="card reveal" href="/p/${esc(p.slug)}">
  <div class="card-shot">${photo(p.imageKey, p.name, '4/3', { morph: morphName(p.slug) })}
    ${p.livestock ? '<span class="tag live">Live</span>' : ''}</div>
  <div class="card-body">
    ${where ? `<span class="where">${esc(where)}</span>` : ''}
    <span class="name">${esc(p.name)}</span>
    <p class="summary">${esc(p.summary)}</p>
    <span class="card-foot">${showPrice ? `<span class="price">${esc(money(p))}</span>` : '<span class="more">See the fish</span>'}${icons.arrow}</span>
  </div>
</a>`;

/**
 * A section tile: the photograph is the tile, with the name set over it.
 * 16:9, because every section photograph is 16:9 (sections/README.md): a
 * 4:3 box cut a quarter off each one.
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
    ${photo(c.imageKey, '', '16/9', { sizes: '(max-width: 640px) 92vw, 460px' })}
    <div class="tile-body">
      <span class="count">${esc(count)}</span>
      <span class="name">${esc(c.name)}</span>
      <p class="summary">${esc(c.teaser ?? c.description ?? '')}</p>
    </div>`;
  return c.browsable
    ? `<a class="tile reveal" href="/c/${esc(c.slug)}">${inner}</a>`
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

/**
 * How a listing can be ordered. `featured` is the catalog's own order; the
 * rest are done here, on the page's own products, because there are at most a
 * few hundred and the catalog has no sort parameter to ask for.
 */
export type Sort = 'featured' | 'price-asc' | 'price-desc' | 'name';
const SORTS: [Sort, string][] = [
  ['featured', 'Featured'], ['price-asc', 'Price, low to high'],
  ['price-desc', 'Price, high to low'], ['name', 'A–Z'],
];
export const isSort = (s: unknown): s is Sort => SORTS.some(([k]) => k === s);

export function sortProducts(products: ProductSummary[], sort: Sort): ProductSummary[] {
  const by = [...products];
  if (sort === 'price-asc') by.sort((a, b) => Number(a.price) - Number(b.price));
  if (sort === 'price-desc') by.sort((a, b) => Number(b.price) - Number(a.price));
  if (sort === 'name') by.sort((a, b) => a.name.localeCompare(b.name));
  return by;
}

/**
 * A section's description, split in two: the first paragraph is the lede under
 * the name, and anything after it is a keeping guide rendered below the
 * listing. The shrimp sections carry several paragraphs (V24), which is where
 * the shop's shrimp-care writing lives: in the catalogue beside the animals,
 * not in this file. A one-paragraph description renders exactly as before.
 */
function splitDescription(text: string | null): { lede: string; guide: string[] } {
  const paras = (text ?? '').split(/\n\s*\n/).map(p => p.trim()).filter(Boolean);
  return { lede: paras[0] ?? '', guide: paras.slice(1) };
}

export function categoryPage(
  chrome: Chrome, page: CategoryPage, products: ProductSummary[], showingAll: boolean, sort: Sort = 'featured',
) {
  const c = page.category;
  const { lede, guide } = splitDescription(c.description ?? c.teaser);
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

  // Sorting is a set of links, not a <select> that submits itself: without
  // JavaScript a select needs a button beside it, and four links are one
  // click where a select-and-button is two.
  const base = `/c/${esc(c.slug)}?${showingAll ? 'all=1&amp;' : ''}sort=`;
  const sorter = products.length > 1
    ? `<nav class="sorter" aria-label="Sort"><span>${products.length} ${products.length === 1 ? 'product' : 'products'}</span>
        <div>${SORTS.map(([k, label]) => `<a href="${base}${k}"${k === sort ? ' aria-current="true"' : ''}>${label}</a>`).join('')}</div></nav>`
    : '';

  const listing = products.length
    ? `${sorter}<section class="grid">${sortProducts(products, sort).map(p => card(p)).join('')}</section>`
    : (hasSections ? '' : `<p class="empty">Nothing stocked here yet. <a href="/#custom-tank">Tell us what you are
         looking for</a> and we will source it on the next import.</p>`);

  // The section's photograph as a banner under its name. Every category has
  // one since V14, and a page that opens on the kind of water these fish come
  // from sells them better than a heading alone.
  // Beside the name, at its own 16:9 -- never cropped to a strip under text.
  const banner = c.imageKey
    ? `<div class="banner">${photo(c.imageKey, '', '16/9', { eager: true, sizes: '(max-width: 1100px) 94vw, 640px' })}
         <div class="banner-text">${crumbs(page.breadcrumb, c.name)}
           <h1>${esc(c.name)}</h1>
           <p class="lede">${esc(lede)}</p></div></div>`
    : `${crumbs(page.breadcrumb, c.name)}<h1>${esc(c.name)}</h1>
       <p class="lede">${esc(lede)}</p>`;

  const keeping = guide.length
    ? `<section class="guide reveal"><p class="eyebrow">Keeping them well</p>
         <h2>${esc(c.name)}: what they need</h2>
         ${guide.map(p => `<p>${esc(p)}</p>`).join('')}</section>`
    : '';

  return layout(c.name, chrome, `
    ${banner}
    ${shortcut}
    ${sections}
    ${listing}
    ${keeping}`, { here: c.slug, description: lede || undefined });
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
 * The custom tank-setup enquiry form, beside a picture of what it is for.
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
const inquiryForm = (state: InquiryFormState, art: string | null) => `
<section class="inquiry reveal" id="custom-tank">
  <div class="inquiry-art">
    ${art ? photo(art, '', '4/5', { sizes: '(max-width: 900px) 92vw, 460px' }) : ''}
    <div class="inquiry-pitch">
      <p class="eyebrow">Custom tank build</p>
      <h2>Tell us the tank you want.</h2>
      <ol class="steps">
        <li><span><b>You describe it</b> &mdash; size, water, plants, the fish you want together.</span></li>
        <li><span><b>We check it</b> against the same rules as the tank checker, and say plainly what will not work.</span></li>
        <li><span><b>We price it</b> and come back to you by email or phone.</span></li>
      </ol>
    </div>
  </div>
  <div class="inquiry-body">
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

    <button type="submit" class="btn">Send this to the shop</button>
    <p class="fineprint">
      Your email, phone number and message are encrypted before they are stored, and are used
      only to answer this enquiry. We do not show them anywhere on this site.
    </p>
  </form>
  </div>
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
      <p class="eyebrow">Enquiry received</p>
      <h1>That is with the shop.</h1>
      <p class="lede">
        Someone who keeps fish will read it and come back to you on the email or phone number
        you left. If what you have asked for will not work as described, we will say so —
        that is the point of asking first.
      </p>
      ${reference ? `<p class="sku">Reference ${esc(reference)}</p>` : ''}
      <p><a class="btn" href="/">Back to the shop</a></p>
    </section>`);
}

/**
 * The homepage's editorial collections: a handful of sections worth a closer
 * look, each on a photograph chosen for the panel it sits in.
 *
 * Two rules, both learnt from the owner's first look at this block
 * (28 September 2026), when a tall panel showed a betta's fin and nothing
 * else and a wide one cut the arowana's back off:
 *
 * - **The panel takes the photograph's shape, not the other way round.**
 *   Every species photograph is 4:3, so the three tiles are 4:3 and show the
 *   whole fish. The arowana is a long fish and gets a panorama of its own,
 *   on a photograph where it runs nose to tail across the frame.
 * - **Nothing is written over the fish.** The caption sits under the photo.
 *
 * The photographs are editorial and live here, not in the catalog: a
 * collection is a shop-front decision about how to show a section, and the
 * section's own tile photo (16:9, a scene) is the wrong shape for it. Each
 * one is a key like every other photo, so a CDN move is unchanged. The
 * names, teasers and counts still come from the catalog, and a slug that is
 * missing or closed drops its panel rather than rendering a dead one.
 */
interface Collection { slug: string; eyebrow: string; image: string; alt: string; focus?: string }

const FEATURE: Collection = {
  slug: 'arowana', eyebrow: 'Showpiece fish',
  image: 'species/asian-arowana-red-tail-golden.jpg',
  alt: 'A red tail golden Asian arowana swimming the length of a dark tank',
  // Measured, not guessed: in the 1400x1050 source the fish runs from y~238
  // (top of the back) to y~663 (anal fin). A 12:5 frame shows 583 px of
  // height, so centring the fish is an offset of ~35%. The first guess, 52%,
  // cut the back off -- the exact complaint this panel exists to answer.
  focus: '50% 35%',
};
const COLLECTIONS: Collection[] = [
  { slug: 'anabantoids', eyebrow: 'Living jewels', image: 'collections/betta-female-crowntail.jpg',
    alt: 'A female crowntail betta, dark blue with red fins, in a planted tank' },
  { slug: 'badidae', eyebrow: 'Small and scarlet', image: 'species/scarlet-badis.jpg',
    alt: 'A scarlet badis over sand' },
  { slug: 'goldfish', eyebrow: 'Fancy goldfish', image: 'species/ryukin-goldfish.jpg',
    alt: 'A red and white ryukin goldfish' },
];

const stocked = (c: Collection, tree: TreeNode[]) => {
  const n = findNode(tree, c.slug);
  return n?.browsable && n.totalProducts > 0 ? n : undefined;
};

const caption = (c: Collection, n: TreeNode) => `
  <span class="collection-text"><span class="eyebrow">${esc(c.eyebrow)}</span>
    <span class="collection-name">${esc(n.name)}</span>
    <span class="collection-teaser">${esc(n.teaser ?? '')}</span>
    <span class="collection-go">${n.totalProducts} in stock ${icons.arrow}</span></span>`;

function collections(tree: TreeNode[]): string {
  const f = stocked(FEATURE, tree);
  const feature = f ? `
    <a class="collection collection-feature reveal" href="/c/${esc(f.slug)}">
      <span class="collection-shot" style="--focus:${esc(FEATURE.focus ?? '50% 50%')}">${photo(FEATURE.image, FEATURE.alt, '12/5',
        { sizes: '(max-width: 900px) 94vw, 1100px' })}</span>
      ${caption(FEATURE, f)}
    </a>` : '';
  const tiles = COLLECTIONS.map(c => ({ c, n: stocked(c, tree) }))
    .filter((x): x is { c: Collection; n: TreeNode } => !!x.n)
    .map(({ c, n }) => `
      <a class="collection reveal" href="/c/${esc(n.slug)}">
        <span class="collection-shot">${photo(c.image, c.alt, '4/3', { sizes: '(max-width: 900px) 92vw, 380px' })}</span>
        ${caption(c, n)}
      </a>`);
  if (!feature && !tiles.length) return '';
  return `<section class="block">
      <div class="block-head"><p class="eyebrow">Collections</p><h2>Fish worth building a tank around</h2></div>
      ${feature}
      ${tiles.length ? `<div class="collections">${tiles.join('')}</div>` : ''}
    </section>`;
}

/**
 * A small version of the tank checker, on the shop front.
 *
 * It submits to `/compatibility` like the full one, so it needs nothing of its
 * own: three rows is enough to ask the question most people arrive with ("can
 * these two go together?") and the answer page offers the rest.
 */
function checkerTeaser(chrome: Chrome): string {
  if (!chrome.products.some(p => p.livestock)) return '';
  return `<section class="checker-teaser reveal" aria-labelledby="checker-h">
    <div class="checker-copy">
      <p class="eyebrow">Only at AquaShop</p>
      <h2 id="checker-h">Will they live <em>together?</em></h2>
      <p>Most shops will sell you any two fish you point at. Ours checks water, tank size, temperament,
        group size and predation first &mdash; and quotes the rule when the answer is no.</p>
    </div>
    <form class="checker-mini" action="/compatibility" method="get">
      <label class="litres"><span>Tank size</span><span class="unit"><input name="litres" type="number" min="1" max="10000"
        inputmode="numeric" placeholder="120" required>L</span></label>
      ${[0, 1, 2].map(i => `<label><span class="sr">Fish ${i + 1}</span><input name="f" list="livestock"
        placeholder="${['e.g. Cardinal Tetra', 'e.g. Honey Gourami', 'Another fish (optional)'][i]}" ${i === 0 ? 'required' : ''}
        autocomplete="off"></label>`).join('')}
      <button class="btn btn-light" type="submit">Check this tank ${icons.arrow}</button>
      ${livestockList(chrome)}
    </form>
  </section>`;
}

/** Every animal the shop sells, as the checker's type-ahead. */
const livestockList = (chrome: Chrome) =>
  `<datalist id="livestock">${chrome.products.filter(p => p.livestock)
    .map(p => `<option value="${esc(p.name)}">`).join('')}</datalist>`;

/**
 * A few photographed animals for the shop front's shelf, changed daily.
 *
 * Seeded by the date, not random per request: every pod shows the same shelf
 * on the same day, a refresh does not reshuffle the page under the customer,
 * and tomorrow's visitor still sees something different. The same seed on two
 * pods is the whole reason this is not `Math.random()`.
 */
export function shelf(products: ProductSummary[], size = 8, day = Math.floor(Date.now() / 86_400_000)) {
  const pool = products.filter(p => p.livestock && p.imageKey).sort((a, b) => a.sku.localeCompare(b.sku));
  let seed = day >>> 0;
  const rand = () => {  // mulberry32: small, fast, and the same everywhere
    seed = (seed + 0x6D2B79F5) >>> 0;
    let t = seed;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  for (let i = pool.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [pool[i], pool[j]] = [pool[j]!, pool[i]!];
  }
  return pool.slice(0, size);
}

export function homePage(chrome: Chrome, inquiry: InquiryFormState = {}) {
  // The hero is the first section's own photograph, so the shop front opens on
  // whatever the shop has chosen to lead with rather than on a stock image.
  const lead = chrome.tree.find(r => r.browsable && r.imageKey);
  const roots = chrome.tree.filter(r => r.browsable && r.totalProducts > 0);
  const stats = roots.map(r => `<li><b>${r.totalProducts}</b><span>${esc(r.name)}</span></li>`).join('');

  // Bubbles and caustic light are CSS only and switched off entirely under
  // prefers-reduced-motion. They are decoration; the page says nothing with
  // them that it does not also say in words.
  const hero = `<section class="hero" aria-labelledby="hero-h">
    ${lead ? photo(lead.imageKey, '', '16/9', { eager: true, sizes: '100vw' }) : ''}
    <div class="hero-light" aria-hidden="true"></div>
    <div class="bubbles" aria-hidden="true">${'<i></i>'.repeat(10)}</div>
    <div class="hero-inner">
      <p class="eyebrow">The freshwater specialist</p>
      <h1 id="hero-h">Bring a living <em>river</em> home.</h1>
      <p class="hero-lede">Fish, shrimp and live plants &mdash; every animal with a full care profile, and an honest
        answer about whether they will live together, before you buy.</p>
      <div class="hero-cta">
        <a class="btn btn-light" href="/c/${esc(lead?.slug ?? 'live-fish')}">Explore the fish ${icons.arrow}</a>
        <a class="btn btn-ghost" href="/compatibility">Will they live together?</a>
      </div>
      ${stats ? `<ul class="hero-stats">${stats}</ul>` : ''}
    </div>
  </section>`;

  // Three promises, each one a rule enforced somewhere in this platform
  // rather than a line of copy: the CHECK constraint that makes a livestock
  // product without a care profile impossible (catalog-service), the
  // advisor's rules file, and order-service's ShippingCalendar. If one stops
  // being true in code, it has to stop being said here.
  const promises = `<section class="promises" aria-label="Why AquaShop">
    <div class="promise reveal">${icons.profile}<h3>A care profile on every animal</h3>
      <p>Adult size, minimum tank, water and temperament on every fish we sell. The shop cannot list one without it.</p></div>
    <div class="promise reveal">${icons.check}<h3>We say so when it will not work</h3>
      <p>The tank checker applies the shop's own stocking rules and quotes the reason for every no.</p></div>
    <div class="promise reveal">${icons.van}<h3>Shipped Monday to Wednesday</h3>
      <p>Livestock never leaves on a Thursday or Friday, so no bag of fish spends a weekend in a depot.</p></div>
  </section>`;

  const featured = shelf(chrome.products);
  const inquiryArt = findNode(chrome.tree, 'hardscape')?.imageKey ?? findNode(chrome.tree, 'plants')?.imageKey ?? null;

  // Order, top to bottom: what the shop is (hero, promises), where to go
  // (sections, collections), the two things only this shop does (checker,
  // custom build), then a shelf of stock. The enquiry form stays above the
  // shelf for the reason it always has: a customer who wants a whole tank
  // built should not have to scroll past fish to find where to ask.
  return layout('Freshwater fish, plants and aquascapes', chrome, `
    ${promises}
    <section class="block">
      <div class="block-head"><p class="eyebrow">Shop by category</p><h2>Start with the water you have</h2></div>
      <div class="tiles">${chrome.tree.map(tile).join('')}</div>
    </section>
    ${collections(chrome.tree)}
    ${checkerTeaser(chrome)}
    ${inquiryForm(inquiry, inquiryArt)}
    ${featured.length ? `<section class="block">
      <div class="block-head"><p class="eyebrow">From the tanks today</p><h2>A few of the fish in the shop now</h2></div>
      <div class="grid">${featured.map(p => card(p, false)).join('')}</div>
    </section>` : ''}`, { hero });
}

/** A titled block of blank-line-separated paragraphs, each escaped on its own. */
function prose(title: string, text: string): string {
  return `
    <section class="about reveal">
      <h2>${esc(title)}</h2>
      ${text.split(/\n\s*\n/).map(para => `<p>${esc(para.trim())}</p>`).join('\n      ')}
    </section>`;
}

/**
 * A water parameter as a band on a fixed scale, rather than two numbers.
 *
 * "pH 7.8-8.6" means nothing to most customers; a band sitting at the far
 * alkaline end of a 5-9 track, beside a neon tetra's band at the acid end,
 * explains the tank checker's refusal before they have read a word of it.
 * The scales are fixed per parameter so two pages can be compared by eye.
 */
const SCALES = {
  temperature: { lo: 16, hi: 32, unit: ' °C', label: 'Temperature' },
  ph: { lo: 5, hi: 9, unit: '', label: 'pH' },
  dgh: { lo: 0, hi: 30, unit: ' dGH', label: 'Hardness' },
} as const;

function gauge(kind: keyof typeof SCALES, r: Range | Band | null): string {
  const s = SCALES[kind];
  if (!r) {
    return `<div class="gauge gauge-${kind} gauge-none"><div class="gauge-head"><span>${s.label}</span>
      <b>No band suits everything</b></div><div class="gauge-track"></div></div>`;
  }
  const pct = (v: number) => Math.max(0, Math.min(100, (v - s.lo) / (s.hi - s.lo) * 100));
  const from = pct(r.min);
  const width = Math.max(pct(r.max) - from, 1.5);
  const text = `${r.min}–${r.max}${s.unit}`;
  return `<div class="gauge gauge-${kind}">
    <div class="gauge-head"><span>${s.label}</span><b>${esc(text)}</b></div>
    <div class="gauge-track" role="img" aria-label="${esc(`${s.label} ${text}, on a scale of ${s.lo} to ${s.hi}${s.unit}`)}">
      <span class="gauge-band" style="left:${from.toFixed(1)}%;width:${width.toFixed(1)}%"></span></div>
    <div class="gauge-scale"><span>${s.lo}${s.unit}</span><span>${s.hi}${s.unit}</span></div>
  </div>`;
}

export function productPage(chrome: Chrome, d: ProductDetail) {
  const p = d.product;
  const s = d.species;
  const pl = d.plant;
  const section = findNode(chrome.tree, p.categorySlug);

  // At-a-glance facts: the five things a customer should know before the
  // price is worth reading. Everything else is further down the page.
  const facts = s
    ? [
        ['Adult size', `${s.maxSizeCm} cm`],
        ['Minimum tank', `${s.minTankLitres} L`],
        ['Keep at least', `${s.minGroupSize}`],
        ['Temperament', words(s.temperament).replace(' ', '-')],
        ['Care level', words(s.careLevel)],
      ]
    : pl
      ? [
          ['Light', words(pl.lightLevel)], ['CO₂', words(pl.co2)], ['Growth', words(pl.growthRate)],
          ['Placement', words(pl.placement)], ['Difficulty', words(pl.difficulty)],
        ]
      : [];
  const factList = facts.length
    ? `<dl class="facts">${facts.map(([k, v]) => `<div><dt>${esc(k)}</dt><dd>${esc(v)}</dd></div>`).join('')}</dl>`
    : '';

  // Two ways to act on a fish, both real: ask the shop (the enquiry form,
  // prefilled with this fish, so the customer is one field from sending it),
  // or check it against the tank they have. WhatsApp only when the number is
  // real -- see `whatsappHref`.
  const groupOf = s ? Math.max(1, s.minGroupSize) : 1;
  const wa = whatsappHref(`${WHATSAPP_GREETING}${p.name} (${p.sku}).`);
  const actions = `<div class="actions">
      <a class="btn" href="/?enquire=${esc(encodeURIComponent(`${p.slug}:${groupOf}`))}#custom-tank">Ask the shop for this ${s ? 'fish' : 'item'}</a>
      ${s ? `<a class="btn btn-quiet" href="/compatibility?f=${esc(encodeURIComponent(p.name))}&amp;n=${groupOf}">Check it with my tank</a>` : ''}
      ${wa ? `<a class="btn btn-quiet" href="${esc(wa)}" target="_blank" rel="noopener">${icons.chat} WhatsApp</a>` : ''}
    </div>
    ${p.livestock ? `<p class="ship-note">${icons.van}<span>Livestock leaves Monday to Wednesday before 14:00, so it never waits out a weekend in a depot.</span></p>` : ''}`;

  const water = s ? `
    <section class="water reveal">
      <h2>The water it needs</h2>
      <div class="gauges">${gauge('temperature', s.temperatureC)}${gauge('ph', s.ph)}${gauge('dgh', s.dgh)}</div>
    </section>` : pl ? `
    <section class="water reveal">
      <h2>The water it grows in</h2>
      <div class="gauges">${gauge('temperature', pl.temperatureC)}${gauge('ph', pl.ph)}</div>
    </section>` : '';

  const care = s ? `
    <section class="care reveal">
      <h2>Care profile</h2>
      <dl>
        <div><dt>Adult size</dt><dd>${esc(s.maxSizeCm)} cm</dd></div>
        <div><dt>Minimum tank</dt><dd>${esc(s.minTankLitres)} L</dd></div>
        <div><dt>Minimum group</dt><dd>${esc(s.minGroupSize)}</dd></div>
        <div><dt>Temperature</dt><dd>${esc(range(s.temperatureC, ' °C'))}</dd></div>
        <div><dt>pH</dt><dd>${esc(range(s.ph, ''))}</dd></div>
        <div><dt>Hardness</dt><dd>${esc(range(s.dgh, ' dGH'))}</dd></div>
        <div><dt>Temperament</dt><dd>${esc(s.temperament.toLowerCase().replace('_', '-'))}</dd></div>
        <div><dt>Care level</dt><dd>${esc(s.careLevel.toLowerCase())}</dd></div>
        <div><dt>Diet</dt><dd>${esc(s.diet.toLowerCase())}</dd></div>
        <div><dt>Plant safe</dt><dd>${s.plantSafe ? 'yes' : 'no'}</dd></div>
      </dl>
      ${s.careNotes ? `<p class="notes">${esc(s.careNotes)}</p>` : ''}
    </section>` : '';

  // Paragraphs are blank-line separated in the column; each is escaped on its
  // own, so no markup from the database ever reaches the page.
  // A shrimp is not a fish (ADR 0019), and the heading over its description
  // should not call it one.
  const kind = s?.animalGroup === 'SHRIMP' ? 'shrimp' : s?.animalGroup === 'SNAIL' ? 'snail' : 'fish';
  const about = s?.description ? prose(`About this ${kind}`, s.description) : '';
  const plant = pl ? `
    ${prose('About this plant', pl.description)}
    <section class="care reveal">
      <h2>Plant care</h2>
      <dl>
        <div><dt>Where it grows</dt><dd>${esc(pl.origin)}</dd></div>
        <div><dt>Placement</dt><dd>${esc(words(pl.placement))}</dd></div>
        <div><dt>Light</dt><dd>${esc(words(pl.lightLevel))} &middot; ${esc(pl.parMin)}&ndash;${esc(pl.parMax)} PAR at the substrate</dd></div>
        <div><dt>CO2</dt><dd>${esc(words(pl.co2))}</dd></div>
        <div><dt>Growth</dt><dd>${esc(words(pl.growthRate))}</dd></div>
        <div><dt>Difficulty</dt><dd>${esc(words(pl.difficulty))}</dd></div>
        <div><dt>Height</dt><dd>${esc(range(pl.heightCm, ' cm'))}</dd></div>
        <div><dt>Temperature</dt><dd>${esc(range(pl.temperatureC, ' °C'))}</dd></div>
        <div><dt>pH</dt><dd>${esc(range(pl.ph, ''))}</dd></div>
        <div><dt>Propagation</dt><dd>${esc(pl.propagation)}</dd></div>
      </dl>
    </section>
    ${prose('How to keep it', pl.careGuide)}
    ${prose('Fish and shrimp that suit it', pl.tankmates)}` : '';

  // A few other things from the same section, so a product page is never a
  // dead end. Taken from the cached list, so it costs no upstream call.
  const related = chrome.products
    .filter(o => o.categorySlug === p.categorySlug && o.slug !== p.slug)
    .slice(0, 4);

  const sci = s?.scientificName ?? (pl ? `${pl.scientificName} · ${pl.family}` : null);

  return layout(p.name, chrome, `
    <article class="detail">
      <div class="detail-shot">${photo(p.imageKey, p.name, '4/3', { eager: true, morph: morphName(p.slug), sizes: '(max-width: 1000px) 92vw, 640px' })}</div>
      <div class="detail-info">
        ${section ? `<a class="eyebrow" href="/c/${esc(section.slug)}">${esc(section.name)}</a>` : ''}
        <h1>${esc(p.name)}</h1>
        ${sci ? `<p class="sci">${esc(sci)}</p>` : ''}
        <p class="lede">${esc(p.summary)}</p>
        <div class="buy-row"><span class="price big">${esc(money(p))}</span>
          ${p.livestock ? '<span class="tag live">Live</span>' : ''}</div>
        ${factList}
        ${actions}
        <p class="sku">SKU ${esc(p.sku)}</p>
      </div>
    </article>
    <div class="detail-more">
      ${about}
      ${water}
      ${care}
      ${plant}
    </div>
    ${related.length ? `<section class="block">
      <div class="block-head"><p class="eyebrow">From the same section</p><h2>${esc(section?.name ?? 'More like this')}</h2></div>
      <div class="grid">${related.map(o => card(o)).join('')}</div></section>` : ''}`,
    { here: p.categorySlug, description: p.summary ?? undefined });
}

export function errorPage(chrome: Chrome, status: number, message: string) {
  return layout('Error', chrome, `<section class="thanks"><p class="eyebrow">Error ${status}</p>
    <h1>${status === 404 ? 'Nothing swimming here.' : 'The water is murky right now.'}</h1>
    <p class="lede">${esc(message)}</p><p><a class="btn" href="/">Back to the shop</a></p></section>`);
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
    <p class="eyebrow page-eyebrow">Search</p>
    <h1>&ldquo;${esc(query)}&rdquo;</h1>
    ${body}`, { query, scope: scope?.slug });
}

/* ---- tank checker ------------------------------------------------------ */

/** What the checker form holds, as typed -- strings, so a bad value can be
 *  shown back exactly as the customer entered it. */
export interface TankForm {
  litres: string;
  rows: { fish: string; qty: string }[];
}

export interface TankOutcome {
  assessment?: Assessment;
  /** Names typed that are not an animal the shop sells. */
  unknown?: string[];
  error?: string;
}

/** Rows the form offers. The advisor accepts up to 40; a customer planning
 *  more than eight species is a conversation, which is what the enquiry is for. */
export const CHECKER_ROWS = 8;

const VERDICT_COPY: Record<Verdict, [string, string]> = {
  ok: ['These can live together.',
    'Nothing in the shop’s rules stands against this tank. Keep the water inside the band below and it has what it needs.'],
  caution: ['This can work — with care.',
    'No rule refuses it, but at least one leaves no margin. Read what we flagged before you buy.'],
  refused: ['This tank will not work as described.',
    'At least one rule refuses it outright. Each reason names the fish and the number — change that, and check again.'],
};

const RULE_GROUPS: Record<string, string> = {
  water: 'Water', stocking: 'Tank size', behaviour: 'Behaviour', welfare: 'Welfare', plants: 'Plants',
};
const ruleLabel = (rule: string) => {
  const [group, name = ''] = rule.split('.');
  const tail = name.replace(/_/g, ' ').replace(/^ph$/i, 'pH');
  return `${RULE_GROUPS[group!] ?? group}${tail ? ` · ${tail}` : ''}`;
};

function finding(f: Finding, bySku: Map<string, ProductSummary>): string {
  const who = f.species.map(sku => bySku.get(sku))
    .filter((p): p is ProductSummary => !!p)
    .map(p => `<a href="/p/${esc(p.slug)}">${esc(p.name)}</a>`).join(', ');
  return `<li class="finding finding-${f.verdict}">
    <span class="finding-rule">${esc(ruleLabel(f.rule))}${who ? ` <span class="finding-who">${who}</span>` : ''}</span>
    <p>${esc(f.detail)}</p></li>`;
}

export function compatibilityPage(chrome: Chrome, form: TankForm, outcome: TankOutcome = {}) {
  const bySku = new Map(chrome.products.map(p => [p.sku, p]));
  const byName = new Map(chrome.products.map(p => [p.name.toLowerCase(), p]));
  const a = outcome.assessment;

  const rows = [...form.rows];
  while (rows.length < Math.max(4, Math.min(CHECKER_ROWS, form.rows.filter(r => r.fish).length + 2))) {
    rows.push({ fish: '', qty: '' });
  }

  let result = '';
  if (outcome.error) {
    result = `<p class="form-error" role="alert">${esc(outcome.error)}</p>`;
  } else if (a) {
    const [head, sub] = VERDICT_COPY[a.verdict];
    const litres = Number(form.litres);
    // The enquiry the customer can send from here: this exact tank, already
    // written out, so the next step after "yes" is one form away.
    const planned = form.rows
      .map(r => ({ p: byName.get(r.fish.trim().toLowerCase()), n: Math.max(1, Number(r.qty) || 1) }))
      .filter(x => x.p)
      .map(x => `${x.p!.slug}:${x.n}`).join(',');
    const findings = a.findings.length
      ? `<ol class="findings">${a.findings.map(f => finding(f, bySku)).join('')}</ol>`
      : '';
    result = `<section class="verdict verdict-${a.verdict}" aria-live="polite">
      <p class="eyebrow">The verdict</p>
      <h2>${esc(head)}</h2>
      <p>${esc(sub)}</p>
      <div class="verdict-grid">
        <div class="verdict-card">
          <h3>Hold the tank at</h3>
          <div class="gauges">${gauge('temperature', a.water.temperatureC)}${gauge('ph', a.water.ph)}${gauge('dgh', a.water.dgh)}</div>
        </div>
        <div class="verdict-card verdict-size">
          <h3>Tank size</h3>
          <p class="big-number"><b>${esc(litres)}</b> L yours</p>
          <p class="big-number"><b>${esc(Math.ceil(a.recommendedLitres))}</b> L this stocking needs fully grown</p>
          <div class="fill" role="img" aria-label="${esc(`This stocking uses ${Math.round(a.recommendedLitres / litres * 100)}% of the tank`)}">
            <span style="width:${Math.min(100, a.recommendedLitres / litres * 100).toFixed(0)}%"></span></div>
        </div>
      </div>
      ${findings}
      <div class="actions">
        ${planned ? `<a class="btn" href="/?enquire=${esc(encodeURIComponent(planned))}&amp;litres=${esc(encodeURIComponent(form.litres))}#custom-tank">Ask the shop to put this tank together</a>` : ''}
      </div>
      <p class="fineprint">Checked against the shop's stocking rules, version ${esc(a.rulesVersion)}. Adult sizes, not the size in the bag.</p>
    </section>`;
  }

  const unknown = outcome.unknown?.length
    ? `<p class="form-error" role="alert">We do not sell anything called ${outcome.unknown.map(n => `&ldquo;${esc(n)}&rdquo;`).join(', ')}.
        Pick a name from the list as you type.</p>`
    : '';

  return layout('Will they live together?', chrome, `
    <section class="checker">
      <p class="eyebrow page-eyebrow">Tank checker</p>
      <h1>Will they live <em>together?</em></h1>
      <p class="lede">Tell us the tank and the fish. We check water chemistry, adult size against the tank,
        temperament, predation, group size and plants, using the same rules the shop floor does &mdash;
        and we tell you why when the answer is no.</p>
      ${unknown}
      <form class="checker-form" action="/compatibility" method="get">
        <label class="litres"><span>Tank size</span><span class="unit"><input name="litres" type="number" min="1" max="10000"
          inputmode="numeric" required value="${esc(form.litres)}" placeholder="120">litres</span></label>
        <div class="checker-rows">
          <div class="checker-row checker-row-head" aria-hidden="true"><span>Fish or invertebrate</span><span>How many</span></div>
          ${rows.map((r, i) => `<div class="checker-row">
            <input name="f" list="livestock" autocomplete="off" aria-label="Fish ${i + 1}" value="${esc(r.fish)}"
              placeholder="${i === 0 ? 'Start typing a name' : ''}">
            <input name="n" type="number" min="1" max="500" inputmode="numeric" aria-label="How many of fish ${i + 1}"
              value="${esc(r.qty)}" placeholder="1">
          </div>`).join('')}
        </div>
        <button class="btn" type="submit">Check this tank</button>
        ${livestockList(chrome)}
      </form>
    </section>
    ${result}`, { description: 'Check whether fish will live together before you buy: water, tank size, temperament, predation and group size, with the reason for every no.' });
}

/**
 * The enquiry message a product page or the checker hands to the form.
 *
 * Built here from known products only -- `enquire` is a list of slugs, never
 * free text -- so nothing a URL carries is echoed onto the page unchecked.
 */
export function enquiryPrefill(products: ProductSummary[], enquire: string, litres?: string): string | undefined {
  const bySlug = new Map(products.map(p => [p.slug, p]));
  const lines = enquire.split(',').slice(0, CHECKER_ROWS).map(part => {
    const [slug = '', n] = part.split(':');
    const p = bySlug.get(slug);
    const qty = Math.min(500, Math.max(1, Math.floor(Number(n)) || 1));
    return p ? `${qty} × ${p.name}` : null;
  }).filter(Boolean);
  if (!lines.length) return undefined;
  const size = litres && /^\d{1,5}$/.test(litres) ? `a ${litres} litre tank` : 'my tank';
  return `I would like to set up ${size} with:\n${lines.map(l => `- ${l}`).join('\n')}\n\nCould you check stock and price it for me?`;
}
