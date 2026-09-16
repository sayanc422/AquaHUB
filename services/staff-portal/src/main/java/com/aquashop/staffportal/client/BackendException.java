package com.aquashop.staffportal.client;

/** A backend call failed or timed out. Carries whether the resource was simply not found. */
public class BackendException extends RuntimeException {

    private final boolean notFound;

    public BackendException(String message, boolean notFound) {
        super(message);
        this.notFound = notFound;
    }

    public BackendException(String message, Throwable cause) {
        super(message, cause);
        this.notFound = false;
    }

    public boolean isNotFound() {
        return notFound;
    }
}
