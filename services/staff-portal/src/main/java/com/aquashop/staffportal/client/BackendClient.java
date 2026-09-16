package com.aquashop.staffportal.client;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

/**
 * The one place an upstream GET happens. Every call is bounded by
 * BackendConfig.timeoutMs -- a back-office page that hangs on a slow backend
 * is worse than one that shows an error, because nobody is behind it watching
 * a spinner; they are looking for an order.
 */
public class BackendClient {

    protected final HttpClient http;
    protected final ObjectMapper json = new ObjectMapper();
    protected final Duration timeout;

    protected BackendClient(Duration timeout) {
        this.timeout = timeout;
        this.http = HttpClient.newBuilder()
                .connectTimeout(timeout)
                .version(HttpClient.Version.HTTP_1_1)
                .build();
    }

    protected JsonNode getJson(String url) {
        HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                .timeout(timeout)
                .GET()
                .build();
        HttpResponse<String> response;
        try {
            response = http.send(request, HttpResponse.BodyHandlers.ofString());
        } catch (IOException e) {
            // e.getMessage() is null for some causes (UnknownHostException in
            // particular, confirmed by actually running this against an
            // unresolvable hostname) -- the class name is what makes the
            // error page and the log line say anything at all in that case.
            throw new BackendException(url + ": " + e.getClass().getSimpleName() + ": " + e.getMessage(), e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new BackendException(url + ": interrupted", e);
        }
        if (response.statusCode() == 404) {
            throw new BackendException(url + ": not found", true);
        }
        if (response.statusCode() / 100 != 2) {
            throw new BackendException(url + ": HTTP " + response.statusCode(), false);
        }
        try {
            return json.readTree(response.body());
        } catch (IOException e) {
            throw new BackendException(url + ": invalid JSON response", e);
        }
    }

    /** Liveness never calls out. Readiness does, with the tightest bound: fail fast. */
    public boolean ping(String baseUrl, String healthPath) {
        try {
            HttpRequest request = HttpRequest.newBuilder(URI.create(baseUrl + healthPath))
                    .timeout(Duration.ofMillis(Math.min(timeout.toMillis(), 1000)))
                    .GET()
                    .build();
            HttpResponse<Void> response = http.send(request, HttpResponse.BodyHandlers.discarding());
            return response.statusCode() / 100 == 2;
        } catch (Exception e) {
            return false;
        }
    }
}
