import Fastify from 'fastify';
import fastifyStatic from '@fastify/static';
import fastifyFormbody from '@fastify/formbody';
import fastifyCompress from '@fastify/compress';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { catalog, UpstreamError } from './catalog-client.js';
import { orders } from './order-client.js';
import { advisor } from './advisor-client.js';
import {
  homePage, categoryPage, productPage, errorPage, inquiryThanksPage, searchPage,
  compatibilityPage, enquiryPrefill, isSort, CHECKER_ROWS,
  type Chrome, type InquiryFormState, type TankForm, type TankOutcome,
} from './views.js';

const app = Fastify({ logger: { level: process.env.LOG_LEVEL ?? 'info' } });
const here = dirname(fileURLToPath(import.meta.url));

// Compression before anything that sends a body. The HTML was going out raw --
// 33 KB for the shop front, most of it the search box's product-name datalist,
// which is the most compressible thing on the page. JPEG and WebP are already
// compressed and are skipped by content type; 1 KB is the floor below which
// the gzip framing costs more than it saves.
//
// Every async handler below ends `return reply.….send(…)`, and must. An async
// handler that calls `send()` and returns nothing resolves while the
// compression stream is still writing, Fastify closes the response, and the
// browser gets `content-encoding: br` with a zero-byte body -- a blank white
// page with no error anywhere but a "premature close" in this log. It worked
// before this plugin only because an uncompressed send finishes synchronously.
await app.register(fastifyCompress, { global: true, threshold: 1024, encodings: ['br', 'gzip'] });

/**
 * Static files, with a cache policy per kind of file rather than the plugin's
 * `max-age=0`, which made every page view revalidate every photograph.
 *
 * - **CSS and fonts: a year, immutable.** The stylesheet's URL carries its
 *   content hash (views.ts) and a font file never changes under its name, so
 *   a changed file is always a changed URL.
 * - **Photographs: a day, then a week of stale-while-revalidate.** *Not*
 *   immutable: this shop replaces photographs under the same name
 *   (context_summary.md, 26 September 2026: six of them, "the files kept their
 *   names"). The cost is that a replaced photo can take a day to reach a
 *   returning customer. Content-hashed image names would fix that and would
 *   need a migration over every `image_key`, which is not worth it for a
 *   photograph.
 */
await app.register(fastifyStatic, {
  root: join(here, '..', 'public'),
  prefix: '/static/',
  cacheControl: false,
  setHeaders(res, path) {
    if (/\.(css|woff2)$/.test(path)) {
      res.setHeader('cache-control', 'public, max-age=31536000, immutable');
    } else if (/\.(jpe?g|webp|png)$/.test(path)) {
      res.setHeader('cache-control', 'public, max-age=86400, stale-while-revalidate=604800');
    } else {
      res.setHeader('cache-control', 'public, max-age=300');
    }
  },
});

// This BFF was GET-only until the tank-enquiry form existed, so it had no body
// parser at all. `application/x-www-form-urlencoded` is what a plain HTML form
// posts, and a plain HTML form is what ADR 0005 says this site renders.
await app.register(fastifyFormbody);

/**
 * The page frame -- sidebar tree, top bar, search suggestions -- is on every
 * page, so it is cached briefly in memory. This is a deliberate, bounded
 * staleness: a category rename or a new product takes up to 60s to appear.
 * The alternative is two upstream calls per page render for data that changes
 * a few times a year.
 *
 * The tree is required: without it there is no navigation, and the error
 * page is the honest answer. The suggestions are not. A failed product list
 * leaves a search box with no type-ahead, which still searches.
 */
let navCache: { at: number; value: Chrome } | null = null;
async function nav(): Promise<Chrome> {
  if (navCache && Date.now() - navCache.at < 60_000) return navCache.value;
  const [tree, products] = await Promise.all([
    catalog.tree(),
    catalog.all().catch(() => []),
  ]);
  const value = { tree, products, suggestions: [...new Set(products.map(p => p.name))] };
  navCache = { at: Date.now(), value };
  return value;
}

/**
 * The shop front.
 *
 * One upstream call at most, and usually none: the sections, the collections
 * and the shelf all come from the cached frame. It used to make a second,
 * uncached call for the shelf on every render.
 *
 * `?enquire=` is how a product page or the tank checker hands a fish (or a
 * whole planned tank) to the enquiry form: slugs and counts, resolved against
 * the catalogue, so only names the shop sells are ever written into the box.
 */
