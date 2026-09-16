package com.aquashop.order.notification;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClient;

/**
 * notification-service, over HTTP.
 *
 * <p>Every exception is caught here, not upstream — see {@link
 * NotificationClient}'s javadoc. A short timeout (wired on the {@code
 * notificationRestClient} bean, see {@code OrderConfig}) plus a catch-all
 * means the slowest this can ever cost the caller is that timeout, and the
 * worst it can ever do is log a warning.
 */
@Component
@ConditionalOnProperty(name = "notification.client", havingValue = "http")
public class HttpNotificationClient implements NotificationClient {

    private static final Logger log = LoggerFactory.getLogger(HttpNotificationClient.class);

    private final RestClient http;

    public HttpNotificationClient(RestClient notificationRestClient) {
        this.http = notificationRestClient;
        log.info("notification client: notification-service over HTTP");
    }

    @Override
    public void notify(Event event, String orderId, String orderReference, String email) {
        try {
            http.post()
                    .uri("/v1/events")
                    .body(new EventBody(orderId, orderReference, event.name(), email))
                    .retrieve()
                    .toBodilessEntity();
        } catch (RestClientException e) {
            // Exactly the outcome NotificationClient's contract promises: log
            // and move on. This notification is lost, not retried here -- see
            // ADR 0020.
            log.warn("could not reach notification-service for order={} event={}: {}",
                    orderReference, event, e.getMessage());
        } catch (RuntimeException e) {
            log.warn("unexpected error notifying for order={} event={}: {}",
                    orderReference, event, e.getMessage());
        }
    }

    record EventBody(String orderId, String orderReference, String eventType, String email) { }
}
