package com.aquashop.order.notification;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * The default. {@code core} and {@code commerce} never deploy
 * notification-service, so this keeps checkout and the dispatch watcher
 * exactly as they behaved before this client existed.
 */
@Component
@ConditionalOnProperty(name = "notification.client", havingValue = "noop", matchIfMissing = true)
public class NoopNotificationClient implements NotificationClient {

    @Override
    public void notify(Event event, String orderId, String orderReference, String email) {
        // Nothing. See the class javadoc on NotificationClient.
    }
}
