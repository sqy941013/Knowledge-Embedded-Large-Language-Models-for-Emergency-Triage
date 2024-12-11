CREATE TABLE IF NOT EXISTS edstaysTransferBeyond1h (
    stay_id INT PRIMARY KEY
);
INSERT INTO edstaysTransferBeyond1h (stay_id)
SELECT DISTINCT stay_id
FROM mimiciv_ed.edstays
WHERE disposition = 'TRANSFER'
    AND outtime > (intime + INTERVAL '1 hour')
ON CONFLICT (stay_id) DO NOTHING;