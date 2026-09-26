import { request } from 'undici';

const BASE = process.env.CATALOG_BASE_URL ?? 'http://catalog-service:8080';
const TIMEOUT_MS = Number(process.env.CATALOG_TIMEOUT_MS ?? 2000);

export interface CategoryView {
  slug: string; name: string; teaser: string | null; description: string | null;
  status: string;
  /** Derived by the catalog, so the storefront never maintains its own list of
   *  statuses that mean "enterable". */
  browsable: boolean;
  /** A key such as `sections/malawi.jpg`, not a URL: the storefront composes
   *  the URL, so moving the images behind a CDN is configuration. */
  imageKey: string | null;
  childCount: number;
  productCount: number;
  /** Everything in the subtree. A "Cichlids" tile holds nothing itself and six
   *  fish below it, and showing 0 would be true and useless. */
  totalProducts: number;
}
export interface ProductSummary {
  sku: string; slug: string; name: string; summary: string | null;
  price: string; currency: string; livestock: boolean; categorySlug: string;
  imageKey: string | null;
}
export interface Range { min: number; max: number }
export interface SpeciesView {
  scientificName: string; commonName: string; maxSizeCm: number;
  minTankLitres: number; minGroupSize: number;
  temperatureC: Range; ph: Range; dgh: Range;
  temperament: string; careLevel: string; diet: string;
  plantSafe: boolean; careNotes: string | null; description: string | null;
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

/**
 * One node of the category tree: exactly a tile's fields, plus what hangs
 * beneath it. The catalog assembles the whole tree in one call
 * (`/api/category-tree`) so the sidebar costs one upstream request, not one per
 * category.
 */
export interface TreeNode extends CategoryView { children: TreeNode[] }

export const catalog = {
  categories: () => get<CategoryView[]>('/api/categories'),
  page: (slug: string) => get<CategoryPage>(`/api/categories/${encodeURIComponent(slug)}`),
  byCategory: (slug: string, deep = false) =>
    get<ProductSummary[]>(
      `/api/categories/${encodeURIComponent(slug)}/products${deep ? '?deep=true' : ''}`),
  tree: () => get<TreeNode[]>('/api/category-tree'),
  /** `scope` is a category slug to search beneath, or undefined for everything. */
  search: (q: string, scope?: string) =>
    get<ProductSummary[]>(`/api/products?q=${encodeURIComponent(q)}`
      + (scope ? `&in=${encodeURIComponent(scope)}` : '')),
  all: () => get<ProductSummary[]>('/api/products'),
  product: (slug: string) => get<ProductDetail>(`/api/products/${encodeURIComponent(slug)}`),
  ping: () => get<unknown>('/actuator/health/readiness'),
};
