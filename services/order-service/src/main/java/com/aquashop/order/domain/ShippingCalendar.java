package com.aquashop.order.domain;

import java.time.DayOfWeek;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.EnumSet;
import java.util.Set;

/**
 * When an order may physically leave the building.
 *
 * <p>This is the rule that makes livestock a different domain from a bookshop.
 * A bag of fish posted on a Thursday sits in a depot over the weekend and
 * arrives dead, so livestock dispatches only early in the week — and an order
 * placed on Thursday afternoon is <em>confirmed and paid for</em> on Thursday
 * and cannot ship until Monday. The order is legitimately in a waiting state
 * that no event will end: only the clock will.
 *
 * <p>Pure and clock-injected, so every branch is a unit test rather than a
 * conversation about what happens at 13:59 on a Wednesday.
 */
public final class ShippingCalendar {

    /**
     * Never Thursday or Friday for anything alive: those bags spend the weekend
     * in a depot. Saturday and Sunday are not dispatch days at all.
     */
    private static final Set<DayOfWeek> LIVESTOCK_DAYS =
            EnumSet.of(DayOfWeek.MONDAY, DayOfWeek.TUESDAY, DayOfWeek.WEDNESDAY);

    private static final Set<DayOfWeek> DRY_GOODS_DAYS = EnumSet.of(
            DayOfWeek.MONDAY, DayOfWeek.TUESDAY, DayOfWeek.WEDNESDAY,
            DayOfWeek.THURSDAY, DayOfWeek.FRIDAY);

    /** After this, the courier has gone and the order waits for the next day. */
    private static final LocalTime CUT_OFF = LocalTime.of(14, 0);

    private final ZoneId zone;

    public ShippingCalendar(ZoneId zone) {
        this.zone = zone;
    }

    /**
     * The first moment this order may be dispatched, at or after {@code placedAt}.
     *
     * <p>Returned as the cut-off time on the chosen day: an order that qualifies
     * for today still waits for the van, and an order placed at 09:00 on Monday
     * and one placed at 13:00 on Monday leave together. Returning "now" for the
     * first would imply a promise the shop floor cannot keep.
     */
    public ZonedDateTime nextDispatch(ZonedDateTime placedAt, boolean hasLivestock) {
        Set<DayOfWeek> days = hasLivestock ? LIVESTOCK_DAYS : DRY_GOODS_DAYS;
        ZonedDateTime candidate = placedAt.withZoneSameInstant(zone);

        // Missed today's van: start looking from tomorrow.
        if (!candidate.toLocalTime().isBefore(CUT_OFF)) {
            candidate = candidate.plusDays(1);
        }
        while (!days.contains(candidate.getDayOfWeek())) {
            candidate = candidate.plusDays(1);
        }
        return candidate.withHour(CUT_OFF.getHour())
                .withMinute(CUT_OFF.getMinute())
                .withSecond(0)
                .withNano(0);
    }

    public ZoneId zone() {
        return zone;
    }
}
