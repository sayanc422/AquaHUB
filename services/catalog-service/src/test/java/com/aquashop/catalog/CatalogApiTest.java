package com.aquashop.catalog;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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

    @Test
    void listsTheTopOfTheShopNotEveryCategory() throws Exception {
        // Roots only. Returning all twenty-nine would make the caller filter,
        // which means the caller has to understand the tree to draw a menu.
        mvc.perform(get("/api/categories"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.length()").value(3))
           .andExpect(jsonPath("$[0].slug").value("live-fish"))
           .andExpect(jsonPath("$[0].childCount").value(2))
           // Live Fishes holds no products itself; the count is the subtree's.
           .andExpect(jsonPath("$[0].productCount").value(0))
           .andExpect(jsonPath("$[0].totalProducts").value(18));
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
           .andExpect(jsonPath("$.length()").value(6))
           .andExpect(jsonPath("$[0].categorySlug").value("malawi"));
    }

    @Test
    void theDeepestPathInTheShopEndsInFish() throws Exception {
        mvc.perform(get("/api/categories/malawi"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.children.length()").value(0))
           .andExpect(jsonPath("$.products.length()").value(6));
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
    void readinessProbeIsExposed() throws Exception {
        mvc.perform(get("/actuator/health/readiness")).andExpect(status().isOk());
    }
}
