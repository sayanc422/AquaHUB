package com.aquashop.catalog.domain;

/**
 * Whether a section of the shop can be entered.
 *
 * <p>{@code COMING_SOON} exists so a section can be announced before it is
 * stocked. Saltwater is on the shop front, greyed out and labelled, rather than
 * absent — a customer who wants marine fish learns that we are working on it
 * instead of concluding we do not sell them.
 */
public enum CategoryStatus {
    ACTIVE,
    COMING_SOON,
    /** Built but not for customers: seasonal sections, staging a new family. */
    HIDDEN;

    public boolean isBrowsable() {
        return this == ACTIVE;
    }
}
