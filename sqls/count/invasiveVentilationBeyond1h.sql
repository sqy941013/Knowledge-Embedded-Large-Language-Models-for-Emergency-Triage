CREATE TABLE IF NOT EXISTS InvasiveVentilationBeyond1HDerived (
    stay_id INT PRIMARY KEY
);
INSERT INTO InvasiveVentilationBeyond1HDerived (stay_id)
SELECT DISTINCT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_hosp.poe AS poe
ON edstays.subject_id = poe.subject_id
WHERE poe.order_subtype = 'Mechanical Ventilation'
AND poe.ordertime BETWEEN (edstays.intime + INTERVAL '1 hour') AND edstays.outtime
ON CONFLICT (stay_id) DO NOTHING;