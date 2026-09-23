package com.aquashop.order;

import com.aquashop.order.inquiry.InquiryKeyUnavailableException;
import com.aquashop.order.inquiry.TankInquiryRepository;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * What a missing encryption key is allowed to break, and what it is not.
 *
 * <p>This is the test that pins the decision. An earlier version of this
 * feature refused to start the Spring context without a key, which meant a
 * forgotten Kubernetes Secret took the <em>checkout saga</em> down — the part
 * of this platform that has been crash-tested and verified in k3d across many
 * sessions — for the sake of a bolt-on enquiry form. The blast radius of a
 * mistake should match the size of the feature that caused it.
 *
 * <p>So: with no key the application starts, carts and orders work, and
 * {@code POST /v1/inquiries} alone answers 503. The safety property is
 * untouched — there is still no fallback key and nothing is ever written in
 * plaintext — only the reach of the failure. See ADR 0021.
 *
 * <p>Gated on {@code ORDER_TEST_DSN} like the rest of the suite: the context
 * needs a real database to start whether or not there is an encryption key,
 * which is itself part of what this class asserts.
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "ORDER_TEST_DSN", matches = ".+")
class InquiryKeyMissingTest {

    @DynamicPropertySource
    static void datasource(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", () -> System.getenv("ORDER_TEST_DSN"));
        registry.add("spring.datasource.username",
                () -> System.getenv().getOrDefault("ORDER_TEST_USER", "postgres"));
        registry.add("spring.datasource.password",
                () -> System.getenv().getOrDefault("ORDER_TEST_PASSWORD", ""));
        registry.add("orders.dispatch-scan-interval-ms", () -> "3600000");
        registry.add("orders.payment-reconcile-interval-ms", () -> "3600000");
        registry.add("orders.recovery-scan-interval-ms", () -> "3600000");
        // The point of the whole class.
        registry.add("inquiries.encryption-key", () -> "");
    }

    @Autowired MockMvc mvc;
    @Autowired TankInquiryRepository inquiries;

    private static final String INQUIRY = """
            {"message": "A 200 litre Tanganyikan tank.",
             "email": "priya@example.com", "phone": "9876543210"}
            """;

    @Test
    void theApplicationStartsWithNoKeyAtAll() {
        // Reaching this line is the assertion: the context booted without a
        // key. Everything below is about what still works.
        assertThat(inquiries.keyAvailable()).isFalse();
        assertThat(inquiries.keyProblem()).contains("INQUIRY_ENCRYPTION_KEY");
    }

    @Test
    void theEnquiryEndpointAnswers503AndSaysWhereToLook() throws Exception {
        MvcResult result = mvc.perform(post("/v1/inquiries")
                        .contentType(MediaType.APPLICATION_JSON).content(INQUIRY))
                // 503, not 500: the request was fine, and it starts working the
                // moment the Secret exists. That is what 503 means.
                .andExpect(status().isServiceUnavailable())
                .andReturn();

        // The body, not Spring's default error shape. A 503 saying only
        // "Service Unavailable" sends whoever is debugging it to the logs of a
        // service that looks perfectly healthy.
        String body = result.getResponse().getContentAsString();
        assertThat(body).contains("rotate-or-create-the-inquiry-key.md")
                        .contains("INQUIRY_ENCRYPTION_KEY")
                        .contains("checkout, carts and orders are unaffected");
    }

    /**
     * The whole reason this class exists: a missing enquiry key must not touch
     * the commerce path. Written to fail the day someone moves the key check
     * back to startup.
     */
    @Test
    void theCommercePathIsCompletelyUnaffected() throws Exception {
        MvcResult created = mvc.perform(post("/v1/carts"))
                .andExpect(status().isCreated())
                .andReturn();
        String cartId = JsonPath.read(created.getResponse().getContentAsString(), "$.id");

        mvc.perform(put("/v1/carts/" + cartId + "/lines")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                 {"sku":"FSH-TEST-01","name":"Test fish","quantity":2,
                                  "unitPriceMinor":45000,"livestock":true}
                                 """))
                .andExpect(status().isOk());

        mvc.perform(get("/v1/carts/" + cartId)).andExpect(status().isOk());
    }

    /**
     * The repository refuses rather than writing something it cannot encrypt.
     *
     * <p>Belt and braces with the controller's own check: a future caller that
     * forgets to ask {@code keyAvailable()} must not be able to reach
     * {@code pgp_sym_encrypt} with a null passphrase and find out what Postgres
     * does with one.
     */
    @Test
    void theRepositoryItselfRefusesToWriteOrReadWithoutAKey() {
        assertThatThrownBy(() -> inquiries.save("a@b.com", "9876543210", "A tank"))
                .isInstanceOf(InquiryKeyUnavailableException.class);
        assertThatThrownBy(() -> inquiries.findById(UUID.randomUUID()))
                .isInstanceOf(InquiryKeyUnavailableException.class);
    }

    /**
     * Counting needs no key, so "are enquiries arriving?" is still answerable
     * on a cluster whose Secret was never created — which is exactly the
     * cluster where someone will ask.
     */
    @Test
    void countingStillWorksWithoutAKey() {
        assertThat(inquiries.count()).isGreaterThanOrEqualTo(0L);
    }
}
