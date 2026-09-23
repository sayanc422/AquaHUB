package com.aquashop.order;

import com.aquashop.order.inquiry.TankInquiry;
import com.aquashop.order.inquiry.TankInquiryRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataAccessException;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.nio.charset.StandardCharsets;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Tank enquiries against a real Postgres.
 *
 * <p>Real, and it has to be: the thing under test is that <em>Postgres</em>
 * encrypts these columns. An in-memory database has no {@code pgcrypto}, so a
 * green test against one would prove that the Java compiled, which is not the
 * claim being made. Same DSN-from-the-environment convention as
 * {@link CheckoutSagaTest}, and the same cost — the database is not created for
 * you and these tests skip silently when {@code ORDER_TEST_DSN} is absent.
 *
 * <pre>
 *   createdb orders_test
 *   ORDER_TEST_DSN=jdbc:postgresql://127.0.0.1:5432/orders_test \
 *   ORDER_TEST_USER=postgres mvn test
 * </pre>
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "ORDER_TEST_DSN", matches = ".+")
class TankInquiryTest {

    /** Not a secret. It is here precisely so that a wrong-key test has a right key to be wrong about. */
    private static final String KEY = "test-key-not-a-real-secret";

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
        registry.add("inquiries.encryption-key", () -> KEY);
    }

    @Autowired MockMvc mvc;
    @Autowired TankInquiryRepository inquiries;
    @Autowired JdbcTemplate jdbc;

    private static final String EMAIL = "priya@example.com";
    private static final String PHONE = "+91 98765 43210";
    private static final String MESSAGE =
            "120 litre planted tank, soft water, deliver to 14 Park Street. Cardinals, "
            + "otocinclus and something peaceful for the mid-water.";

    private static String body(String message, String email, String phone) {
        return """
               {"message": %s, "email": %s, "phone": %s}
               """.formatted(quote(message), quote(email), quote(phone));
    }

    private static String quote(String s) {
        return '"' + s.replace("\\", "\\\\").replace("\"", "\\\"") + '"';
    }

    // ---- the round trip -------------------------------------------------

    @Test
    void aUsableKeyEnablesTheFeature() {
        // The mirror of InquiryKeyMissingTest, which asserts the other half:
        // no key, application still starts, this one endpoint answers 503.
        assertThat(inquiries.keyAvailable()).isTrue();
        assertThat(inquiries.keyProblem()).isNull();
    }

    @Test
    void storesAnEnquiryAndCanReadItBackWithTheKey() {
        UUID id = inquiries.save(EMAIL, PHONE, MESSAGE);

        TankInquiry back = inquiries.findById(id).orElseThrow();
        assertThat(back.email()).isEqualTo(EMAIL);
        assertThat(back.phone()).isEqualTo(PHONE);
        assertThat(back.message()).isEqualTo(MESSAGE);
        assertThat(back.createdAt()).isNotNull();
    }

    /**
     * The claim the whole feature rests on. If this fails, everything else here
     * passing is worthless — the columns would be storing readable PII under a
     * BYTEA type, which looks encrypted in a schema dump and is not.
     */
    @Test
    void whatIsOnDiskIsNotThePlaintext() {
        UUID id = inquiries.save(EMAIL, PHONE, MESSAGE);

        byte[] email = jdbc.queryForObject(
                "SELECT email_enc FROM tank_inquiry WHERE id = ?", byte[].class, id);
        byte[] phone = jdbc.queryForObject(
                "SELECT phone_enc FROM tank_inquiry WHERE id = ?", byte[].class, id);
        byte[] message = jdbc.queryForObject(
                "SELECT message_enc FROM tank_inquiry WHERE id = ?", byte[].class, id);

        assertThat(raw(email)).doesNotContain(EMAIL).doesNotContain("example.com");
        assertThat(raw(phone)).doesNotContain("98765").doesNotContain("9876543210");
        assertThat(raw(message)).doesNotContain("Park Street").doesNotContain("Cardinals");
    }

    /**
     * Two submissions of the same address must not produce the same bytes.
     *
     * <p>Deterministic ciphertext would let anyone with read access to the
     * table — without the key — group enquiries by customer and tell that the
     * same person wrote twice. pgcrypto's fresh session key per call is what
     * prevents that, and it is also why there is no unique index on these
     * columns.
     */
    @Test
    void theSameAddressEncryptsDifferentlyEveryTime() {
        UUID first = inquiries.save(EMAIL, PHONE, MESSAGE);
        UUID second = inquiries.save(EMAIL, PHONE, MESSAGE);

        byte[] a = jdbc.queryForObject(
                "SELECT email_enc FROM tank_inquiry WHERE id = ?", byte[].class, first);
        byte[] b = jdbc.queryForObject(
                "SELECT email_enc FROM tank_inquiry WHERE id = ?", byte[].class, second);

        assertThat(a).isNotEqualTo(b);
    }

    /**
     * A wrong key raises, rather than quietly returning something.
     *
     * <p>This is the failure mode a rebuilt cluster with a re-generated secret
     * produces, and it must be loud: rows written under the old key are not
     * recoverable, and a decrypt that returned mojibake instead of throwing
     * would hide that until someone tried to phone a customer.
     */
    @Test
    void aWrongKeyFailsLoudlyRatherThanReturningRubbish() {
        UUID id = inquiries.save(EMAIL, PHONE, MESSAGE);

        assertThatThrownBy(() -> jdbc.queryForObject(
                "SELECT pgp_sym_decrypt(email_enc, ?) FROM tank_inquiry WHERE id = ?",
                String.class, "an-entirely-different-key", id))
                .isInstanceOf(DataAccessException.class);
    }

    @Test
    void theOnlyThingLegibleWithoutTheKeyIsTheLength() {
        UUID id = inquiries.save(EMAIL, PHONE, MESSAGE);

        Integer chars = jdbc.queryForObject(
                "SELECT message_chars FROM tank_inquiry WHERE id = ?", Integer.class, id);
        assertThat(chars).isEqualTo(MESSAGE.length());
    }

    @Test
    void anUnknownIdIsEmptyRatherThanAnError() {
        assertThat(inquiries.findById(UUID.randomUUID())).isEmpty();
    }

    // ---- the endpoint ---------------------------------------------------

    @Test
    void theEndpointAcceptsASubmissionAndAnswersWithAnIdAlone() throws Exception {
        long before = inquiries.count();

        MvcResult result = mvc.perform(post("/v1/inquiries")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body(MESSAGE, EMAIL, PHONE)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").exists())
                .andReturn();

        String responseBody = result.getResponse().getContentAsString();

        // The response must not carry the submission back out. This is the
        // assertion that catches someone "helpfully" widening InquiryAccepted.
        assertThat(responseBody).doesNotContain(EMAIL).doesNotContain("98765")
                .doesNotContain("Park Street");
        // Nor a Location header pointing at a GET that does not exist.
        assertThat(result.getResponse().getHeader("Location")).isNull();

        assertThat(inquiries.count()).isEqualTo(before + 1);
    }

    @Test
    void theEndpointRefusesAnEmptyMessage() throws Exception {
        long before = inquiries.count();
        mvc.perform(post("/v1/inquiries")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body("   ", EMAIL, PHONE)))
                .andExpect(status().isBadRequest());
        assertThat(inquiries.count()).isEqualTo(before);
    }

    @Test
    void theEndpointRefusesSomethingThatIsNotAnEmailAddress() throws Exception {
        mvc.perform(post("/v1/inquiries")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body(MESSAGE, "priya-at-example", PHONE)))
                .andExpect(status().isBadRequest());
    }

    /**
     * There is no read path, and a test says so.
     *
     * <p>Written to fail the day somebody adds one without reading ADR 0021 —
     * an unauthenticated list endpoint over this table would undo every other
     * test in this class.
     */
    @Test
    void thereIsNoWayToReadAnEnquiryBackOverHttp() throws Exception {
        UUID id = inquiries.save(EMAIL, PHONE, MESSAGE);

        mvc.perform(get("/v1/inquiries/" + id)).andExpect(status().isNotFound());
        mvc.perform(get("/v1/inquiries")).andExpect(status().isMethodNotAllowed());
    }

    private static String raw(byte[] bytes) {
        // ISO-8859-1 so every byte maps to a character and nothing is lost to
        // replacement characters before the assertion looks at it.
        return new String(bytes, StandardCharsets.ISO_8859_1);
    }
}
