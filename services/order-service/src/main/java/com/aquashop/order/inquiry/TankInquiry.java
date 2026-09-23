package com.aquashop.order.inquiry;

import java.time.Instant;
import java.util.UUID;

/**
 * A custom tank-setup enquiry, in the clear.
 *
 * <p>This type only ever exists <em>after</em> a successful decrypt, and
 * nothing on the HTTP surface returns it — {@code InquiryController} answers a
 * submission with an id and nothing else. It exists so the round-trip through
 * pgcrypto can be asserted by a test, and so that the day a staff-side read
 * path is built (ADR 0021 names it as the follow-up) there is already one
 * shape for a decrypted enquiry rather than two.
 *
 * <p>Deliberately not logged, not serialised by Jackson anywhere, and not
 * cached. A record that can be printed by accident is a record that will be.
 */
public record TankInquiry(UUID id, String email, String phone, String message, Instant createdAt) {

    /**
     * Overridden so that an accidental {@code log.info("{}", inquiry)} cannot
     * put a customer's address and phone number into a log aggregator. The
     * default record {@code toString()} prints every component, which is the
     * one behaviour this type must not have.
     */
    @Override
    public String toString() {
        return "TankInquiry[id=" + id + ", createdAt=" + createdAt + ", redacted]";
    }
}
