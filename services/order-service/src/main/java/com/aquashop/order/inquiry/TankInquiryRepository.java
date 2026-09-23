package com.aquashop.order.inquiry;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

/**
 * Writes and reads {@code tank_inquiry}, with the encryption done by Postgres.
 *
 * <p><b>Why not JPA.</b> Every other table in this service is a mapped entity.
 * This one is not, because the ciphertext must never exist as a plaintext field
 * on a managed object: a JPA entity with an {@code AttributeConverter} means
 * Hibernate holds the decrypted email in its first-level cache, in a dirty-check
 * snapshot, and in whatever a future {@code findAll()} returns. Plain SQL with
 * {@code pgp_sym_encrypt} keeps the plaintext alive for exactly the length of
 * one INSERT statement.
 *
 * <p><b>Why the database and not the application.</b> The same reason
 * payment-service enforces its append-only ledger with a Postgres trigger
 * rather than a code review: an invariant that lives in one service's Java is
 * an invariant that the next service, the next migration, or a psql session
 * does not have. Encrypting in {@code pgp_sym_encrypt} means the plaintext is
 * never what gets written to the WAL, never what a base backup contains, and
 * never what {@code SELECT *} shows.
 *
 * <p><b>What this does not protect against.</b> The key travels to Postgres as
 * a bind parameter on every call. Anyone who can read the Postgres server log
 * with {@code log_statement = 'all'} and parameter logging on, or who can
 * attach to the process, sees it. This is a real limit of doing symmetric
 * crypto inside the database rather than an oversight — ADR 0021 states it.
 */
@Repository
public class TankInquiryRepository {

    /**
     * AES-256 rather than pgcrypto's AES-128 default, and compression off.
     *
     * <p>Compression before encryption is not free: PGP's default would shrink
     * a repetitive message before encrypting it, and the resulting ciphertext
     * length would then leak something about the content. There is nothing to
     * gain here — these are short messages — so the only effect would be the
     * leak.
     */
    private static final String PGP_OPTIONS = "cipher-algo=aes256, compress-algo=0";

    private static final String INSERT = """
            INSERT INTO tank_inquiry (id, email_enc, phone_enc, message_enc, message_chars)
            VALUES (?,
                    pgp_sym_encrypt(?, ?, ?),
                    pgp_sym_encrypt(?, ?, ?),
                    pgp_sym_encrypt(?, ?, ?),
                    ?)
            """;

    private static final String SELECT_ONE = """
            SELECT id,
                   pgp_sym_decrypt(email_enc,   ?) AS email,
                   pgp_sym_decrypt(phone_enc,   ?) AS phone,
                   pgp_sym_decrypt(message_enc, ?) AS message,
                   created_at
              FROM tank_inquiry
             WHERE id = ?
            """;

    /**
     * Short enough to be a typo, long enough that nothing shorter can be an
     * accident. 16 characters is not a security threshold — pgcrypto stretches
     * the passphrase with S2K either way — it is a tripwire for the case that
     * actually happens: someone wiring the Secret by hand and putting
     * {@code changeme} in it.
     */
    private static final int MIN_KEY_CHARS = 16;

    private static final Logger log = LoggerFactory.getLogger(TankInquiryRepository.class);

    private final JdbcTemplate jdbc;

    /** Null exactly when {@link #keyProblem} is non-null. Never a fallback value. */
    private final String key;

    /** Why the key is unusable, in a sentence fit to return to a caller — or null. */
    private final String keyProblem;

    public TankInquiryRepository(JdbcTemplate jdbc,
                                 @Value("${inquiries.encryption-key:}") String key) {
        this.jdbc = jdbc;
        this.keyProblem = problemWith(key);
        this.key = this.keyProblem == null ? key.trim() : null;

        // Said once, at boot, at WARN. A feature that is silently off is a
        // feature that stays off: the operator who rebuilt the cluster and
        // forgot the Secret finds out here rather than from a customer.
        if (this.keyProblem != null) {
            log.warn("tank enquiries are DISABLED: {}. Everything else in order-service is "
                     + "unaffected. See docs/runbooks/rotate-or-create-the-inquiry-key.md",
                     this.keyProblem);
        }
    }

