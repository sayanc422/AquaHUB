package com.aquashop.order.api;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * The wire contract for custom tank-setup enquiries.
 *
 * <p>Separate from {@link OrderDtos} on purpose. An enquiry is not an order and
 * shares no field with one; putting the two in the same file would be the first
 * step towards someone reusing {@code OrderView} for it and echoing an email
 * address back over HTTP.
 */
public final class InquiryDtos {

    private InquiryDtos() { }

    /**
     * What a customer submits.
     *
     * <p>The bounds are not cosmetic. {@code message} is capped because the
     * column is encrypted and an unbounded field is an unbounded ciphertext,
     * and because a public endpoint with no authentication and no rate limit
     * (ADR 0021 names both) should not also accept a megabyte per request.
     *
     * <p>{@code phone} is checked for shape, not validity. Nothing here can
     * tell a real Indian mobile from a plausible-looking one, and pretending
     * otherwise by writing a stricter regex would reject correct international
     * numbers to catch nothing. The check exists to refuse prose in the phone
     * field, which is the actual failure mode of a free-text form.
     */
    public record InquiryRequest(
            @NotBlank @Size(max = 4000) String message,
            @NotBlank @Email @Size(max = 190) String email,
            @NotBlank @Size(min = 7, max = 24)
            @Pattern(regexp = "^\\+?[0-9][0-9 ()\\-]*$",
                     message = "must look like a phone number") String phone) { }

    /**
     * What comes back: an id, and nothing the customer sent.
     *
     * <p>Echoing the submission back would put the email and phone number into
     * the response body, the BFF's memory, and any proxy log along the way —
     * for data whose entire reason for existing in ciphertext is that it should
     * not be sitting in the clear anywhere. The id is enough to quote in a
     * support conversation and worth nothing to anyone who intercepts it,
     * because there is no endpoint that resolves it.
     */
    public record InquiryAccepted(String id) { }

    /**
     * What a caller gets when the encryption key is missing.
     *
     * <p>An explicit body rather than Spring's default error shape, because
     * Spring omits the exception message unless {@code server.error.include-message}
     * is set globally — and turning that on would start leaking every other
     * handler's exception messages to satisfy this one endpoint. A 503 that
     * says only "Service Unavailable" sends whoever is debugging it to the
     * logs of a service that looks entirely healthy, which is precisely the
     * wrong place.
     *
     * <p>{@code reason} names a configuration problem and never the key
     * itself.
     */
    public record InquiryUnavailable(String reason, String runbook, String affects) { }
}
