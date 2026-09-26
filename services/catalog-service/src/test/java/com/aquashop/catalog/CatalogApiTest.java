package com.aquashop.catalog;

import org.junit.jupiter.api.Test;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Runs against a real Postgres, not H2. The schema uses CHECK constraints and
 * a functional index that H2 would either ignore or reject, so an in-memory
 * substitute would test a schema that does not exist in any environment.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class CatalogApiTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void datasource(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;

    /*
     * Counts are asked of the database, not written into the test. Nine
     * assertions here once said "13" or "47" and went stale the day V17 added
     * a hundred products -- they failed for a whole catalogue expansion
     * without telling anyone anything about the API. What these tests are for
     * is the API agreeing with the data: a subtree total that matches the rows
     * beneath it, a page that lists what is filed on it. The data itself is
     * each migration's business.
     */
    private int subtreeCount(String slug) {
        return jdbc.queryForObject("""
            WITH RECURSIVE sub AS (
              SELECT id FROM category WHERE slug = ?
              UNION ALL
              SELECT c.id FROM category c JOIN sub ON c.parent_id = sub.id)
            SELECT count(*) FROM product p JOIN sub ON p.category_id = sub.id""", Integer.class, slug);
    }

    private int directCount(String slug) {
        return jdbc.queryForObject(
            "SELECT count(*) FROM product p JOIN category c ON c.id = p.category_id WHERE c.slug = ?",
            Integer.class, slug);
    }

    @Test
    void listsTheTopOfTheShopNotEveryCategory() throws Exception {
        // Roots only. Returning all forty-odd would make the caller filter,
        // which means the caller has to understand the tree to draw a menu.
        mvc.perform(get("/api/categories"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.length()").value(4))
           .andExpect(jsonPath("$[0].slug").value("live-fish"))
           .andExpect(jsonPath("$[0].childCount").value(2))
           // Live Fishes holds no products itself; the count is the subtree's.
           .andExpect(jsonPath("$[0].productCount").value(0))
           .andExpect(jsonPath("$[0].totalProducts").value(subtreeCount("live-fish")))
           // A shrimp is not a fish. V7 lifted them out of Live Fishes and
           // gave them a root section of their own, between fish and plants.
           .andExpect(jsonPath("$[1].slug").value("invertebrates"))
           .andExpect(jsonPath("$[2].slug").value("plants"))
           .andExpect(jsonPath("$[3].slug").value("supplies"));
    }

    @Test
    void aCategoryPageCarriesItsTrailAndItsSections() throws Exception {
        mvc.perform(get("/api/categories/cichlids-african"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.category.name").value("African Cichlids"))
           // Shop front first, immediate parent last -- the order it renders in.
           .andExpect(jsonPath("$.breadcrumb.length()").value(3))
           .andExpect(jsonPath("$.breadcrumb[0].slug").value("live-fish"))
           .andExpect(jsonPath("$.breadcrumb[2].slug").value("cichlids"))
           .andExpect(jsonPath("$.children.length()").value(4))
           .andExpect(jsonPath("$.children[0].slug").value("malawi"));
    }

    @Test
    void aSectionThatIsAnnouncedButNotStockedSaysSo() throws Exception {
        // Saltwater exists so a customer who wants marine fish learns we are
        // working on it, rather than concluding we do not sell fish at all.
        mvc.perform(get("/api/categories/live-fish"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.children[1].slug").value("saltwater"))
           .andExpect(jsonPath("$.children[1].status").value("COMING_SOON"))
           .andExpect(jsonPath("$.children[1].browsable").value(false));
    }

    @Test
    void aBranchHoldsNoProductsItselfButKnowsWhatIsBeneathIt() throws Exception {
        // The escape hatch from a six-level tree: ?deep=true.
        mvc.perform(get("/api/categories/cichlids/products"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.length()").value(0));

        mvc.perform(get("/api/categories/cichlids/products").param("deep", "true"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.length()").value(subtreeCount("cichlids")))
           .andExpect(jsonPath("$[0].categorySlug").value("malawi"));
    }

    @Test
    void theDeepestPathInTheShopEndsInFish() throws Exception {
        mvc.perform(get("/api/categories/malawi"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.children.length()").value(0))
           .andExpect(jsonPath("$.products.length()").value(directCount("malawi")));
        assertThat(directCount("malawi")).isPositive();
    }

    // ------------------------------------------------------------ V7 tree --

    @Test
    void americanCichlidsAreAParentOfCentralAndSouthNotTheirSibling() throws Exception {
        // The tree V3 built had American, North American and South American as
        // siblings, so one entry contained the other two. This is the fix.
        mvc.perform(get("/api/categories/cichlids"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.children.length()").value(3))
           .andExpect(jsonPath("$.children[0].slug").value("cichlids-african"))
           .andExpect(jsonPath("$.children[1].slug").value("cichlids-american"));

        mvc.perform(get("/api/categories/cichlids-american"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.children.length()").value(2))
           .andExpect(jsonPath("$.children[0].slug").value("cichlids-central-american"))
           .andExpect(jsonPath("$.children[1].slug").value("cichlids-south-american"));
    }

    @Test
    void theAfricanLakesEndInACatchAllRatherThanInWestAfricaOnly() throws Exception {
        mvc.perform(get("/api/categories/african-other"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.category.name").value("Other African Cichlids"))
           .andExpect(jsonPath("$.category.status").value("COMING_SOON"));
    }

    /**
     * The catfish split is a rule, not a taste: small is an adult under 15 cm
     * that is happy in 150 L or less. A customer with a 60 L tank browses one
     * page and trusts it, which only holds if every fish on it passes the rule.
     * Asserted against the care profiles rather than against a list of slugs,
     * so adding a catfish to the wrong page fails here instead of in somebody's
     * living room.
     */
    @Test
    void everyFishOnTheSmallCatfishPageFitsASmallTank() {
        var rows = jdbc.queryForList("""
            WITH RECURSIVE sub AS (
              SELECT id FROM category WHERE slug = 'catfish-small'
              UNION ALL
              SELECT c.id FROM category c JOIN sub ON c.parent_id = sub.id)
            SELECT p.name, s.max_size_cm, s.min_tank_litres
              FROM product p
              JOIN sub ON p.category_id = sub.id
              JOIN species_profile s ON s.id = p.species_profile_id
             WHERE s.max_size_cm >= 15 OR s.min_tank_litres > 150""");
        assertThat(rows).as("catfish filed as small that are not").isEmpty();

        var large = jdbc.queryForList("""
            WITH RECURSIVE sub AS (
              SELECT id FROM category WHERE slug = 'catfish-large'
              UNION ALL
              SELECT c.id FROM category c JOIN sub ON c.parent_id = sub.id)
            SELECT p.name, s.max_size_cm, s.min_tank_litres
              FROM product p
              JOIN sub ON p.category_id = sub.id
              JOIN species_profile s ON s.id = p.species_profile_id
             WHERE s.max_size_cm < 15 AND s.min_tank_litres <= 150""");
        assertThat(large).as("catfish filed as large that are not").isEmpty();
    }

    @Test
    void loachesAreNoLongerFiledUnderCatfish() throws Exception {
        // Cobitidae, not Siluriformes. They shared a page because they share a
        // shelf, which is not the same thing.
        mvc.perform(get("/api/categories/loaches"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.breadcrumb.length()").value(2))
           .andExpect(jsonPath("$.breadcrumb[1].slug").value("freshwater"))
           .andExpect(jsonPath("$.products.length()").value(directCount("loaches")));
        // And none of them has drifted back: nothing under Catfish is a loach.
        assertThat(jdbc.queryForObject("""
            WITH RECURSIVE sub AS (
              SELECT id FROM category WHERE slug = 'catfish'
              UNION ALL
              SELECT c.id FROM category c JOIN sub ON c.parent_id = sub.id)
            SELECT count(*) FROM product p JOIN sub ON p.category_id = sub.id
             WHERE p.name ILIKE '%loach%'""", Integer.class)).isZero();
    }

    @Test
    void badidaeHaveASectionBecauseTheyFitNowhereElse() throws Exception {
        mvc.perform(get("/api/categories/badidae"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.products.length()").value(3));

        mvc.perform(get("/api/products/scarlet-badis"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.species.scientificName").value("Dario dario"))
           .andExpect(jsonPath("$.species.maxSizeCm").value(2.0))
           // It will not eat flake, which is the single most useful fact about
           // it and the reason most of them die in their first month.
           .andExpect(jsonPath("$.species.diet").value("CARNIVORE"));
    }

    @Test
    void invertebratesAreARootSectionWithShrimpAndSnails() throws Exception {
        mvc.perform(get("/api/categories/invertebrates"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.breadcrumb.length()").value(0))
           .andExpect(jsonPath("$.children.length()").value(2))
           .andExpect(jsonPath("$.children[0].slug").value("inverts-shrimp"))
           .andExpect(jsonPath("$.children[1].slug").value("inverts-snails"));

        mvc.perform(get("/api/categories/inverts-shrimp"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.products.length()").value(6));
        mvc.perform(get("/api/categories/inverts-snails"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.products.length()").value(5));
    }

    /**
     * Red Cherry, Blue Dream, Blue Velvet and Yellow are one species in four
     * colours. Four species_profile rows would claim otherwise -- and would
     * contradict the advice the shop gives, which is to keep one colour per
     * tank precisely because they interbreed.
     */
    @Test
    void theNeocaridinaColoursShareOneCareProfile() {
        Integer profiles = jdbc.queryForObject(
            "SELECT count(*) FROM species_profile WHERE scientific_name = 'Neocaridina davidi'",
            Integer.class);
        assertThat(profiles).isEqualTo(1);

        Integer colours = jdbc.queryForObject("""
            SELECT count(*) FROM product p
              JOIN species_profile s ON s.id = p.species_profile_id
             WHERE s.scientific_name = 'Neocaridina davidi'""", Integer.class);
        assertThat(colours).isEqualTo(4);
    }

    /**
     * An ACTIVE leaf with no products is a tile on the shop front that opens an
     * empty page. Two of them sat there from V3 until V7 because nothing joined
     * the tree to the products; this is the assertion that would have said so.
     */
    @Test
    void noSectionIsOpenForBrowsingWithNothingInIt() {
        var dead = jdbc.queryForList("""
            SELECT c.slug FROM category c
             WHERE c.status = 'ACTIVE'
               AND NOT EXISTS (SELECT 1 FROM category k WHERE k.parent_id   = c.id)
               AND NOT EXISTS (SELECT 1 FROM product  p WHERE p.category_id = c.id)""");
        assertThat(dead).as("ACTIVE sections with no children and no products").isEmpty();
    }

    /**
     * image_key is a promise that a photograph exists, and the convention is
     * `species/<product slug>.jpg` so that nobody needs a lookup table. V5 made
     * that promise for six Malawi fish when only three files ever arrived, and
     * three product pages rendered a broken image rather than the placeholder
     * until V7 cleared them.
     *
     * This cannot check the files: they live in the storefront's `public/`
     * directory, in a different service, and a test that reached across that
     * boundary would be asserting on somebody else's deployment. What it can
     * check is the convention, and which products are knowingly without a
     * photograph: V18 left seven NULL on purpose, each with a reason in the
     * storefront's species/CREDITS.md. A new NULL, or one of these gaining a
     * key, is a decision someone should see in a diff, not a count that
     * silently moves.
     */
    @Test
    void anImageKeyFollowsTheSlugConventionAndNothingClaimsMore() {
        var rows = jdbc.queryForList(
            "SELECT slug, image_key FROM product WHERE image_key IS NOT NULL ORDER BY slug");
        assertThat(rows).allSatisfy(r ->
            assertThat(r.get("image_key")).isEqualTo("species/" + r.get("slug") + ".jpg"));

        var unphotographed = jdbc.queryForList(
            "SELECT slug FROM product WHERE image_key IS NULL", String.class);
        assertThat(unphotographed).containsExactlyInAnyOrder(
            "bumblebee-cichlid", "endlers-livebearer", "head-and-tail-light-tetra",
            "scissortail-rasbora", "skunk-cory", "snowball-pleco", "tire-track-eel");
    }

    /**
     * A shrimp is not a small fish, and the catalogue is where that fact lives.
     *
     * aquatics-advisor sizes a stocking by summing adult length, which is a
     * fair proxy for a fish and badly wrong for an invertebrate. Running the V7
     * catalogue through the advisor had it refuse four scarlet badis and ten
     * cherry shrimp in a 40 L nano -- the shrimp were 79% of the bioload it
     * refused on. The advisor owns what to do about it; the catalogue owns
     * which animal it is.
     */
    @Test
    void aSpeciesSaysWhatKindOfAnimalItIs() throws Exception {
        mvc.perform(get("/api/products/cherry-shrimp"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.species.animalGroup").value("SHRIMP"));
        mvc.perform(get("/api/products/nerite-snail"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.species.animalGroup").value("SNAIL"));
        mvc.perform(get("/api/products/oscar"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.species.animalGroup").value("FISH"));
    }

    @Test
    void everySpeciesHasAnAnimalGroupRatherThanADefault() {
        // V8 adds the column with a DEFAULT so it does not have to enumerate
        // forty rows, then drops the default -- a species added without
        // deciding what it is should fail, not silently become a fish.
        var withoutDefault = jdbc.queryForList("""
            SELECT column_default FROM information_schema.columns
             WHERE table_name = 'species_profile' AND column_name = 'animal_group'
               AND column_default IS NOT NULL""");
        assertThat(withoutDefault).as("animal_group still has a DEFAULT").isEmpty();

        Integer groups = jdbc.queryForObject(
            "SELECT count(DISTINCT animal_group) FROM species_profile", Integer.class);
        assertThat(groups).isEqualTo(3);
    }

    @Test
    void unknownCategoryIsNotFound() throws Exception {
        mvc.perform(get("/api/categories/atlantis")).andExpect(status().isNotFound());
    }

    /**
     * The regression that took down the unfiltered product list: every query in
     * ProductRepository join-fetches the category except the inherited
     * findAll(), and with open-in-view false the DTO then asks a closed session
     * for the category name.
     */
    @Test
    void theUnfilteredProductListDoesNotTripOverALazyCategory() throws Exception {
        mvc.perform(get("/api/products"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$[0].categorySlug").isNotEmpty());
    }

    @Test
    void aPhotographedProductNamesItsImageAsAKeyNotAUrl() throws Exception {
        // A URL hard-codes where the bytes live; a key does not. Moving the
        // photographs behind a CDN should be a ConfigMap change, not a
        // migration over every row.
        mvc.perform(get("/api/products/demasoni"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.product.imageKey").value("species/demasoni.jpg"));
    }

    @Test
    void anUnphotographedProductHasNoKeyRatherThanAGuessedOne() throws Exception {
        // Null is handled by the storefront as a placeholder. A key invented
        // from the slug would point at a file nobody has taken.
        // The neon tetra was the example until it was photographed (V9); the
        // tire track eel is one of V18's seven deliberate gaps.
        mvc.perform(get("/api/products/tire-track-eel"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.product.imageKey").doesNotExist());
    }

    @Test
    void theAmericanCichlidSectionsAreNoLongerEmpty() throws Exception {
        // They were created ACTIVE with nothing in them, which is a section a
        // customer can walk into and find bare. Photographs arrived for four
        // American cichlids and they are stocked now.
        mvc.perform(get("/api/categories/cichlids-south-american"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.products.length()").value(directCount("cichlids-south-american")))
           // One level deeper than it used to be: V7 put American Cichlids
           // between this page and Cichlids.
           .andExpect(jsonPath("$.breadcrumb.length()").value(4))
           .andExpect(jsonPath("$.breadcrumb[3].slug").value("cichlids-american"));

        assertThat(directCount("cichlids-south-american")).isPositive();

        mvc.perform(get("/api/categories/cichlids/products").param("deep", "true"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.length()").value(subtreeCount("cichlids")));
    }

    @Test
    void anOscarIsBigEnoughToEatTheCommunityTank() throws Exception {
        // 35 cm against a neon tetra's 3.5: the advisor refuses that pairing on
        // the size ratio alone, which only works if the adult size is honest.
        mvc.perform(get("/api/products/oscar"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.species.maxSizeCm").value(35.0))
           .andExpect(jsonPath("$.species.minTankLitres").value(400))
           .andExpect(jsonPath("$.product.imageKey").value("species/oscar.jpg"));
    }

    @Test
    void mbunaCarryTheWaterParametersThatMakeThemIncompatibleWithTetras() throws Exception {
        // Not a contrivance: aquatics-advisor refuses a demasoni-and-neon tank
        // on exactly these numbers, with no rule written about either fish.
        mvc.perform(get("/api/products/demasoni"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.species.scientificName").value("Chindongo demasoni"))
           .andExpect(jsonPath("$.species.ph.min").value(7.8))
           .andExpect(jsonPath("$.species.minGroupSize").value(12));
    }

    @Test
    void livestockProductCarriesACareProfile() throws Exception {
        mvc.perform(get("/api/products/neon-tetra"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.product.livestock").value(true))
           .andExpect(jsonPath("$.species.scientificName").value("Paracheirodon innesi"))
           .andExpect(jsonPath("$.species.minGroupSize").value(8));
    }

    @Test
    void dryGoodsHaveNoCareProfile() throws Exception {
        mvc.perform(get("/api/products/heater-100w"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.species").doesNotExist());
    }

    @Test
    void unknownProductIsNotFound() throws Exception {
        mvc.perform(get("/api/products/does-not-exist"))
           .andExpect(status().isNotFound());
    }

    @Test
    void theTreeIsTheWholeCatalogueInOneCallWithCountsOnEveryNode() throws Exception {
        mvc.perform(get("/api/category-tree"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.length()").value(4))
           // Unwrapped: a node reads exactly like a tile, plus its children.
           .andExpect(jsonPath("$[0].slug").value("live-fish"))
           .andExpect(jsonPath("$[0].totalProducts").value(subtreeCount("live-fish")))
           .andExpect(jsonPath("$[0].children[0].slug").value("freshwater"))
           .andExpect(jsonPath("$[0].children[1].slug").value("saltwater"))
           .andExpect(jsonPath("$[0].children[1].browsable").value(false))
           .andExpect(jsonPath("$[0].children[0].children[0].slug").value("cichlids"))
           .andExpect(jsonPath("$[0].children[0].children[0].children[0].children[0].slug").value("malawi"));
    }

    @Test
    void searchMatchesACategoryAboveTheProductNotJustItsName() throws Exception {
        // No Lake Malawi fish is *named* a cichlid. "cichlid" still finds them,
        // because the customer typing it means the section, not the word.
        mvc.perform(get("/api/products").param("q", "cichlid"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$[?(@.slug == 'demasoni')]").exists())
           .andExpect(jsonPath("$[?(@.slug == 'neon-tetra')]").doesNotExist());
    }

    @Test
    void searchMatchesTheScientificName() throws Exception {
        mvc.perform(get("/api/products").param("q", "Corydoras sterbai"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.length()").value(1))
           .andExpect(jsonPath("$[0].categorySlug").value("catfish-corydoras"));
    }

    @Test
    void searchIgnoresTheSpaceACustomerPutsInAOneWordName() throws Exception {
        mvc.perform(get("/api/products").param("q", "spider wood"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$[0].slug").value("spiderwood-medium"));
        // And the other way round: V16's summary says driftwood in one word.
        mvc.perform(get("/api/products").param("q", "drift wood").param("in", "supplies"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.length()").value(1))
           .andExpect(jsonPath("$[0].slug").value("spiderwood-medium"));
    }

    @Test
    void searchCanBeNarrowedToOneSectionOfTheShop() throws Exception {
        // The "Aquarium Supplies" choice beside the search box: whatever else
        // "wood" might match, beneath supplies it can only be hardscape, and a
        // fish name searched there finds nothing rather than leaking out.
        mvc.perform(get("/api/products").param("q", "wood").param("in", "supplies"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$[*].categorySlug", org.hamcrest.Matchers.everyItem(
                   org.hamcrest.Matchers.is("hardscape"))));
        mvc.perform(get("/api/products").param("q", "tetra").param("in", "supplies"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void searchRanksANameMatchAboveASectionMatch() throws Exception {
        // "tetra" is in the Tetras & Characins section name, which every fish
        // filed there matches; the ones actually called tetras come first.
        // Asserted as an ordering, not as "cardinal first": V17 added a dozen
        // tetras and alphabetical order among name hits is not the point.
        String body = mvc.perform(get("/api/products").param("q", "tetra"))
           .andExpect(status().isOk())
           .andReturn().getResponse().getContentAsString();
        List<String> names = com.jayway.jsonpath.JsonPath.read(body, "$[*].name");
        int lastNameHit = -1, firstSectionHit = -1;
        for (int i = 0; i < names.size(); i++) {
            boolean named = names.get(i).toLowerCase().contains("tetra");
            if (named) lastNameHit = i;
            else if (firstSectionHit < 0) firstSectionHit = i;
        }
        assertThat(lastNameHit).as("some product is called a tetra").isGreaterThanOrEqualTo(0);
        assertThat(firstSectionHit).as("the section also holds non-tetras, e.g. the silver dollar")
            .isGreaterThanOrEqualTo(0);
        assertThat(lastNameHit).as("every name match ranks above every section-only match")
            .isLessThan(firstSectionHit);
    }

    @Test
    void searchingInAnUnknownSectionIsNotFound() throws Exception {
        mvc.perform(get("/api/products").param("q", "x").param("in", "no-such-section"))
           .andExpect(status().isNotFound());
    }

    @Test
    void readinessProbeIsExposed() throws Exception {
        mvc.perform(get("/actuator/health/readiness")).andExpect(status().isOk());
    }
}
