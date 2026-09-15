import { request } from 'undici';

const BASE = process.env.CATALOG_BASE_URL ?? 'http://catalog-service:8080';
const TIMEOUT_MS = Number(process.env.CATALOG_TIMEOUT_MS ?? 2000);

export interface CategoryView {
  slug: string; name: string; teaser: string | null; description: string | null;
  status: string;
  /** Derived by the catalog, so the storefront never maintains its own list of
   *  statuses that mean "enterable". */
  browsable: boolean;
  imageUrl: string | null;
  childCount: number;
  productCount: number;
  /** Everything in the subtree. A "Cichlids" tile holds nothing itself and six
   *  fish below it, and showing 0 would be true and useless. */
  totalProducts: number;
}
export interface ProductSummary {
  sku: string; slug: string; name: string; summary: string | null;
  price: string; currency: string; livestock: boolean; categorySlug: string;
  imageUrl: string | null;
}
export interface Range { min: number; max: number }
export interface SpeciesView {
  scientificName: string; commonName: string; maxSizeCm: number;
  minTankLitres: number; minGroupSize: number;
  temperatureC: Range; ph: Range; dgh: Range;
  temperament: string; careLevel: string; diet: string;
  plantSafe: boolean; careNotes: string | null;
}
export interface ProductDetail { product: ProductSummary; species: SpeciesView | null }

export class UpstreamError extends Error {
  constructor(readonly status: number, message: string) { super(message); }
}

/**
 * Every upstream call is bounded. A BFF without a timeout inherits the slowest
 * dependency's latency and turns one slow service into a site-wide outage,
 * because its own connection pool fills with requests that will never return.
 */
async function get<T>(path: string): Promise<T> {
  const res = await request(`${BASE}${path}`, {
    method: 'GET',
    headersTimeout: TIMEOUT_MS,
    bodyTimeout: TIMEOUT_MS,
    headers: { accept: 'application/json' },
  });
  if (res.statusCode >= 400) {
    res.body.dump();
    throw new UpstreamError(res.statusCode, `catalog ${path} -> ${res.statusCode}`);
  }
  return (await res.body.json()) as T;
}

/**
 * One category page in one call.
 *
 * The catalog assembles breadcrumb, subsections and products together because
 * the page renders them together -- three round trips to draw one page is how
 * a BFF ends up slower than the service behind it.
 */
export interface CategoryPage {
  category: CategoryView;
  breadcrumb: CategoryView[];
  children: CategoryView[];
  products: ProductSummary[];
}

export const catalog = {
  categories: () => get<CategoryView[]>('/api/categories'),
  page: (slug: string) => get<CategoryPage>(`/api/categories/${encodeURIComponent(slug)}`),
  byCategory: (slug: string, deep = false) =>
    get<ProductSummary[]>(
      `/api/categories/${encodeURIComponent(slug)}/products${deep ? '?deep=true' : ''}`),
  product: (slug: string) => get<ProductDetail>(`/api/products/${encodeURIComponent(slug)}`),
  ping: () => get<unknown>('/actuator/health/readiness'),
};
