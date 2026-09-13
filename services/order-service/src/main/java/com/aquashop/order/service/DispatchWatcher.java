package com.aquashop.order.service;

import com.aquashop.order.domain.CustomerOrder;
import com.aquashop.order.domain.OrderState;
import com.aquashop.order.repo.OrderEventRepository;
import com.aquashop.order.repo.OrderRepository;
import com.aquashop.order.domain.OrderEvent;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.List;

/**
 * Notices when a waiting order becomes dispatchable.
 *
 * <p><b>It is not load-bearing, and that is the point.</b> Whether an order may
 * ship is {@code now() >= dispatch_at}, evaluated wherever the question is
 * asked. This job records the moment for the notification service to pick up in
 * Phase 6 and moves the gauge; if it stops, no order is delayed and no order
 * ships early. The worst it can do is fail to send an email.
 *
 * <p>Exactly the same reasoning as inventory-service's reaper. The temptation
 * in both cases is to let a scheduled job own the transition, and in both cases
 * that makes the correctness of the business depend on the health of a cron.
 */
@Component
public class DispatchWatcher {

    private static final Logger log = LoggerFactory.getLogger(DispatchWatcher.class);

    private final OrderRepository orders;
    private final OrderEventRepository events;
    private final Clock clock;
    private final Counter becameDispatchable;

    public DispatchWatcher(OrderRepository orders, OrderEventRepository events,
                           Clock clock, MeterRegistry meters) {
        this.orders = orders;
        this.events = events;
        this.clock = clock;
        this.becameDispatchable = Counter.builder("orders_became_dispatchable_total")
                .description("Confirmed orders whose dispatch window opened.")
                .register(meters);
    }

    @Scheduled(fixedDelayString = "${orders.dispatch-scan-interval-ms:60000}")
    @Transactional
    public void scan() {
        Instant now = clock.instant();
        List<CustomerOrder> due = orders.findNewlyDispatchable(OrderState.CONFIRMED, now);
        for (CustomerOrder order : due) {
            order.setDispatchableSeenAt(now);
            // Not a state change: the order stays CONFIRMED. Shippability is
            // derived, so there is no transition to record -- only the fact
            // that the window has opened.
            events.save(new OrderEvent(order.getId(), OrderState.CONFIRMED, OrderState.CONFIRMED,
                    "dispatch window open"));
            becameDispatchable.increment();
            log.info("dispatch window open order={} dispatchAt={}",
                    order.getReference(), order.getDispatchAt());
        }
        if (!due.isEmpty()) {
            orders.saveAll(due);
        }
    }
}
