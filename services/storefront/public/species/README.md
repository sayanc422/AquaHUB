# Product photography

Drop a JPEG in here named after the product slug and it appears on the site. No code change, no
deployment of anything but the image.

```
public/species/demasoni.jpg          ->  key "species/demasoni.jpg"  ->  /static/species/demasoni.jpg
public/sections/malawi.jpg           ->  key "sections/malawi.jpg"
```

The key is stored in `catalog-service` (`product.image_key`, `category.image_key`); the URL is
composed by the storefront from `IMAGE_BASE_URL`. That split is deliberate: the day these move
behind a CDN, it is a ConfigMap change and not a migration.

## Shape

| | |
|---|---|
| Product | 4:3, at least 1200 × 900. The fish in profile, filling most of the frame. |
| Section | 16:9, at least 1600 × 900. |
| Format | JPEG, quality ~80, under 300 KB. Nobody browsing on mobile data wants a 4 MB fish. |

A missing file renders as the same placeholder as a missing key — the storefront catches the load
error in the browser, because only the browser can know whether a CDN has the file. So a key that
points at nothing is not a broken page.

It is still a wasted request per card, so commit the photograph in the same change as the key
wherever you can.

## Licensing — read this before adding anything

Every photograph here must be one of:

1. **taken by the shop** — the best option, and the only one that also shows the actual fish for sale;
2. **licensed for commercial use**, with the licence recorded in `CREDITS.md` beside it; or
3. **supplied by the breeder or importer** with written permission.

A photograph found through an image search is none of those. Aquarium photographs are routinely
watermarked and routinely enforced, and a shop is a commercial use with no fair-dealing argument
available. The fish in the tank is the product; photograph that one.
