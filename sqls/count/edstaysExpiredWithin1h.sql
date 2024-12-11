CREATE TABLE IF NOT EXISTS edstaysExpiredWithin1h (
    stay_id INT PRIMARY KEY
);
INSERT INTO edstaysExpiredWithin1h (stay_id)
SELECT DISTINCT stay_id
FROM mimiciv_ed.edstays
WHERE disposition = 'EXPIRED'
    AND outtime <= (intime + INTERVAL '1 hour')
ON CONFLICT (stay_id) DO NOTHING;