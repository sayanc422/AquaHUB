package com.aquashop.order.inquiry;

/**
 * The tank-enquiry encryption key is missing or is a placeholder, so nothing
 * can be encrypted and no enquiry can be stored.
 *
 * <p>Unchecked, and deliberately narrow: it means <em>this one feature</em> is
 * unavailable. It is not a database failure, not a bad request, and above all
 * not a reason for anything else in `order-service` to stop. The checkout saga
 * neither throws nor catches this, and never will — see
 * {@code TankInquiryRepository.keyAvailable()} and ADR 0021 for why a missing
 * enquiry key must not be able to take commerce down.
 *
 * <p>Its message names the configuration problem, never the key.
 */
public class InquiryKeyUnavailableException extends RuntimeException {

    public InquiryKeyUnavailableException(String problem) {
        super(problem == null ? "the tank-enquiry encryption key is unavailable" : problem);
    }
}
