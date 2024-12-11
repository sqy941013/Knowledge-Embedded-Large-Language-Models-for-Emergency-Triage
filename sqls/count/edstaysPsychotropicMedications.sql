-- 检查并删除表 edstaysPsychotropicMedications 如果存在
DROP TABLE IF EXISTS edstaysPsychotropicMedications;

-- 创建新表 edstaysPsychotropicMedications
CREATE TABLE edstaysPsychotropicMedications (
    stay_id INT PRIMARY KEY
);

-- 插入符合条件的数据到 edstaysPsychotropicMedications 表中
INSERT INTO edstaysPsychotropicMedications (stay_id)
WITH PatientAge AS (
    SELECT
        e.subject_id,
        e.stay_id,
        e.intime,
        e.outtime,
        p.anchor_age + (EXTRACT(YEAR FROM e.intime) - p.anchor_year) AS age
    FROM
        mimiciv_ed.edstays e
    JOIN
        mimiciv_hosp.patients p
    ON
        e.subject_id = p.subject_id
),
FilteredMedications AS (
    SELECT
        m.subject_id,
        m.stay_id,
        m.charttime,
        m.name,
        p.age
    FROM
        mimiciv_ed.pyxis m
    JOIN
        PatientAge p
    ON
        m.subject_id = p.subject_id
        AND m.stay_id = p.stay_id
    WHERE
        (m.name ILIKE '%haloperidol%' AND m.name ILIKE '%5mg/1mL 1mL VIAL%')
        OR (m.name ILIKE '%lorazepam%' AND m.name ILIKE '%2mg/1mL 1mL SYR%')
        OR (m.name ILIKE '%olanzapine%' AND m.name ILIKE '%10mg VIAL%')
),
FinalFilteredRecords AS (
    SELECT
        f.stay_id
    FROM
        FilteredMedications f
    JOIN
        mimiciv_ed.edstays e
    ON
        f.stay_id = e.stay_id
    WHERE
        f.charttime BETWEEN e.intime AND (e.intime + INTERVAL '120 minutes')
)
SELECT DISTINCT
    stay_id
FROM
    FinalFilteredRecords
ON CONFLICT (stay_id) DO NOTHING;

-- 统计插入的数据量
SELECT COUNT(*) AS total_count FROM edstaysPsychotropicMedications;