CREATE TABLE InvasiveVentilation (
    stay_id INT PRIMARY KEY
);
INSERT INTO InvasiveVentilation (stay_id)
SELECT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_hosp.poe AS poe
ON edstays.subject_id = poe.subject_id
WHERE poe.order_subtype = 'Mechanical Ventilation'
AND poe.ordertime BETWEEN edstays.intime AND (edstays.intime + INTERVAL '1 hour');