import Fastify from 'fastify';
import fastifyStatic from '@fastify/static';
import fastifyFormbody from '@fastify/formbody';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { catalog, UpstreamError, type NavCategory } from './catalog-client.js';
import { orders } from './order-client.js';
import {
  homePage, categoryPage, productPage, errorPage, inquiryThanksPage,
  type InquiryFormState,
} from './views.js';

const app = Fastify({ logger: { level: process.env.LOG_LEVEL ?? 'info' } });
const here = dirname(fileURLToPath(import.meta.url));

await app.register(fastifyStatic, { root: join(here, '..', 'public'), prefix: '/static/' });

// This BFF was GET-only until the tank-enquiry form existed, so it had no body
// parser at all. `application/x-www-form-urlencoded` is what a plain HTML form
// posts, and a plain HTML form is what ADR 0005 says this site renders.
await app.register(fastifyFormbody);

/**
 * The nav is on every page, so it is cached briefly in memory. This is a
 * deliberate, bounded staleness: a category rename takes up to 60s to appear.
 * The alternative is one upstream call per page render for data that changes
 * a few times a year.
 *
 * Building the hover dropdown means each root needs its subcategories too --
 * up to two levels deep, so a pass-through branch like `freshwater` (the only
 * child of `live-fish`) contributes its own nine children to the menu instead
 * of making a customer click through an intermediate page to see them. Worth
 * doing here rather than in `views.ts`: the shape of the dropdown is a fact
 * about the catalogue tree, not about how a page renders.
 */
let navCache: { at: number; value: NavCategory[] } | null = null;
async function nav(): Promise<NavCategory[]> {
  if (navCache && Date.now() - navCache.at < 60_000) return navCache.value;
  const roots = await catalog.categories();
  const value = await Promise.all(roots.map(async (root): Promise<NavCategory> => {
    if (root.childCount === 0) return { ...root, menu: [] };
    try {
      const { children } = await catalog.page(root.slug);
      const menu = (await Promise.all(children.map(async child => {
        if (child.childCount === 0) return [child];
        const grandchildren = await catalog.page(child.slug);
        return grandchildren.children;
      }))).flat();
      return { ...root, menu };
    } catch {
      // The dropdown is a convenience on top of a link that already works --
      // a slow or failing catalog call here should fall back to "no
      // dropdown", not take out the whole nav bar.
      return { ...root, menu: [] };
    }
  }));
  navCache = { at: Date.now(), value };
  return value;
}

app.get('/', async (_req, reply) => {
  // The shop front shows its top sections and a handful of what is actually in
  // stock beneath them -- an empty grid of three doors tells a customer nothing.
  const [categories, fish] = await Promise.all([
    nav(),
    catalog.byCategory('freshwater', true),
  ]);
  reply.type('text/html').send(homePage(categories, fish.slice(0, 6)));
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
app.get<{ Params: { slug: string }; Querystring: { all?: string } }>(
  '/c/:slug',
  async (req, reply) => {
    const categories = await nav();
    let page;
    try {
      page = await catalog.page(req.params.slug);
    } catch (err) {
      if (err instanceof UpstreamError && err.status === 404) {
        reply.code(404).type('text/html').send(errorPage(categories, 404, 'No such category.'));
        return;
      }
      throw err;
    }

    const wantsAll = req.query.all === '1' && page.children.length > 0;
    const products = wantsAll
      ? await catalog.byCategory(page.category.slug, true)
      : page.products;

    reply.type('text/html')
         .send(categoryPage(categories, page, products, wantsAll));
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
      const [categories, fish] = await Promise.all([nav(), catalog.byCategory('freshwater', true)]);
      reply.code(400).type('text/html').send(homePage(categories, fish.slice(0, 6), checked));
      return;
    }

    let accepted;
    try {
      accepted = await orders.submitInquiry(checked.draft);
    } catch (err) {
      // The customer keeps their words. Anything else — an error page, a
      // redirect — and they have to type the whole thing again to retry, which
      // is how a transient upstream blip turns into a lost enquiry.
      app.log.error({ err }, 'tank inquiry not accepted by order-service');
      const [categories, fish] = await Promise.all([nav(), catalog.byCategory('freshwater', true)]);
      const upstream = err instanceof UpstreamError ? err.status : 0;
      // 503 is passed through rather than flattened into 502, because the two
      // mean different things to the person reading the page. 502 is "try
      // again"; order-service answers 503 when its enquiry encryption key is
      // missing (ADR 0021), and no amount of retrying fixes that until an
      // operator creates the Secret. Telling someone to try again when it
      // cannot work is the kind of soft lie this project does not tell.
      const status = upstream === 400 ? 400 : upstream === 503 ? 503 : 502;
      reply.code(status).type('text/html').send(homePage(categories, fish.slice(0, 6), {
        ...checked.draft,
        error: status === 400
          ? 'The shop could not accept that as written. Please check the email and phone number.'
          : status === 503
            ? 'This form is not taking enquiries at the moment — that is our fault, not yours. '
              + 'Your message is still here; please copy it and email the shop directly.'
            : 'We could not reach the shop just now. Your message is still here — try sending it again.',
      }));
      return;
    }

    // Post/redirect/get, so a refresh on the confirmation page does not submit
    // the enquiry a second time. The id is safe in a URL: nothing resolves it
    // back to the customer's details, because no endpoint reads this table.
    reply.code(303).header('location', `/inquiries/thanks?ref=${encodeURIComponent(accepted.id)}`).send();
  });

const UUID_SHAPE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

app.get<{ Querystring: { ref?: string } }>('/inquiries/thanks', async (req, reply) => {
  const categories = await nav();
  // Shown only if it is the shape this service issues. Echoing an arbitrary
  // query parameter onto a page is how a reflected-content bug starts, and the
  // escaping in views.ts should not be the only thing standing in the way.
  const ref = req.query.ref && UUID_SHAPE.test(req.query.ref) ? req.query.ref : null;
  reply.type('text/html').send(inquiryThanksPage(categories, ref));
});

app.get<{ Params: { slug: string } }>('/p/:slug', async (req, reply) => {
  const categories = await nav();
  const detail = await catalog.product(req.params.slug);
  reply.type('text/html').send(productPage(categories, detail));
});

app.setErrorHandler(async (err, _req, reply) => {
  const status = err instanceof UpstreamError && err.status === 404 ? 404 : 502;
  app.log.error({ err }, 'request failed');
  const categories = navCache?.value ?? [];
  reply.code(status).type('text/html')
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
