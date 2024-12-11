-- 检查并删除表 edstays_with_labevents 如果存在
DROP TABLE IF EXISTS edstays_with_labevents;

-- 创建新表 edstays_with_labevents
CREATE TABLE edstays_with_labevents (
    stay_id INT PRIMARY KEY
);

-- 插入满足条件的数据到 edstays_with_labevents 表中
INSERT INTO edstays_with_labevents (stay_id)
SELECT DISTINCT
    ed.stay_id
FROM 
    mimiciv_ed.edstays AS ed
JOIN 
    mimiciv_hosp.labevents AS le
ON 
    ed.subject_id = le.subject_id
WHERE 
    le.charttime BETWEEN ed.intime AND ed.outtime;

-- 统计插入的数据量
SELECT COUNT(*) AS total_count FROM edstays_with_labevents;

-- 更新 edstay_triage_extra 表，增加 lab_event_count 列并记录数据
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN lab_event_count INT DEFAULT 0;

-- 更新 lab_event_count 列，统计每个 stay_id 的实验室事件次数
UPDATE mimiciv_ed.edstay_triage_extra extra
SET lab_event_count = subquery.lab_count
FROM (
    SELECT
        ed.stay_id,
        COUNT(le.labevent_id) AS lab_count
    FROM 
        mimiciv_ed.edstays AS ed
    JOIN 
        mimiciv_hosp.labevents AS le
    ON 
        ed.subject_id = le.subject_id
    WHERE 
        le.charttime BETWEEN ed.intime AND ed.outtime
    GROUP BY
        ed.stay_id
) AS subquery
WHERE extra.stay_id = subquery.stay_id;

-- 统计更新的数据量
SELECT COUNT(*) AS updated_count
FROM mimiciv_ed.edstay_triage_extra
WHERE lab_event_count > 0;


-- 检查并删除表 edstays_with_microbiologyevents 如果存在
DROP TABLE IF EXISTS edstays_with_microbiologyevents;

-- 创建新表 edstays_with_microbiologyevents
CREATE TABLE edstays_with_microbiologyevents (
    stay_id INT PRIMARY KEY
);

-- 插入满足条件的数据到 edstays_with_microbiologyevents 表中
INSERT INTO edstays_with_microbiologyevents (stay_id)
SELECT DISTINCT
    ed.stay_id
FROM 
    mimiciv_ed.edstays AS ed
JOIN 
    mimiciv_hosp.microbiologyevents AS me
ON 
    ed.subject_id = me.subject_id
WHERE 
    me.charttime BETWEEN ed.intime AND ed.outtime;

-- 统计插入的数据量
SELECT COUNT(*) AS total_count FROM edstays_with_microbiologyevents;

-- 更新 edstay_triage_extra 表，增加 microbio_event_count 列并记录数据
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN microbio_event_count INT DEFAULT 0;

-- 更新 microbio_event_count 列，统计每个 stay_id 的微生物事件次数
UPDATE mimiciv_ed.edstay_triage_extra extra
SET microbio_event_count = subquery.microbio_count
FROM (
    SELECT
        ed.stay_id,
        COUNT(me.microevent_id) AS microbio_count
    FROM 
        mimiciv_ed.edstays AS ed
    JOIN 
        mimiciv_hosp.microbiologyevents AS me
    ON 
        ed.subject_id = me.subject_id
    WHERE 
        me.charttime BETWEEN ed.intime AND ed.outtime
    GROUP BY
        ed.stay_id
) AS subquery
WHERE extra.stay_id = subquery.stay_id;

-- 统计更新的数据量
SELECT COUNT(*) AS updated_count
FROM mimiciv_ed.edstay_triage_extra
WHERE microbio_event_count > 0;


-- 创建新表以存储结果
CREATE TABLE IF NOT EXISTS mimiciv_ed.edstay_exam_counts (
    stay_id INT PRIMARY KEY,
    exam_count INT
);

-- 插入统计结果到新表中
WITH ExamCounts AS (
    SELECT
        edstays.stay_id,
        COUNT(radiology.note_id) AS exam_count
    FROM
        mimiciv_note.radiology AS radiology
    JOIN
        mimiciv_ed.edstays AS edstays
    ON
        radiology.subject_id = edstays.subject_id
        AND radiology.charttime BETWEEN edstays.intime AND edstays.outtime
    GROUP BY
        edstays.stay_id
)
INSERT INTO mimiciv_ed.edstay_exam_counts (stay_id, exam_count)
SELECT 
    stay_id,
    exam_count
