import { request } from 'undici';
import { UpstreamError } from './catalog-client.js';

/**
 * The BFF's one call into order-service.
 *
 * Same shape as `catalog-client.ts` on purpose — base URL from the
 * environment, `undici`, a bounded timeout — because a second pattern for
 * "call a backend service" is a second place to get timeouts wrong.
 *
 * `UpstreamError` is imported rather than redeclared. Two structurally
 * identical error classes would break `instanceof` in `server.ts` in a way
 * that only shows up on the error path, which is the path nobody exercises.
 */
const BASE = process.env.ORDER_BASE_URL ?? 'http://order-service:8082';
const TIMEOUT_MS = Number(process.env.ORDER_TIMEOUT_MS ?? 2000);

export interface InquiryDraft {
  /** What the customer wants their tank to look like, in their own words. */
  message: string;
  email: string;
  phone: string;
}

/**
 * What order-service answers with: an id and nothing else.
 *
 * Deliberately not `{ id, email, ... }`. order-service does not echo the
 * submission back, and this interface exists partly to make that visible here
 * — the BFF has nowhere to accidentally render a customer's phone number onto
 * a page because it never receives one back.
 */
export interface InquiryAccepted { id: string }

/**
 * Bounded at 2 s like every other upstream call from this BFF.
 *
 * A POST is the one place where a timeout is genuinely ambiguous — the request
 * may have been stored and the answer lost — and that ambiguity is accepted
 * rather than papered over with a retry. Retrying would risk two rows for one
 * enquiry, and a duplicate enquiry costs a wasted phone call; a lost one costs
 * a customer who was told it failed and can submit again. The second is the
 * cheaper mistake, so there is no retry here.
 */
export const orders = {
  async submitInquiry(draft: InquiryDraft): Promise<InquiryAccepted> {
    const res = await request(`${BASE}/v1/inquiries`, {
      method: 'POST',
      headersTimeout: TIMEOUT_MS,
      bodyTimeout: TIMEOUT_MS,
      headers: { 'content-type': 'application/json', accept: 'application/json' },
      body: JSON.stringify(draft),
    });
    if (res.statusCode >= 400) {
      res.body.dump();
      throw new UpstreamError(res.statusCode, `order /v1/inquiries -> ${res.statusCode}`);
    }
    return (await res.body.json()) as InquiryAccepted;
  },
};
