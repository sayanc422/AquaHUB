import { request } from 'undici';
import { UpstreamError } from './catalog-client.js';

/**
 * The BFF's call into aquatics-advisor: "will these fish live together?"
 *
 * Same shape as `catalog-client.ts` and `order-client.ts` -- base URL from the
 * environment, `undici`, a bounded timeout -- for the reason `order-client.ts`
 * gives: a second pattern for calling a backend is a second place to get
 * timeouts wrong.
 *
 * The advisor makes one catalog call per species it has not cached, so its
 * first answer for a six-species tank is slower than the 2 s every other call
 * here gets. 4 s is still bounded; a customer waiting on a verdict will wait
 * that long, and a storefront thread held any longer is the failure mode the
 * catalog client's comment describes.
 */
const BASE = process.env.ADVISOR_BASE_URL ?? 'http://aquatics-advisor:8084';
const TIMEOUT_MS = Number(process.env.ADVISOR_TIMEOUT_MS ?? 4000);

export type Verdict = 'ok' | 'caution' | 'refused';

export interface Finding {
  verdict: Verdict;
  /** e.g. `water.pH` -- the key into the advisor's published rules file. */
  rule: string;
  /** A sentence that names the fish and quotes the rule's own justification. */
  detail: string;
  species: string[];
}

export interface Band { min: number; max: number }

export interface Assessment {
  verdict: Verdict;
  findings: Finding[];
  /** The band every inhabitant can live in, or null where there is none. */
  water: { temperatureC: Band | null; ph: Band | null; dgh: Band | null };
  recommendedLitres: number;
  rulesVersion: string;
}

export interface TankDraft {
  volumeLitres: number;
  inhabitants: { sku: string; quantity: number }[];
}

export const advisor = {
  async check(tank: TankDraft): Promise<Assessment> {
    const res = await request(`${BASE}/v1/tank/check`, {
      method: 'POST',
      headersTimeout: TIMEOUT_MS,
      bodyTimeout: TIMEOUT_MS,
      headers: { 'content-type': 'application/json', accept: 'application/json' },
      body: JSON.stringify(tank),
    });
    if (res.statusCode >= 400) {
      res.body.dump();
      throw new UpstreamError(res.statusCode, `advisor /v1/tank/check -> ${res.statusCode}`);
    }
    return (await res.body.json()) as Assessment;
  },
};
