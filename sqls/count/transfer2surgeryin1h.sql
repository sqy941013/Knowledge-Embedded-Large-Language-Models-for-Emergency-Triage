CREATE TABLE IF NOT EXISTS transfer2surgeryin1h (
    stay_id INT PRIMARY KEY
);
INSERT INTO transfer2surgeryin1h (stay_id)
SELECT DISTINCT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_hosp.transfers AS transfers
ON edstays.subject_id = transfers.subject_id 
    AND edstays.hadm_id = transfers.hadm_id
JOIN mimiciv_hosp.procedures_icd AS procedures
ON edstays.subject_id = procedures.subject_id 
    AND edstays.hadm_id = procedures.hadm_id
WHERE transfers.careunit IN (
        'Cardiac Surgery',
        'Cardiology Surgery Intermediate',
        'Medical/Surgical (Gynecology)',
        'Surgery',
        'Surgery/Pancreatic/Biliary/Bariatric',
        'Surgery/Trauma',
        'Thoracic Surgery',
        'Med/Surg',
        'Med/Surg/GYN',
        'Med/Surg/Trauma'
    )
    AND DATE(transfers.intime) BETWEEN DATE(edstays.intime) AND DATE(edstays.outtime)
    AND transfers.intime BETWEEN edstays.intime AND (edstays.intime + INTERVAL '1 hour')
    AND DATE(procedures.chartdate) BETWEEN DATE(edstays.intime) AND DATE(edstays.outtime)
ON CONFLICT (stay_id) DO NOTHING;