app.get<{ Querystring: { enquire?: string; litres?: string } }>('/', async (req, reply) => {
  const chrome = await nav();
  const message = req.query.enquire
    ? enquiryPrefill(chrome.products, String(req.query.enquire).slice(0, 600), req.query.litres)
    : undefined;
  return reply.type('text/html').send(homePage(chrome, message ? { message } : {}));
});

/**
 * A category page, at any depth.
 *
 * The catalogue is a tree six levels deep, so this one route serves the shop
 * front's sections and a tank of Lake Malawi cichlids alike: whatever the
 * catalog says is inside, is what gets rendered.
 *
 * `?all=1` asks for everything in the subtree rather than the sections. Six
 * levels is five correct guesses before a customer sees a fish, so every level
 * that has sections also offers a way past them.
 */
app.get<{ Params: { slug: string }; Querystring: { all?: string; sort?: string } }>(
  '/c/:slug',
  async (req, reply) => {
    const categories = await nav();
    let page;
    try {
      page = await catalog.page(req.params.slug);
    } catch (err) {
      if (err instanceof UpstreamError && err.status === 404) {
        return reply.code(404).type('text/html').send(errorPage(categories, 404, 'No such category.'));
      }
      throw err;
    }

    const wantsAll = req.query.all === '1' && page.children.length > 0;
    const products = wantsAll
      ? await catalog.byCategory(page.category.slug, true)
      : page.products;

    const sort = isSort(req.query.sort) ? req.query.sort : 'featured';
    return reply.type('text/html')
         .send(categoryPage(categories, page, products, wantsAll, sort));
  });

/**
 * The custom tank-setup enquiry.
 *
 * Deliberately shallow validation. This BFF has no business deciding what a
 * valid enquiry is — order-service validates the same three fields again, and
 * that check is the one that counts because it is the one next to the
 * database. What happens here is only the part that needs to happen *here*:
 * catching an empty or obviously-malformed submission before it costs an
 * upstream round trip, and re-rendering the page with the customer's own words
 * still in the box when it does.
 *
 * Bounds mirror order-service's DTO rather than being independently chosen. If
 * they drift, this side is the one that gets more permissive and the customer
 * sees a 400 they cannot act on, which is the failure worth avoiding.
 */
const MAX_MESSAGE = 4000;
const MAX_EMAIL = 190;
const MAX_PHONE = 24;

/** Enough of an email to be worth sending upstream; nothing more is knowable here. */
const EMAIL_SHAPE = /^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$/;

function checkInquiry(raw: Record<string, unknown>): InquiryFormState | { ok: true; draft: {
  message: string; email: string; phone: string } } {
  const message = String(raw.message ?? '').trim();
  const email = String(raw.email ?? '').trim();
  const phone = String(raw.phone ?? '').trim();
  const state: InquiryFormState = { message, email, phone };

  if (!message) return { ...state, error: 'Tell us what you would like in the tank first.' };
  if (message.length > MAX_MESSAGE) {
    return { ...state, error: `That is longer than we can take — please keep it under ${MAX_MESSAGE} characters.` };
  }
  if (!EMAIL_SHAPE.test(email) || email.length > MAX_EMAIL) {
    return { ...state, error: 'That email address does not look right, and it is how we will reply.' };
  }
  // Digits, not shape. A regex strict enough to be meaningful about phone
  // numbers rejects correct international ones, so this only refuses prose.
  if ((phone.match(/\d/g) ?? []).length < 7 || phone.length > MAX_PHONE) {
    return { ...state, error: 'We need a phone number we can actually call.' };
  }
  return { ok: true, draft: { message, email, phone } };
}

