# 22. Declarative browser features are not client-side JavaScript — clarifies 0005

**Status:** Accepted · **Phase:** storefront, 28 September 2026

## Context

The storefront was asked to feel premium: fast between pages, smooth when it changes, and
distinctive beside other fish shops. The usual way to get there is a client-side router, an image
component and a transition library, which is the SPA ADR 0005 rules out.

Browsers now do three of those things from declarations, with no code:

- **Cross-document view transitions** (`@view-transition { navigation: auto }` in CSS): the old
  page and the new one cross-fade, and an element named on both (a product's photograph) animates
  from its old box to its new one.
- **Speculation rules** (`<script type="speculationrules">` holding JSON): the browser prefetches a
  link while the pointer approaches it and prerenders a product page when the button goes down.
- **Scroll-driven animations** (`animation-timeline: view()`): sections rise into place as they
  enter the viewport.

The question is whether these break ADR 0005's "no client-side framework". The `<script>` tag in
particular reads like a violation at a glance.

## Decision

ADR 0005 is about **client state and a build toolchain**, not about the literal string `<script>`.
A feature is allowed when all three are true:

1. it is a declaration the browser interprets (CSS, or JSON the browser reads), with no code of
   ours executing;
2. it holds no state that the server does not also hold; and
3. a browser that does not support it gets exactly the site it got before, with no fallback code.

All three features above pass. Anything that needs a `.js` file, an event listener or a bundler
still does not, and still needs a decision of its own.

## Consequences

The site navigates like an app in Chromium-based browsers (Chrome, Edge, Samsung Internet) and
behaves exactly as before everywhere else. What share of this shop's customers that is has not been
measured; there are no customers to measure. Every page is still one server-rendered
HTML document that works with JavaScript off.

**Cost:**

- **The premium feel is uneven.** Firefox and Safari do not yet run speculation rules or
  cross-document view transitions, so a Safari customer gets plain page loads: correct, but not the
  experience the Chromium screenshots show. Nothing detects this, and nothing needs to, but a
  demo on an iPhone will look plainer than the one on a laptop.
- **Speculation costs the cluster real requests.** A prefetch is a full page render, with its
  catalog calls behind it, for a page the customer may never open. Mitigated by `moderate`
  prefetch (on hover, not on sight) and `conservative` prerender (on press, product pages only),
  and by the 60 s frame cache that already absorbs most catalog calls. Not measured under load,
  because nothing here has been.
- **A view-transition name must be unique on a page, and each named element is snapshotted on
  every navigation.** Names are carried in a `--vt` custom property and switched on only for the
  hovered card and the product hero, so a 149-card page names one element, not 149. If two
  elements ever share a name, the transition silently does not run. The failure is quiet and
  cosmetic, not broken.
- **The rule needs judgment to apply.** "Declarative, stateless, no fallback needed" is a line a
  future change could argue itself across, say with an `onclick` in an attribute. The existing
  `onerror` on product images, which swaps a missing photo for a placeholder, is the one inline
  handler on the site. It predates this ADR and stays because a broken-image icon on a live shop is
  worse, but it is code, and it is the precedent to *not* extend.
