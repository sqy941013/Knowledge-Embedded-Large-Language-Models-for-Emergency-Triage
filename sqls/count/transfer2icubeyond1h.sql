CREATE TABLE IF NOT EXISTS transfer2ICUbeyond1h (
    stay_id INT PRIMARY KEY
);
INSERT INTO transfer2ICUbeyond1h (stay_id)
SELECT DISTINCT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_hosp.transfers AS transfers
ON edstays.subject_id = transfers.subject_id 
    AND edstays.hadm_id = transfers.hadm_id
WHERE transfers.careunit IN (
        'Cardiac Vascular Intensive Care Unit (CVICU)',
        'Coronary Care Unit (CCU)',
        'Medical Intensive Care Unit (MICU)',
        'Medical/Surgical Intensive Care Unit (MICU/SICU)',
        'Neuro Intermediate',
        'Neuro Stepdown',
        'Neuro Surgical Intensive Care Unit (Neuro SICU)',
        'Surgical Intensive Care Unit (SICU)',
        'Trauma SICU (TSICU)'
    )
    AND DATE(transfers.intime) BETWEEN DATE(edstays.intime) AND DATE(edstays.outtime)
    AND transfers.intime > (edstays.intime + INTERVAL '1 hour')
ON CONFLICT (stay_id) DO NOTHING;