    /**
     * Whether enquiries can be accepted at all.
     *
     * <p><b>A missing key disables this one endpoint and nothing else.</b> It
     * deliberately does not stop the Spring context. `order-service` also owns
     * the checkout saga — the part of this platform that has been hardened,
     * crash-tested and verified in k3d over many sessions — and a forgotten
     * Secret for a bolt-on enquiry form must not be able to take commerce down
     * with it. The blast radius of the mistake should match the size of the
     * feature.
     *
     * <p>The safety property is unchanged either way: there is still no
     * fallback key, still nothing written in plaintext, still no row accepted
     * that cannot be encrypted. The only difference is what else breaks.
     * See ADR 0021.
     */
    public boolean keyAvailable() {
        return key != null;
    }

    /** Why enquiries are disabled, or null when they are not. Safe to show a caller: names no secret. */
    public String keyProblem() {
        return keyProblem;
    }

    /**
     * Refuse a missing or placeholder key. Never substitute one.
     *
     * <p>A baked-in default would be the genuinely dangerous option: it accepts
     * submissions and writes rows that <em>look</em> encrypted while being
     * readable by anyone holding this source file, and then makes those same
     * rows permanently undecryptable the day the real key arrives — discovered,
     * at the earliest, when somebody tries to phone a customer. Refusing the
     * write is the safe answer whether the refusal happens at boot or at the
     * endpoint.
     */
    private static String problemWith(String candidate) {
        String k = candidate == null ? "" : candidate.trim();
        if (k.isEmpty()) {
            return "inquiries.encryption-key is not set (INQUIRY_ENCRYPTION_KEY)";
        }
        if (k.length() < MIN_KEY_CHARS) {
            return "inquiries.encryption-key is shorter than " + MIN_KEY_CHARS
                   + " characters, so it is almost certainly a placeholder rather than a key";
        }
        return null;
    }

    /**
     * Guards every statement that needs the key.
     *
     * <p>Belt and braces with {@link #keyAvailable()}: the controller checks
     * first so it can answer 503 with something useful, and this stops any
     * future caller that forgets to. A {@code null} key reaching
     * {@code pgp_sym_encrypt} would otherwise be a database error at best.
     */
    private String requireKey() {
        if (key == null) {
            throw new InquiryKeyUnavailableException(keyProblem);
        }
        return key;
    }

    /**
     * Store one enquiry. The caller gets an id back and nothing else.
     *
     * <p>{@code message.length()} is counted here, on the plaintext, because
     * the database never sees it uncounted — the whole point of
     * {@code message_chars} is to be the one fact about a submission that is
     * legible without the key.
     */
    public UUID save(String email, String phone, String message) {
        String k = requireKey();
        UUID id = UUID.randomUUID();
        jdbc.update(INSERT,
                id,
                email, k, PGP_OPTIONS,
                phone, k, PGP_OPTIONS,
                message, k, PGP_OPTIONS,
                message.length());
        return id;
    }

    /**
     * Decrypt one enquiry by id.
     *
     * <p><b>Nothing in the HTTP surface calls this.</b> There is no
     * {@code GET /v1/inquiries/{id}} and no list endpoint, because this project
     * has no authentication anywhere and an unauthenticated read of this table
     * would undo the entire reason it is encrypted. It exists so the encrypt →
     * decrypt round trip is asserted by a test against a real Postgres rather
     * than assumed, and as the seam a future staff-portal read path would use
     * once there is something to authenticate against. See ADR 0021.
     *
     * <p>A wrong key makes {@code pgp_sym_decrypt} raise
     * {@code Wrong key or corrupt data}, which surfaces as a
     * {@code DataAccessException}. It is deliberately not caught and turned
     * into {@code Optional.empty()}: "the key is wrong" and "there is no such
     * row" are different problems and must not look the same.
     */
    public Optional<TankInquiry> findById(UUID id) {
        String key = requireKey();
        try {
            return Optional.ofNullable(jdbc.queryForObject(SELECT_ONE, (rs, n) -> new TankInquiry(
                    rs.getObject("id", UUID.class),
                    rs.getString("email"),
                    rs.getString("phone"),
                    rs.getString("message"),
                    rs.getTimestamp("created_at", java.util.Calendar.getInstance(
                            java.util.TimeZone.getTimeZone("UTC"))) instanceof Timestamp t
                            ? t.toInstant() : Instant.EPOCH), key, key, key, id));
        } catch (EmptyResultDataAccessException noSuchRow) {
            return Optional.empty();
        }
    }

    /** How many enquiries exist. Counts rows; decrypts nothing. */
    public long count() {
        Long n = jdbc.queryForObject("SELECT count(*) FROM tank_inquiry", Long.class);
        return n == null ? 0L : n;
    }
}
