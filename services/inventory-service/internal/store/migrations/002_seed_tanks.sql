-- Shop floor as it stands.
--
-- The SKUs are catalog-service's, verified against its seed data: FSH-NEO-01
-- is a Neon Tetra in both services. That string is the entire contract between
-- them -- no shared schema, no shared database, no foreign key. If it drifts,
-- the storefront shows a product that cannot be reserved and nothing in either
-- database will say why, which is the cost of the boundary and the reason the
-- SKU is worth checking rather than assuming.
--
-- Tank codes are the labels on the physical glass. An operator reading a stock
-- discrepancy alert has to be able to walk to the tank the alert names.

INSERT INTO tank (code, sku, quantity_on_hand, status, note) VALUES
    ('T-01', 'FSH-NEO-01', 48, 'open',       'neon tetra, main display, south wall'),
    ('T-02', 'FSH-NEO-01', 22, 'open',       'neon tetra, grow-out'),
    ('T-03', 'FSH-NEO-01', 30, 'quarantine', 'neon tetra, ich treatment, day 3 of 10'),
    ('T-04', 'FSH-CAR-01', 26, 'open',       'cardinal tetra, main display'),
    ('T-05', 'FSH-COR-01', 18, 'open',       'panda cory, bottom-dweller bank'),
    ('T-06', 'FSH-COR-01',  9, 'open',       'panda cory, grow-out'),
    ('T-07', 'FSH-BET-01',  6, 'open',       'betta, individual jars, rack A'),
    ('T-08', 'INV-AMA-01', 95, 'open',       'amano shrimp, shrimp bank'),
    ('T-09', 'INV-CHE-01', 40, 'open',       'cherry shrimp, shrimp bank'),
    ('T-10', 'PLT-ANU-01', 35, 'open',       'anubias nana petite, plant trough');
