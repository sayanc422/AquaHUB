package com.aquashop.order.client;

import java.util.UUID;

/**
 * The hold ran out before the order could commit it. If this arrives after
 * payment, the money has to go back.
 */
public class ReservationExpiredException extends RuntimeException {
    public ReservationExpiredException(UUID reservationId, String code) {
        super("reservation " + reservationId + " could not be committed: " + code);
    }
}
