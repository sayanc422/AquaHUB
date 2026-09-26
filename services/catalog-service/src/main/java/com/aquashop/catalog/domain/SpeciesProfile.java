package com.aquashop.catalog.domain;

import jakarta.persistence.*;

import java.math.BigDecimal;

/**
 * The care profile a customer reads before buying, and the data the
 * aquatics-advisor service will later read through this service's API to
 * answer compatibility questions. catalog-service owns it; nobody else
 * writes it.
 */
@Entity
@Table(name = "species_profile")
public class SpeciesProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "scientific_name", nullable = false)
    private String scientificName;

    @Column(name = "common_name", nullable = false)
    private String commonName;

    // BigDecimal, not double, on every measurement below.
    //
    // The columns are NUMERIC(n,1) -- exact decimal, which is right for values
    // a person types and reads: a pH of 6.8, not 6.800000000000000266. A bare
    // `double` field maps to float(53), so `ddl-auto: validate` refused to
    // start on this service's first ever boot, and Hibernate then refused the
    // precision/scale annotation outright: "scale has no meaning for SQL
    // floating point types". That error is the mapping telling the truth --
    // an exact column needs an exact field, not a more detailed description of
    // an inexact one.
    //
    // It also matters downstream. aquatics-advisor computes interval overlap
    // across every inhabitant of a tank, and a 0.1 step that is not exactly
    // 0.1 turns "6.8 is within 6.8-7.5" into a coin toss at the boundary. The
    // published JSON stays a number: the DTO converts at the edge.
    @Column(name = "max_size_cm", nullable = false, precision = 5, scale = 2)
    private BigDecimal maxSizeCm;

    @Column(name = "min_tank_litres", nullable = false)
    private int minTankLitres;

    @Column(name = "min_group_size", nullable = false)
    private int minGroupSize;

    @Column(name = "temp_min_c", nullable = false, precision = 4, scale = 1) private BigDecimal tempMinC;
    @Column(name = "temp_max_c", nullable = false, precision = 4, scale = 1) private BigDecimal tempMaxC;
    @Column(name = "ph_min", nullable = false, precision = 3, scale = 1)     private BigDecimal phMin;
    @Column(name = "ph_max", nullable = false, precision = 3, scale = 1)     private BigDecimal phMax;
    @Column(name = "dgh_min", nullable = false, precision = 4, scale = 1)    private BigDecimal dghMin;
    @Column(name = "dgh_max", nullable = false, precision = 4, scale = 1)    private BigDecimal dghMax;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Temperament temperament;

    @Enumerated(EnumType.STRING)
    @Column(name = "care_level", nullable = false, length = 16)
    private CareLevel careLevel;

    @Column(nullable = false, length = 32)
    private String diet;

    @Column(name = "plant_safe", nullable = false)
    private boolean plantSafe;

    /**
     * What kind of animal this is. A fact about the species, so it lives here
     * rather than in whichever consumer needs it first -- aquatics-advisor uses
     * it to stop counting a shrimp's length as though it were a fish's bioload.
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "animal_group", nullable = false, length = 16)
    private AnimalGroup animalGroup;

    @Column(name = "care_notes", columnDefinition = "text")
    private String careNotes;

    /**
     * What the animal is -- origin, appearance, behaviour, breeding -- as
     * opposed to careNotes, which is what to do about it. Kept apart so the
     * short practical note stays short. Paragraphs are separated by a blank
     * line; the storefront splits on that. NULL for profiles nobody has
     * written one for yet (shrimp and snails, as of V20).
     */
    @Column(name = "description", columnDefinition = "text")
    private String description;

    protected SpeciesProfile() { }

    public enum Temperament { PEACEFUL, SEMI_AGGRESSIVE, AGGRESSIVE, TERRITORIAL }
    public enum CareLevel { BEGINNER, INTERMEDIATE, ADVANCED }
    public enum AnimalGroup { FISH, SHRIMP, SNAIL }

    public Long getId() { return id; }
    public String getScientificName() { return scientificName; }
    public String getCommonName() { return commonName; }
    public BigDecimal getMaxSizeCm() { return maxSizeCm; }
    public int getMinTankLitres() { return minTankLitres; }
    public int getMinGroupSize() { return minGroupSize; }
    public BigDecimal getTempMinC() { return tempMinC; }
    public BigDecimal getTempMaxC() { return tempMaxC; }
    public BigDecimal getPhMin() { return phMin; }
    public BigDecimal getPhMax() { return phMax; }
    public BigDecimal getDghMin() { return dghMin; }
    public BigDecimal getDghMax() { return dghMax; }
    public Temperament getTemperament() { return temperament; }
    public CareLevel getCareLevel() { return careLevel; }
    public String getDiet() { return diet; }
    public boolean isPlantSafe() { return plantSafe; }
    public AnimalGroup getAnimalGroup() { return animalGroup; }
    public String getCareNotes() { return careNotes; }
    public String getDescription() { return description; }
}
