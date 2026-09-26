package com.aquashop.catalog.api;

import com.aquashop.catalog.domain.Category;
import com.aquashop.catalog.domain.Product;
import com.aquashop.catalog.domain.SpeciesProfile;

import java.text.Normalizer;
import java.util.*;

/**
 * The shop's one search box.
 *
 * <p>A product matches when every word the customer typed appears somewhere in
 * what they could mean by it: the product's name and summary, its species'
 * common and scientific names, and the name of every category above it. So
 * "cichlid" finds a Lake Malawi mbuna whose own name never says cichlid,
 * "pterophyllum" finds the angelfish, and "malawi yellow" narrows to one fish.
 *
 * <p>Words are compared with spaces and punctuation squeezed out, so
 * "spider wood" finds "Spiderwood" and "bristlenose" finds "Bristle-nose".
 * The cost is the occasional match across a word boundary, which on a
 * catalogue of short names has not produced a wrong hit worth fixing.
 *
 * <p>Deliberately not searched: care notes and category descriptions. They are
 * prose about <em>other</em> fish ("needs driftwood to rasp", "bullied by most
 * of the fish on the Malawi page"), and matching them turns every search into
 * half the catalogue.
 *
 * <p>Results rank name matches above species-name matches above everything
 * else, then alphabetically -- someone who types "neon" wants the Neon Tetra
 * first, not whatever sorts first among things filed near it.
 */
final class ProductSearch {

    private final Map<Long, Category> categoriesById = new HashMap<>();

    ProductSearch(List<Category> allCategories) {
        for (Category c : allCategories) categoriesById.put(c.getId(), c);
    }

    /**
     * @param scopeSlug when non-null, only products in that category's subtree:
     *                  the "Aquarium Supplies" choice beside the search box.
     */
    List<Product> run(List<Product> catalogue, String query, String scopeSlug) {
        List<String> words = words(query);
        record Hit(Product product, int rank) { }
        List<Hit> hits = new ArrayList<>();

        for (Product p : catalogue) {
            List<Category> trail = trail(p.getCategory());
            if (scopeSlug != null && trail.stream().noneMatch(c -> c.getSlug().equals(scopeSlug))) continue;
            if (words.isEmpty()) { hits.add(new Hit(p, 0)); continue; }

            String name = squash(p.getName());
            SpeciesProfile s = p.getSpeciesProfile();
            String species = s == null ? "" : squash(s.getCommonName() + " " + s.getScientificName());
            StringBuilder rest = new StringBuilder(squash(p.getSummary()));
            for (Category c : trail) rest.append(' ').append(squash(c.getName()));
            String everything = name + ' ' + species + ' ' + rest;

            if (!words.stream().allMatch(w -> containsWord(everything, w))) continue;
            int rank = words.stream().allMatch(w -> containsWord(name, w)) ? 0
                     : words.stream().allMatch(w -> containsWord(name + ' ' + species, w)) ? 1
                     : 2;
            hits.add(new Hit(p, rank));
        }

        hits.sort(Comparator.comparingInt(Hit::rank)
                .thenComparing(h -> h.product().getName(), String.CASE_INSENSITIVE_ORDER));
        return hits.stream().map(Hit::product).toList();
    }

    /** The category and every category above it, nearest first. */
    private List<Category> trail(Category leaf) {
        List<Category> out = new ArrayList<>();
        for (Category c = categoriesById.get(leaf.getId()); c != null;
             c = c.getParent() == null ? null : categoriesById.get(c.getParent().getId())) {
            out.add(c);
        }
        return out;
    }

    /**
     * A plural typed where the catalogue has the singular ("tetras" against
     * "Cardinal Tetra") should still match, so a trailing s is optional.
     * Not a stemmer: "loaches" and "catfish" are already how the catalogue
     * spells its own sections, and one rule covers the common case without a
     * dependency.
     */
    private static boolean containsWord(String haystack, String word) {
        if (haystack.contains(word)) return true;
        return word.length() > 3 && word.endsWith("s")
                && haystack.contains(word.substring(0, word.length() - 1));
    }

    private static List<String> words(String query) {
        if (query == null) return List.of();
        return Arrays.stream(fold(query).split("[^a-z0-9]+"))
                .filter(w -> !w.isEmpty())
                .toList();
    }

    /**
     * Lower-cased, accents dropped, everything but letters and digits removed
     * -- except that separate fields stay separated by the single spaces the
     * caller joins them with, so a word never matches across two fields.
     */
    private static String squash(String s) {
        return s == null ? "" : fold(s).replaceAll("[^a-z0-9]", "");
    }

    private static String fold(String s) {
        return Normalizer.normalize(s, Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "")
                .toLowerCase(Locale.ROOT);
    }
}