app.post<{ Body: Record<string, unknown> }>(
  '/inquiries',
  // A public, unauthenticated POST. There is no rate limiting in this pass
  // (stated as a known gap in ADR 0021), so the body limit is the only bound
  // on what one request can cost: 16 KiB is four times the longest message the
  // form will accept and a great deal less than Fastify's 1 MiB default.
  { bodyLimit: 16 * 1024 },
  async (req, reply) => {
    const checked = checkInquiry(req.body ?? {});

    // Re-render, rather than redirect, on a rejected submission: a redirect
    // would need the typed-in paragraph carried in a cookie or a query string,
    // and a customer's free text does not belong in either.
    if (!('ok' in checked)) {
      return reply.code(400).type('text/html').send(homePage(await nav(), checked));
    }

    let accepted;
    try {
      accepted = await orders.submitInquiry(checked.draft);
    } catch (err) {
      // The customer keeps their words. Anything else — an error page, a
      // redirect — and they have to type the whole thing again to retry, which
      // is how a transient upstream blip turns into a lost enquiry.
      app.log.error({ err }, 'tank inquiry not accepted by order-service');
      const categories = await nav();
      const upstream = err instanceof UpstreamError ? err.status : 0;
      // 503 is passed through rather than flattened into 502, because the two
      // mean different things to the person reading the page. 502 is "try
      // again"; order-service answers 503 when its enquiry encryption key is
      // missing (ADR 0021), and no amount of retrying fixes that until an
      // operator creates the Secret. Telling someone to try again when it
      // cannot work is the kind of soft lie this project does not tell.
      const status = upstream === 400 ? 400 : upstream === 503 ? 503 : 502;
      return reply.code(status).type('text/html').send(homePage(categories, {
        ...checked.draft,
        error: status === 400
          ? 'The shop could not accept that as written. Please check the email and phone number.'
          : status === 503
            ? 'This form is not taking enquiries at the moment — that is our fault, not yours. '
              + 'Your message is still here; please copy it and email the shop directly.'
            : 'We could not reach the shop just now. Your message is still here — try sending it again.',
      }));
    }

    // Post/redirect/get, so a refresh on the confirmation page does not submit
    // the enquiry a second time. The id is safe in a URL: nothing resolves it
    // back to the customer's details, because no endpoint reads this table.
    return reply.code(303).header('location', `/inquiries/thanks?ref=${encodeURIComponent(accepted.id)}`).send();
  });

const UUID_SHAPE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

app.get<{ Querystring: { ref?: string } }>('/inquiries/thanks', async (req, reply) => {
  const categories = await nav();
  // Shown only if it is the shape this service issues. Echoing an arbitrary
  // query parameter onto a page is how a reflected-content bug starts, and the
  // escaping in views.ts should not be the only thing standing in the way.
  const ref = req.query.ref && UUID_SHAPE.test(req.query.ref) ? req.query.ref : null;
  return reply.type('text/html').send(inquiryThanksPage(categories, ref));
});

/**
 * Search, across the whole shop or under one of its top-level sections.
 *
 * `in` is honoured only if it names a root section that is open for browsing:
 * the picker offers nothing else, so anything else is a hand-edited URL, and
 * searching everything is a better answer to that than an error page.
 *
 * An empty query is not a search. With a section picked it goes to that
 * section's full listing -- the nearest thing to "show me everything in
 * supplies" -- and without one, to the shop front.
 */
const MAX_QUERY = 100;

app.get<{ Querystring: { q?: string; in?: string } }>('/search', async (req, reply) => {
  const chrome = await nav();
  const query = String(req.query.q ?? '').trim().slice(0, MAX_QUERY);
  const scope = chrome.tree.find(r => r.browsable && r.slug === req.query.in);

  if (!query) {
    return reply.redirect(scope ? `/c/${encodeURIComponent(scope.slug)}?all=1` : '/', 303);
  }
  const results = await catalog.search(query, scope?.slug);
  return reply.type('text/html').send(searchPage(chrome, query, scope, results));
});

app.get<{ Params: { slug: string } }>('/p/:slug', async (req, reply) => {
  const categories = await nav();
  const detail = await catalog.product(req.params.slug);
  return reply.type('text/html').send(productPage(categories, detail));
});

/**
 * The tank checker: "will these fish live together?"
 *
 * A GET form, so a checked tank is a URL -- the customer can bookmark it, send
 * it to the person they share the tank with, or come back to it from the
 * product page's "Check it with my tank" link, which arrives pre-filled.
 *
 * Names, not SKUs, are what the customer types, and they are resolved here
 * against the cached product list. That keeps the form free of a <select>
 * with 160 options per row, and it means an unknown name is caught before the
 * advisor is asked anything: a typo is the customer's to fix, not a 404 to
 * explain.
 *
 * The advisor being down is not the storefront being down. The page still
 * renders, the form keeps what was typed, and the message says whose fault it
 * is. Readiness does not check the advisor, for the reason it does not check
 * order-service: one feature does not get to take the shop down with it.
 */
const toArray = (v: unknown): string[] =>
  (Array.isArray(v) ? v : v === undefined ? [] : [v]).map(x => String(x));

