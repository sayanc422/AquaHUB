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
    void listsSeededCategories() throws Exception {
        mvc.perform(get("/api/categories"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$[0].slug").value("livestock-fish"));
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
