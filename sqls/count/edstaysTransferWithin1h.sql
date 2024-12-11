CREATE TABLE IF NOT EXISTS edstaysTransferWithin1h (
    stay_id INT PRIMARY KEY
);
INSERT INTO edstaysTransferWithin1h (stay_id)
SELECT DISTINCT stay_id
FROM mimiciv_ed.edstays
WHERE disposition = 'TRANSFER'
    AND outtime BETWEEN intime AND (intime + INTERVAL '1 hour')
ON CONFLICT (stay_id) DO NOTHING;