app.get<{ Querystring: { litres?: string; f?: string | string[]; n?: string | string[] } }>(
  '/compatibility', async (req, reply) => {
    const chrome = await nav();
    const names = toArray(req.query.f).slice(0, CHECKER_ROWS);
    const qtys = toArray(req.query.n);
    const form: TankForm = {
      litres: String(req.query.litres ?? '').slice(0, 6),
      rows: names.map((fish, i) => ({ fish: fish.slice(0, 80), qty: (qtys[i] ?? '').slice(0, 4) })),
    };

    const filled = form.rows.filter(r => r.fish.trim());
    const litres = Number(form.litres);
    // Nothing asked yet, or asked from a product page before the tank size is
    // known: show the form, pre-filled, and no verdict.
    if (!filled.length || !form.litres) {
      return reply.type('text/html').send(compatibilityPage(chrome, form));
    }

    const outcome: TankOutcome = {};
    let status = 200;
    const byName = new Map(chrome.products.filter(p => p.livestock).map(p => [p.name.toLowerCase(), p]));
    outcome.unknown = filled.map(r => r.fish.trim()).filter(n => !byName.has(n.toLowerCase()));

    if (!(litres > 0 && litres <= 10_000)) {
      outcome.error = 'Tank size has to be a number of litres between 1 and 10,000.';
      status = 400;
    } else if (outcome.unknown.length) {
      status = 400;
    } else {
      // Two rows of the same fish are one group of that fish, not two species
      // that happen to share a name: the advisor would otherwise run its
      // same-species rules against a pair it thinks are strangers.
      const counts = new Map<string, number>();
      for (const r of filled) {
        const sku = byName.get(r.fish.trim().toLowerCase())!.sku;
        const n = Math.min(500, Math.max(1, Math.floor(Number(r.qty)) || 1));
        counts.set(sku, (counts.get(sku) ?? 0) + n);
      }
      try {
        outcome.assessment = await advisor.check({
          volumeLitres: litres,
          inhabitants: [...counts].map(([sku, quantity]) => ({ sku, quantity })),
        });
      } catch (err) {
        app.log.error({ err }, 'tank check failed');
        status = 502;
        outcome.error = err instanceof UpstreamError && err.status === 404
          ? 'One of those animals has no care profile the checker can read yet, so it cannot be checked. Ask the shop instead.'
          : 'The tank checker is not answering just now. Your tank is still in the form; try again in a minute.';
      }
    }
    return reply.code(status).type('text/html').send(compatibilityPage(chrome, form, outcome));
  });

app.setErrorHandler(async (err, _req, reply) => {
  const status = err instanceof UpstreamError && err.status === 404 ? 404 : 502;
  app.log.error({ err }, 'request failed');
  const categories = navCache?.value ?? { tree: [], suggestions: [], products: [] };
  return reply.code(status).type('text/html')
       .send(errorPage(categories, status, status === 404 ? 'We could not find that.' : 'The catalog is not answering right now.'));
});

// Liveness: is the process wedged? Deliberately does NOT touch the catalog.
// If it did, a catalog outage would make Kubernetes restart every healthy
// storefront pod in a loop and turn a partial outage into a total one.
app.get('/healthz', async () => ({ status: 'ok' }));

// Readiness: should this pod receive traffic? This one does depend on the
// catalog, because a storefront that cannot reach it renders nothing useful.
//
// It deliberately does NOT check order-service, even though the enquiry form
// now needs it. A storefront that cannot reach order-service still serves the
// entire catalogue; failing readiness would take the shop down to protect one
// form, and the form already has an honest failure state that keeps the
// customer's text.
app.get('/readyz', async (_req, reply) => {
  try { await catalog.ping(); return { status: 'ok' }; }
  catch { reply.code(503); return { status: 'catalog unreachable' }; }
});

const port = Number(process.env.PORT ?? 3000);
await app.listen({ host: '0.0.0.0', port });

// Graceful shutdown: on SIGTERM stop accepting new connections and drain.
// Kubernetes removes the pod from Endpoints and sends SIGTERM concurrently,
// so in-flight requests must be allowed to finish inside terminationGracePeriod.
for (const sig of ['SIGTERM', 'SIGINT'] as const) {
  process.on(sig, () => { app.log.info(`${sig} received, draining`); app.close().then(() => process.exit(0)); });
}
