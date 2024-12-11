CREATE TABLE IF NOT EXISTS edstaysTransfusionWithin1h (
    stay_id INT PRIMARY KEY
);
INSERT INTO edstaysTransfusionWithin1h (stay_id)
SELECT DISTINCT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_hosp.poe AS poe
ON edstays.subject_id = poe.subject_id
WHERE poe.order_subtype IN (
        'Frozen Plasma Product Order',
        'Platelet Product Order',
        'Red Cell Product Order'
    )
    AND poe.ordertime BETWEEN edstays.intime AND (edstays.intime + INTERVAL '1 hour')
ON CONFLICT (stay_id) DO NOTHING;