FROM 
    ExamCounts
ON CONFLICT (stay_id) DO NOTHING;

-- 更新 edstay_triage_extra 表，增加 exam_count 列并记录数据
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN exam_count INT DEFAULT 0;

-- 更新 exam_count 列，统计每个 stay_id 的检查次数
UPDATE mimiciv_ed.edstay_triage_extra extra
SET exam_count = subquery.exam_count
FROM (
    SELECT
        stay_id,
        exam_count
    FROM 
        mimiciv_ed.edstay_exam_counts
) AS subquery
WHERE extra.stay_id = subquery.stay_id;

-- 统计更新的数据量
SELECT COUNT(*) AS updated_count
FROM mimiciv_ed.edstay_triage_extra
WHERE exam_count > 0;


-- 创建新的表来存储统计结果
CREATE TABLE IF NOT EXISTS mimiciv_ed.stay_drug_usage (
    stay_id INTEGER PRIMARY KEY,
    intravenous_fluids INTEGER DEFAULT 0,
    intravenous INTEGER DEFAULT 0,
    intramuscular INTEGER DEFAULT 0,
    nebulized_medications INTEGER DEFAULT 0,
    oral_medications INTEGER DEFAULT 0
);

-- 插入统计结果到新的表中
WITH PyxisMedications AS (
    SELECT
        p.stay_id,
        p.name AS drug_name,
        COUNT(*) AS count
    FROM
        mimiciv_ed.pyxis p
    JOIN
        mimiciv_ed.edstays e ON p.stay_id = e.stay_id
    WHERE
        p.charttime BETWEEN e.intime AND e.outtime
    GROUP BY
        p.stay_id, p.name
),
MedicationTypes AS (
    SELECT
        pm.stay_id,
        pm.drug_name,
        pm.count,
        pam.admin_method
    FROM
        PyxisMedications pm
    JOIN
        mimiciv_ed.pyxis_admin_method pam ON pm.drug_name = pam.drug_name
),
StayDrugCounts AS (
    SELECT
        stay_id,
        SUM(CASE WHEN admin_method = 'intravenous fluids' THEN count ELSE 0 END) AS intravenous_fluids,
        SUM(CASE WHEN admin_method = 'intravenous' THEN count ELSE 0 END) AS intravenous,
        SUM(CASE WHEN admin_method = 'intramuscular' THEN count ELSE 0 END) AS intramuscular,
        SUM(CASE WHEN admin_method = 'nebulized medications' THEN count ELSE 0 END) AS nebulized_medications,
        SUM(CASE WHEN admin_method = 'oral medications' THEN count ELSE 0 END) AS oral_medications
    FROM
        MedicationTypes
    GROUP BY
        stay_id
)
INSERT INTO mimiciv_ed.stay_drug_usage (stay_id, intravenous_fluids, intravenous, intramuscular, nebulized_medications, oral_medications)
SELECT
    stay_id,
    intravenous_fluids,
    intravenous,
    intramuscular,
    nebulized_medications,
    oral_medications
FROM
    StayDrugCounts
ON CONFLICT (stay_id) DO NOTHING;

-- 更新 mimiciv_ed.edstay_triage_extra 表，增加药物使用的列并记录数据
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN intravenous_fluids INTEGER DEFAULT 0,
ADD COLUMN intravenous INTEGER DEFAULT 0,
ADD COLUMN intramuscular INTEGER DEFAULT 0,
ADD COLUMN nebulized_medications INTEGER DEFAULT 0,
ADD COLUMN oral_medications INTEGER DEFAULT 0;

-- 将药物使用数据更新到 mimiciv_ed.edstay_triage_extra 表中
UPDATE mimiciv_ed.edstay_triage_extra extra
SET 
    intravenous_fluids = COALESCE(drug_usage.intravenous_fluids, 0),
    intravenous = COALESCE(drug_usage.intravenous, 0),
    intramuscular = COALESCE(drug_usage.intramuscular, 0),
    nebulized_medications = COALESCE(drug_usage.nebulized_medications, 0),
    oral_medications = COALESCE(drug_usage.oral_medications, 0)
