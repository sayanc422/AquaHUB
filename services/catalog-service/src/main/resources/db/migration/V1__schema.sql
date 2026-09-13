-- catalog-service owns this schema. No other service connects to this database.
-- The role used here has CONNECT on `catalog` only; see platform-repo postgres init.

CREATE TABLE category (
    id          BIGSERIAL PRIMARY KEY,
    slug        VARCHAR(64)  NOT NULL UNIQUE,
    name        VARCHAR(128) NOT NULL,
    description TEXT,
    sort_order  INT          NOT NULL DEFAULT 0
);

CREATE TABLE species_profile (
    id              BIGSERIAL PRIMARY KEY,
    scientific_name VARCHAR(128) NOT NULL,
    common_name     VARCHAR(128) NOT NULL,
    max_size_cm     NUMERIC(5,2) NOT NULL,
    min_tank_litres INT          NOT NULL,
    min_group_size  INT          NOT NULL,
    temp_min_c      NUMERIC(4,1) NOT NULL,
    temp_max_c      NUMERIC(4,1) NOT NULL,
    ph_min          NUMERIC(3,1) NOT NULL,
    ph_max          NUMERIC(3,1) NOT NULL,
    dgh_min         NUMERIC(4,1) NOT NULL,
    dgh_max         NUMERIC(4,1) NOT NULL,
    temperament     VARCHAR(16)  NOT NULL,
    care_level      VARCHAR(16)  NOT NULL,
    diet            VARCHAR(32)  NOT NULL,
    plant_safe      BOOLEAN      NOT NULL,
    care_notes      TEXT,
    CONSTRAINT species_temp_range CHECK (temp_max_c >= temp_min_c),
    CONSTRAINT species_ph_range   CHECK (ph_max   >= ph_min),
    CONSTRAINT species_dgh_range  CHECK (dgh_max  >= dgh_min)
);

CREATE TABLE product (
    id                 BIGSERIAL PRIMARY KEY,
    sku                VARCHAR(32)  NOT NULL UNIQUE,
    slug               VARCHAR(96)  NOT NULL UNIQUE,
    name               VARCHAR(160) NOT NULL,
    summary            TEXT,
    price_minor        BIGINT       NOT NULL CHECK (price_minor >= 0),
    currency           CHAR(3)      NOT NULL,
    is_livestock       BOOLEAN      NOT NULL DEFAULT FALSE,
    category_id        BIGINT       NOT NULL REFERENCES category(id),
    species_profile_id BIGINT       REFERENCES species_profile(id),
    -- a living product without a care profile is a data defect, not a valid row
    CONSTRAINT livestock_has_profile
        CHECK (is_livestock = FALSE OR species_profile_id IS NOT NULL)
);

CREATE INDEX idx_product_category ON product(category_id);
CREATE INDEX idx_product_name_lower ON product(lower(name));
