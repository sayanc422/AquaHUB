package com.aquashop.order.service;

import com.aquashop.order.domain.CustomerOrder;
import com.aquashop.order.notification.NotificationClient;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Clock;

/**
 * Notices when a waiting order becomes dispatchable.
 *
 * <p><b>It is not load-bearing, and that is the point.</b> Whether an order may
 * ship is {@code now() >= dispatch_at}, evaluated wherever the question is
 * asked. This job records the moment and moves the gauge; if it stops, no
 * order is delayed and no order ships early. It also pushes {@code
 * NotificationClient.Event.ORDER_DISPATCHABLE} to notification-service, a
 * best-effort side channel with no compensation (ADR 0020) that stands in for
 * the NATS subscription Phase 6 replaces it with. The worst any of this can
 * do is fail to send an email.
 *
 * <p>Exactly the same reasoning as inventory-service's reaper. The temptation
 * in both cases is to let a scheduled job own the transition, and in both cases
 * that makes the correctness of the business depend on the health of a cron.
 */
@Component
public class DispatchWatcher {

    private static final Logger log = LoggerFactory.getLogger(DispatchWatcher.class);

    private final OrderSteps steps;
    private final NotificationClient notifications;
    private final Clock clock;
    private final Counter becameDispatchable;

    public DispatchWatcher(OrderSteps steps, NotificationClient notifications,
                           Clock clock, MeterRegistry meters) {
        this.steps = steps;
        this.notifications = notifications;
        this.clock = clock;
        this.becameDispatchable = Counter.builder("orders_became_dispatchable_total")
                .description("Confirmed orders whose dispatch window opened.")
                .register(meters);
    }

    /**
     * Deliberately not {@code @Transactional} itself. The DB write lives in
     * {@link OrderSteps#markDispatchable}, a separate bean, for the same
     * reason {@code OrderSteps} exists at all: a call from one method to
     * another on the <em>same</em> class never passes through Spring's
     * {@code @Transactional} proxy, so putting the transactional method here
     * and calling it via {@code this.} would silently run with no transaction.
     * Only once that call returns — its transaction already committed — does
     * this method fire notifications, so a notification-service outage can
     * never affect the gauge write it exists to react to.
     */
    @Scheduled(fixedDelayString = "${orders.dispatch-scan-interval-ms:60000}")
    public void scan() {
        for (CustomerOrder order : steps.markDispatchable(clock.instant())) {
            becameDispatchable.increment();
            log.info("dispatch window open order={} dispatchAt={}",
                    order.getReference(), order.getDispatchAt());
            notifications.notify(NotificationClient.Event.ORDER_DISPATCHABLE,
                    order.getId().toString(), order.getReference(), order.getEmail());
        }
    }
}