FROM mimiciv_ed.stay_drug_usage drug_usage
WHERE extra.stay_id = drug_usage.stay_id;

-- 统计更新的数据量
SELECT COUNT(*) AS updated_count
FROM mimiciv_ed.edstay_triage_extra
WHERE 
    intravenous_fluids > 0 OR
    intravenous > 0 OR
    intramuscular > 0 OR
    nebulized_medications > 0 OR
    oral_medications > 0;


-- 删除表 mimiciv_ed.edstays_consults_count 如果存在
DROP TABLE IF EXISTS mimiciv_ed.edstays_consults_count;

-- 创建新表并保存edstay对应的consult次数
CREATE TABLE mimiciv_ed.edstays_consults_count AS
WITH stay_periods AS (
    SELECT
        stay_id,
        subject_id,
        intime,
        outtime
    FROM
        mimiciv_ed.edstays
),
consults_in_period AS (
    SELECT
        e.stay_id,
        COUNT(p.poe_id) AS consults_count
    FROM
        stay_periods e
    JOIN
        mimiciv_hosp.poe p
    ON
        e.subject_id = p.subject_id
        AND p.order_type = 'Consults'
        AND p.ordertime BETWEEN e.intime AND e.outtime
    GROUP BY
        e.stay_id
),
filtered_consults AS (
    SELECT
        e.stay_id,
        e.subject_id,
        e.intime,
        e.outtime,
        COALESCE(c.consults_count, 0) AS consults_count
    FROM
        stay_periods e
    LEFT JOIN
        consults_in_period c
    ON
        e.stay_id = c.stay_id
)
SELECT
    stay_id,
    subject_id,
    intime,
    outtime,
    consults_count
FROM
    filtered_consults;

-- 在 mimiciv_ed.edstay_triage_extra 表中增加专科会诊次数列
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN consults_count INT DEFAULT 0;

-- 更新 mimiciv_ed.edstay_triage_extra 表，记录每个stay_id的专科会诊次数
UPDATE mimiciv_ed.edstay_triage_extra extra
SET consults_count = COALESCE(consults.consults_count, 0)
FROM mimiciv_ed.edstays_consults_count consults
WHERE extra.stay_id = consults.stay_id;

-- 统计更新的数据量
SELECT COUNT(*) AS updated_count
FROM mimiciv_ed.edstay_triage_extra
WHERE consults_count > 0;


-- 删除表 mimiciv_ed.stay_procedures 如果存在
DROP TABLE IF EXISTS mimiciv_ed.stay_procedures;

-- 创建表并保存edstay对应的手术信息
CREATE TABLE mimiciv_ed.stay_procedures AS
WITH stay_periods AS (
    SELECT
        stay_id,
        subject_id,
        intime,
        outtime
    FROM
        mimiciv_ed.edstays
),
procedures_in_period AS (
    SELECT
        e.stay_id,
        p.icd_code AS procedures_icd,
        p.icd_version
    FROM
        stay_periods e
    JOIN
        mimiciv_hosp.procedures_icd p
    ON
        e.subject_id = p.subject_id
        AND DATE(p.chartdate) BETWEEN DATE(e.intime) AND DATE(e.outtime + INTERVAL '1 day')
)
SELECT
    p.stay_id,
    e.subject_id,
    e.intime,
    e.outtime,
    p.procedures_icd,
    p.icd_version
FROM
    stay_periods e
JOIN
    procedures_in_period p
ON
    e.stay_id = p.stay_id;

-- 删除 mimiciv_ed.edstay_triage_extra 表中的 procedure_count 列如果存在
ALTER TABLE mimiciv_ed.edstay_triage_extra
DROP COLUMN IF EXISTS procedure_count;

-- 更新 mimiciv_ed.edstay_triage_extra 表，增加 procedure_count 列并记录数据
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN procedure_count INT DEFAULT 0;

UPDATE mimiciv_ed.edstay_triage_extra extra
SET procedure_count = (
    SELECT COUNT(*)
    FROM mimiciv_ed.stay_procedures sp
    WHERE extra.stay_id = sp.stay_id
);

-- 统计 mimiciv_ed.edstay_triage_extra 表中 procedure_count 列的数据量
SELECT COUNT(*) AS total_count FROM mimiciv_ed.edstay_triage_extra
WHERE procedure_count > 0;


