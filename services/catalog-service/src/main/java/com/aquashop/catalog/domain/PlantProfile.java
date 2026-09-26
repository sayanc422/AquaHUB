package com.aquashop.catalog.domain;

import jakarta.persistence.*;

import java.math.BigDecimal;

/**
 * The care profile for a live plant -- the plant-side counterpart of
 * {@link SpeciesProfile}, and deliberately a separate table rather than more
 * nullable columns on that one.
 *
 * <p>The two share almost nothing. A fish has a temperament, a group size and
 * a minimum tank; a plant has a light requirement, a CO2 requirement, a growth
 * rate and a place in the tank. Folding plants into species_profile would have
 * meant every NOT NULL there becoming nullable, and the aquatics-advisor --
 * which reads species profiles to judge bioload and aggression -- learning to
 * skip rows that are not animals. A plant is not a very quiet fish.
 *
 * <p>One profile per species or cultivar, shared by every product that sells
 * it (a potted Anubias and one on driftwood are the same plant).
 */
@Entity
@Table(name = "plant_profile")
public class PlantProfile {

    public enum Placement { FOREGROUND, MIDGROUND, BACKGROUND, EPIPHYTE, FLOATING }
    public enum LightLevel { LOW, MEDIUM, HIGH }
    public enum Co2 { NOT_NEEDED, BENEFICIAL, REQUIRED }
    public enum GrowthRate { SLOW, MODERATE, FAST }
    public enum Difficulty { EASY, MODERATE, DEMANDING }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "scientific_name", nullable = false, unique = true)
    private String scientificName;

    @Column(name = "common_name", nullable = false)
    private String commonName;

    @Column(nullable = false, length = 64)
    private String family;

    @Column(nullable = false, length = 160)
    private String origin;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Placement placement;

    @Enumerated(EnumType.STRING)
    @Column(name = "light_level", nullable = false, length = 8)
    private LightLevel lightLevel;

    /**
     * Light at the substrate, in PAR (umol/m2/s). The level alone ("medium")
     * is what a customer reads; the number is what they can check with a meter
     * or a manufacturer's PAR chart, and it is the honest answer to "how
     * strong does the light need to be" -- wattage says what a fitting
     * consumes, not what reaches the plant.
     */
    @Column(name = "par_min", nullable = false) private int parMin;
    @Column(name = "par_max", nullable = false) private int parMax;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private Co2 co2;

    @Enumerated(EnumType.STRING)
    @Column(name = "growth_rate", nullable = false, length = 8)
    private GrowthRate growthRate;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private Difficulty difficulty;

    // BigDecimal for the same reason as SpeciesProfile: exact NUMERIC columns.
    @Column(name = "height_min_cm", nullable = false, precision = 5, scale = 1) private BigDecimal heightMinCm;
    @Column(name = "height_max_cm", nullable = false, precision = 5, scale = 1) private BigDecimal heightMaxCm;
    @Column(name = "temp_min_c", nullable = false, precision = 4, scale = 1)    private BigDecimal tempMinC;
    @Column(name = "temp_max_c", nullable = false, precision = 4, scale = 1)    private BigDecimal tempMaxC;
    @Column(name = "ph_min", nullable = false, precision = 3, scale = 1)        private BigDecimal phMin;
    @Column(name = "ph_max", nullable = false, precision = 3, scale = 1)        private BigDecimal phMax;

    @Column(nullable = false, columnDefinition = "text")
    private String propagation;

    /** What the plant is. Paragraphs are blank-line separated, as for fish. */
    @Column(nullable = false, columnDefinition = "text")
    private String description;

    /** How to keep it: planting, light, CO2, feeding, trimming, Indian conditions. */
    @Column(name = "care_guide", nullable = false, columnDefinition = "text")
    private String careGuide;

    /** Which fish and invertebrates suit it, and which will eat or uproot it. */
    @Column(nullable = false, columnDefinition = "text")
    private String tankmates;

    protected PlantProfile() { }

    public Long getId() { return id; }
    public String getScientificName() { return scientificName; }
    public String getCommonName() { return commonName; }
    public String getFamily() { return family; }
    public String getOrigin() { return origin; }
    public Placement getPlacement() { return placement; }
    public LightLevel getLightLevel() { return lightLevel; }
    public int getParMin() { return parMin; }
    public int getParMax() { return parMax; }
    public Co2 getCo2() { return co2; }
    public GrowthRate getGrowthRate() { return growthRate; }
    public Difficulty getDifficulty() { return difficulty; }
    public BigDecimal getHeightMinCm() { return heightMinCm; }
    public BigDecimal getHeightMaxCm() { return heightMaxCm; }
    public BigDecimal getTempMinC() { return tempMinC; }
    public BigDecimal getTempMaxC() { return tempMaxC; }
    public BigDecimal getPhMin() { return phMin; }
    public BigDecimal getPhMax() { return phMax; }
    public String getPropagation() { return propagation; }
    public String getDescription() { return description; }
    public String getCareGuide() { return careGuide; }
    public String getTankmates() { return tankmates; }
}
