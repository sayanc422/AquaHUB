import Fastify from 'fastify';
import fastifyStatic from '@fastify/static';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { catalog, UpstreamError, type CategoryView } from './catalog-client.js';
import { homePage, categoryPage, productPage, errorPage } from './views.js';

const app = Fastify({ logger: { level: process.env.LOG_LEVEL ?? 'info' } });
const here = dirname(fileURLToPath(import.meta.url));

await app.register(fastifyStatic, { root: join(here, '..', 'public'), prefix: '/static/' });

/**
 * The nav is on every page, so it is cached briefly in memory. This is a
 * deliberate, bounded staleness: a category rename takes up to 60s to appear.
 * The alternative is one upstream call per page render for data that changes
 * a few times a year.
 */
let navCache: { at: number; value: CategoryView[] } | null = null;
async function nav(): Promise<CategoryView[]> {
  if (navCache && Date.now() - navCache.at < 60_000) return navCache.value;
  const value = await catalog.categories();
  navCache = { at: Date.now(), value };
  return value;
}

app.get('/', async (_req, reply) => {
  const [categories, fish] = await Promise.all([nav(), catalog.byCategory('livestock-fish')]);
  reply.type('text/html').send(homePage(categories, fish.slice(0, 6)));
});

app.get<{ Params: { slug: string } }>('/c/:slug', async (req, reply) => {
  const categories = await nav();
  const current = categories.find(c => c.slug === req.params.slug);
  if (!current) { reply.code(404).type('text/html').send(errorPage(categories, 404, 'No such category.')); return; }
  const products = await catalog.byCategory(current.slug);
  reply.type('text/html').send(categoryPage(categories, current, products));
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
