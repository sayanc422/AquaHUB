package com.aquashop.order;

import com.aquashop.order.domain.ShippingCalendar;
import org.junit.jupiter.api.Test;

import java.time.DayOfWeek;
import java.time.ZoneId;
import java.time.ZonedDateTime;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The dispatch calendar decides when live animals are allowed to be in a van,
 * so every branch gets a test. These are the rules a customer will be told on
 * the phone; "I think it ships Monday" is not good enough.
 */
class ShippingCalendarTest {

    private static final ZoneId IST = ZoneId.of("Asia/Kolkata");
    private final ShippingCalendar calendar = new ShippingCalendar(IST);

    private static ZonedDateTime at(String isoLocal) {
        return ZonedDateTime.parse(isoLocal + "+05:30[Asia/Kolkata]");
    }

    @Test
    void livestockOrderedMondayMorningLeavesThatMonday() {
        ZonedDateTime dispatch = calendar.nextDispatch(at("2026-09-14T09:00:00"), true);
        assertThat(dispatch.getDayOfWeek()).isEqualTo(DayOfWeek.MONDAY);
        assertThat(dispatch.toLocalDate()).isEqualTo(at("2026-09-14T00:00:00").toLocalDate());
        // Not "now": the order waits for the van, and an order placed at 09:00
        // leaves with one placed at 13:00.
        assertThat(dispatch.getHour()).isEqualTo(14);
    }

    @Test
    void afterTheCutOffTheOrderMissesTodaysVan() {
        ZonedDateTime dispatch = calendar.nextDispatch(at("2026-09-14T14:00:00"), true);
        assertThat(dispatch.getDayOfWeek()).isEqualTo(DayOfWeek.TUESDAY);
    }

    @Test
    void justBeforeTheCutOffItStillCatchesIt() {
        ZonedDateTime dispatch = calendar.nextDispatch(at("2026-09-14T13:59:59"), true);
        assertThat(dispatch.getDayOfWeek()).isEqualTo(DayOfWeek.MONDAY);
    }

    /**
     * The rule the whole calendar exists for: a bag of fish posted on Thursday
     * sits in a depot over the weekend and arrives dead.
     */
    @Test
    void livestockOrderedThursdayWaitsForMonday() {
        ZonedDateTime dispatch = calendar.nextDispatch(at("2026-09-17T10:00:00"), true);
        assertThat(dispatch.getDayOfWeek()).isEqualTo(DayOfWeek.MONDAY);
        assertThat(dispatch.toLocalDate()).isEqualTo(at("2026-09-21T00:00:00").toLocalDate());
    }

    @Test
    void livestockOrderedFridayOrSaturdayAlsoWaitsForMonday() {
        assertThat(calendar.nextDispatch(at("2026-09-18T10:00:00"), true).getDayOfWeek())
                .isEqualTo(DayOfWeek.MONDAY);
        assertThat(calendar.nextDispatch(at("2026-09-19T10:00:00"), true).getDayOfWeek())
                .isEqualTo(DayOfWeek.MONDAY);
    }

    @Test
    void livestockOrderedWednesdayAfternoonWaitsForMondayNotThursday() {
        ZonedDateTime dispatch = calendar.nextDispatch(at("2026-09-16T15:00:00"), true);
        assertThat(dispatch.getDayOfWeek()).isEqualTo(DayOfWeek.MONDAY);
    }

    @Test
    void dryGoodsMayLeaveOnAThursday() {
        ZonedDateTime dispatch = calendar.nextDispatch(at("2026-09-17T10:00:00"), false);
        assertThat(dispatch.getDayOfWeek()).isEqualTo(DayOfWeek.THURSDAY);
    }

    @Test
    void dryGoodsOrderedFridayAfternoonWaitForMonday() {
        ZonedDateTime dispatch = calendar.nextDispatch(at("2026-09-18T16:00:00"), false);
        assertThat(dispatch.getDayOfWeek()).isEqualTo(DayOfWeek.MONDAY);
    }

    @Test
    void theAnswerIsNeverInThePast() {
        ZonedDateTime placed = at("2026-09-17T23:30:00");
        assertThat(calendar.nextDispatch(placed, true)).isAfter(placed);
        assertThat(calendar.nextDispatch(placed, false)).isAfter(placed);
    }

    /**
     * An order placed at 23:00 UTC on Sunday is already Monday in the shop's
     * time zone. The cut-off is the shop's, not the customer's.
     */
    @Test
    void theCutOffIsInTheShopsTimeZone() {
        ZonedDateTime sundayLateUtc = ZonedDateTime.parse("2026-09-13T23:00:00Z");
        ZonedDateTime dispatch = calendar.nextDispatch(sundayLateUtc, true);
        assertThat(dispatch.getZone()).isEqualTo(IST);
        assertThat(dispatch.getDayOfWeek()).isEqualTo(DayOfWeek.MONDAY);
    }
}
