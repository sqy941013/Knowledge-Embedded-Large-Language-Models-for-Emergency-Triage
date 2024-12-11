CREATE TABLE IF NOT EXISTS NonInvasiveVentilation (
    stay_id INT PRIMARY KEY
);
INSERT INTO NonInvasiveVentilation (stay_id)
SELECT DISTINCT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_hosp.poe AS poe
ON edstays.subject_id = poe.subject_id
WHERE poe.order_subtype IN ('BiPAP', 'CPAP for OSA')
ON CONFLICT (stay_id) DO NOTHING;