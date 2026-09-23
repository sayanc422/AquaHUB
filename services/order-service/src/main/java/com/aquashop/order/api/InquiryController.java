package com.aquashop.order.api;

import com.aquashop.order.inquiry.InquiryKeyUnavailableException;
import com.aquashop.order.inquiry.TankInquiryRepository;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

/**
 * Custom tank-setup enquiries: write-only.
 *
 * <p><b>There is exactly one method here and that is the design.</b> No
 * {@code GET /{id}}, no list, no search, no count. This service has no
 * authentication and neither does anything in front of it, so any read
 * endpoint added today would be a read endpoint for everyone on the network —
 * which would make encrypting the columns theatre. The shop's current way to
 * read an enquiry is a {@code psql} session held by someone who also holds the
 * key. That is a genuine gap, recorded as one in ADR 0021, not a feature.
 *
 * <p>No {@code Location} header on the 201 either, for the same reason: a
 * {@code Location} pointing at a URL that returns 404 is a promise this service
 * does not keep.
 */
@RestController
@RequestMapping("/v1/inquiries")
public class InquiryController {

    private static final Logger log = LoggerFactory.getLogger(InquiryController.class);

    private final TankInquiryRepository inquiries;

    public InquiryController(TankInquiryRepository inquiries) {
        this.inquiries = inquiries;
    }

    /**
     * Accept one enquiry.
     *
     * <p>{@code @Transactional} for one statement is not ceremony: without it
     * the insert runs in autocommit and the encrypt happens outside any unit
     * of work, which is fine today and stops being fine the moment a second
     * statement joins it.
     */
    @PostMapping
    @Transactional
    public ResponseEntity<InquiryDtos.InquiryAccepted> submit(
            @Valid @RequestBody InquiryDtos.InquiryRequest body) {

        // Without a key, this endpoint is the only thing in order-service that
        // stops working. 503 rather than 500: the request was fine, the service
        // is not configured to answer it, and it will start working the moment
        // the Secret exists — which is exactly what 503 means.
        //
        // The alternative, refusing to start the whole application, was the
        // first shape of this and was rejected: order-service also owns the
        // checkout saga, and a forgotten Secret for a bolt-on enquiry form must
        // not be able to take commerce down. Nothing about the safety property
        // changes — there is still no fallback key and still no plaintext
        // written — only the blast radius of the mistake. See ADR 0021.
        if (!inquiries.keyAvailable()) {
            // Checked here as well as inside the repository so the refusal
            // costs nothing — no transaction, no round trip. Both paths throw
            // the same exception, so both render identically below.
            throw new InquiryKeyUnavailableException(inquiries.keyProblem());
        }

        UUID id = inquiries.save(body.email().trim(), body.phone().trim(), body.message().trim());

        // The id and the length, never the content. This line is the whole
        // operational view of the feature, so it has to be safe to ship to a
        // log aggregator that nobody audits.
        log.info("tank inquiry accepted id={} messageChars={}", id, body.message().trim().length());

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new InquiryDtos.InquiryAccepted(id.toString()));
    }

    /**
     * Renders a missing encryption key as a 503 that says what to do about it.
     *
     * <p>Scoped to this controller deliberately. It is the only place in
     * order-service where this exception can be raised, and a global handler
     * would imply the rest of the service has an opinion about the enquiry
     * key. It does not, and must not — that separation is the whole point of
     * this shape.
     */
    @ExceptionHandler(InquiryKeyUnavailableException.class)
    public ResponseEntity<InquiryDtos.InquiryUnavailable> keyUnavailable(
            InquiryKeyUnavailableException e) {

        log.warn("tank inquiry refused: {}", e.getMessage());
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(new InquiryDtos.InquiryUnavailable(
                        e.getMessage(),
                        "docs/runbooks/rotate-or-create-the-inquiry-key.md",
                        "tank enquiries only; checkout, carts and orders are unaffected"));
    }
}
