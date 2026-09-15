package com.aquashop.catalog.domain;

import jakarta.persistence.*;

@Entity
@Table(name = "category")
public class Category {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String slug;

    @Column(nullable = false)
    private String name;

    @Column(columnDefinition = "text")
    private String description;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    /**
     * The tree.
     *
     * <p>Lazy and one-directional: a category knows its parent, not its
     * children. A bidirectional mapping would make every category load drag a
     * collection behind it, and the child list is always wanted with counts
     * attached -- which is a query, not a mapping.
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_id")
    private Category parent;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private CategoryStatus status = CategoryStatus.ACTIVE;

    /** One line under the name in a grid. `description` is the page paragraph. */
    @Column(length = 200)
    private String teaser;

    @Column(name = "image_url", length = 300)
    private String imageUrl;

    protected Category() { }

    public Long getId() { return id; }
    public String getSlug() { return slug; }
    public String getName() { return name; }
    public String getDescription() { return description; }
    public int getSortOrder() { return sortOrder; }
    public Category getParent() { return parent; }
    public CategoryStatus getStatus() { return status; }
    public String getTeaser() { return teaser; }
    public String getImageUrl() { return imageUrl; }
}
