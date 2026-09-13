-- Shop floor as it stands. SKUs match catalog-service; the two services share
-- no schema and no database, only this string, which is the published contract.
--
-- Tank codes are the labels on the physical glass. An operator reading a stock
-- discrepancy alert has to be able to walk to the tank the alert names.

INSERT INTO tank (code, sku, quantity_on_hand, status, note) VALUES
    ('T-01', 'FSH-NEON-TETRA',    48, 'open',       'main display, south wall'),
    ('T-02', 'FSH-NEON-TETRA',    22, 'open',       'grow-out'),
    ('T-03', 'FSH-NEON-TETRA',    30, 'quarantine', 'ich treatment, day 3 of 10'),
    ('T-04', 'FSH-CARDINAL-TETRA', 26, 'open',      'main display'),
    ('T-05', 'FSH-CORY-PANDA',    18, 'open',       'bottom-dweller bank'),
    ('T-06', 'FSH-CORY-PANDA',     9, 'open',       'grow-out'),
    ('T-07', 'FSH-BETTA-HM',       6, 'open',       'individual jars, rack A'),
    ('T-08', 'INV-AMANO-SHRIMP',  95, 'open',       'shrimp bank'),
    ('T-09', 'INV-NERITE-SNAIL',  40, 'open',       'shrimp bank'),
    ('T-10', 'PLT-ANUBIAS-NANA',  35, 'open',       'plant trough');
