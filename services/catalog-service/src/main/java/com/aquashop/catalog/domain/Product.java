package com.aquashop.catalog.domain;

import jakarta.persistence.*;
import java.math.BigDecimal;

@Entity
@Table(name = "product")
public class Product {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String sku;

    @Column(nullable = false, unique = true)
    private String slug;

    @Column(nullable = false)
    private String name;

    @Column(columnDefinition = "text")
    private String summary;

    /** Minor units (paise/cents). Never a float: money is integral arithmetic. */
    @Column(name = "price_minor", nullable = false)
    private long priceMinor;

    @Column(nullable = false, length = 3)
    private String currency;

    /**
     * True when the product is a living organism. Livestock cannot be shipped
     * outside a safe weather window, which is what makes order state richer
     * than "paid then dispatched".
     */
    @Column(name = "is_livestock", nullable = false)
    private boolean livestock;

    /** Where the photograph lives. Null until the shop has taken one. */
    @Column(name = "image_url", length = 300)
    private String imageUrl;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "category_id")
    private Category category;

    /**
     * Care profile for livestock products. Null for equipment and dry goods.
     * Same aggregate as the product because it has no life cycle of its own.
     */
    @OneToOne(fetch = FetchType.LAZY, cascade = CascadeType.ALL, orphanRemoval = true)
    @JoinColumn(name = "species_profile_id")
    private SpeciesProfile speciesProfile;

    protected Product() { }

    public Long getId() { return id; }
    public String getSku() { return sku; }
    public String getSlug() { return slug; }
    public String getName() { return name; }
    public String getSummary() { return summary; }
    public long getPriceMinor() { return priceMinor; }
    public String getCurrency() { return currency; }
    public boolean isLivestock() { return livestock; }
    public Category getCategory() { return category; }
    public String getImageUrl() { return imageUrl; }
    public SpeciesProfile getSpeciesProfile() { return speciesProfile; }

    public BigDecimal getPriceMajor() {
        return BigDecimal.valueOf(priceMinor, 2);
    }
}
