CREATE TABLE IF NOT EXISTS Tier2MedUsage (
    stay_id INT PRIMARY KEY
);
INSERT INTO Tier2MedUsage (stay_id)
SELECT DISTINCT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_ed.pyxis AS pyxis
ON edstays.stay_id = pyxis.stay_id
WHERE (
    pyxis.name ILIKE '%nicardipine%'
    OR pyxis.name ILIKE '%sodium nitroprusside%'
    OR pyxis.name ILIKE '%esmolol%'
    OR pyxis.name ILIKE '%milrinone%'
    OR pyxis.name ILIKE 'Labetalol'
    OR pyxis.name ILIKE 'Labetalol 100mg/20mL 20mL VIAL'
    OR pyxis.name ILIKE 'Nitroglycerin'
    OR pyxis.name ILIKE 'Nitroglycerin SL'
    OR pyxis.name ILIKE 'Nitroglycerin SL 0.3mg BTL'
    OR pyxis.name ILIKE 'Nitroglycerin SL 0.4mg BTL'
    OR pyxis.name ILIKE '%dextrose 50%%'
    OR pyxis.name ILIKE '%naloxone%'
    OR pyxis.name ILIKE '%calcium gluconate%'
    OR pyxis.name ILIKE '%calcium chloride%'
    OR pyxis.name ILIKE '%sodium bicarbonate%'
)
ON CONFLICT (stay_id) DO NOTHING;