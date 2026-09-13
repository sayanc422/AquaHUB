package com.aquashop.order.config;

import com.aquashop.order.domain.ShippingCalendar;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.ClientHttpRequestFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

import java.time.Clock;
import java.time.Duration;
import java.time.ZoneId;

@Configuration
public class OrderConfig {

    /**
     * Injected rather than used statically, so the shipping calendar can be
     * tested at 13:59 on a Wednesday without waiting for one.
     */
    @Bean
    public Clock clock() {
        return Clock.systemUTC();
    }

    @Bean
    public ShippingCalendar shippingCalendar(@Value("${orders.dispatch-zone:Asia/Kolkata}") String zone) {
        // The shop's local time, not UTC: a cut-off of 14:00 means 14:00 where
        // the courier collects.
        return new ShippingCalendar(ZoneId.of(zone));
    }

    /**
     * Every call to inventory-service is bounded.
     *
     * <p>Without these, a slow inventory service holds checkout threads until
     * the pool is exhausted, and one degraded dependency becomes a dead
     * storefront. The read timeout is deliberately short: a reservation that
     * has not answered in two seconds is not going to, and a retry with the
     * same idempotency key is safe.
     */
    @Bean
    public RestClient inventoryRestClient(
            @Value("${inventory.base-url:http://inventory-service:8081}") String baseUrl,
            @Value("${inventory.connect-timeout-ms:1000}") int connectTimeoutMs,
            @Value("${inventory.read-timeout-ms:2000}") int readTimeoutMs) {

        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(Duration.ofMillis(connectTimeoutMs));
        factory.setReadTimeout(Duration.ofMillis(readTimeoutMs));
        ClientHttpRequestFactory bounded = factory;

        return RestClient.builder()
                .baseUrl(baseUrl)
                .requestFactory(bounded)
                .build();
    }
}
