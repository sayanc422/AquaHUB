package com.aquashop.catalog.domain;

import jakarta.persistence.*;

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

    @Column(name = "max_size_cm", nullable = false)
    private double maxSizeCm;

    @Column(name = "min_tank_litres", nullable = false)
    private int minTankLitres;

    @Column(name = "min_group_size", nullable = false)
    private int minGroupSize;

    @Column(name = "temp_min_c", nullable = false) private double tempMinC;
    @Column(name = "temp_max_c", nullable = false) private double tempMaxC;
    @Column(name = "ph_min", nullable = false)     private double phMin;
    @Column(name = "ph_max", nullable = false)     private double phMax;
    @Column(name = "dgh_min", nullable = false)    private double dghMin;
    @Column(name = "dgh_max", nullable = false)    private double dghMax;

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

    @Column(name = "care_notes", columnDefinition = "text")
    private String careNotes;

    protected SpeciesProfile() { }

    public enum Temperament { PEACEFUL, SEMI_AGGRESSIVE, AGGRESSIVE, TERRITORIAL }
    public enum CareLevel { BEGINNER, INTERMEDIATE, ADVANCED }

    public Long getId() { return id; }
    public String getScientificName() { return scientificName; }
    public String getCommonName() { return commonName; }
    public double getMaxSizeCm() { return maxSizeCm; }
    public int getMinTankLitres() { return minTankLitres; }
    public int getMinGroupSize() { return minGroupSize; }
    public double getTempMinC() { return tempMinC; }
    public double getTempMaxC() { return tempMaxC; }
    public double getPhMin() { return phMin; }
    public double getPhMax() { return phMax; }
    public double getDghMin() { return dghMin; }
    public double getDghMax() { return dghMax; }
    public Temperament getTemperament() { return temperament; }
    public CareLevel getCareLevel() { return careLevel; }
    public String getDiet() { return diet; }
    public boolean isPlantSafe() { return plantSafe; }
    public String getCareNotes() { return careNotes; }
}
