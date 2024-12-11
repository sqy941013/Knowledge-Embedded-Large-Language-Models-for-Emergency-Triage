-- 创建新的表 edstay_triage_extra，并将 edstays 和 triage 的内容合并到这个表中
CREATE TABLE mimiciv_ed.edstay_triage_extra AS
SELECT
    e.subject_id,
    e.stay_id,
    e.hadm_id,
    e.intime,
    e.outtime,
    e.gender,
    e.race,
    e.arrival_transport,
    e.disposition,
    t.temperature,
    t.heartrate,
    t.resprate,
    t.o2sat,
    t.sbp,
    t.dbp,
    t.pain,
    t.acuity,
    t.chiefcomplaint
FROM
    mimiciv_ed.edstays e
LEFT JOIN
    mimiciv_ed.triage t
ON
    e.subject_id = t.subject_id
    AND e.stay_id = t.stay_id;

    -- 删除已经存在的临时表&#xff08;如果存在&#xff09;
DROP TABLE IF EXISTS InvasiveVentilation_New;

-- 创建一个新的临时表来存储1小时内侵入通气的stay_id
CREATE TEMPORARY TABLE InvasiveVentilation_New (
    stay_id INT PRIMARY KEY
);

-- 插入符合条件的stay_id到新的临时表中，使用DISTINCT去重
INSERT INTO InvasiveVentilation_New (stay_id)
SELECT DISTINCT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_hosp.poe AS poe
ON edstays.subject_id = poe.subject_id
WHERE poe.order_subtype = 'Mechanical Ventilation'
AND poe.ordertime BETWEEN edstays.intime AND (edstays.intime + INTERVAL '1 hour');

-- 在mimiciv_ed.edstay_triage_extra表中增加一个新列invasive_ventilation
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN invasive_ventilation INT DEFAULT 0;

-- 更新mimiciv_ed.edstay_triage_extra表中的invasive_ventilation列
UPDATE mimiciv_ed.edstay_triage_extra AS et
SET invasive_ventilation = 1
FROM InvasiveVentilation_New iv
WHERE et.stay_id = iv.stay_id;

-- 删除已经存在的临时表&#xff08;如果存在&#xff09;
DROP TABLE IF EXISTS InvasiveVentilationBeyond1HDerived;

-- 创建一个新的临时表来存储1小时外侵入通气的stay_id
CREATE TEMPORARY TABLE InvasiveVentilationBeyond1HDerived (
    stay_id INT PRIMARY KEY
);

-- 插入符合条件的stay_id到新的临时表中，使用DISTINCT去重
INSERT INTO InvasiveVentilationBeyond1HDerived (stay_id)
SELECT DISTINCT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_hosp.poe AS poe
ON edstays.subject_id = poe.subject_id
WHERE poe.order_subtype = 'Mechanical Ventilation'
AND poe.ordertime BETWEEN (edstays.intime + INTERVAL '1 hour') AND edstays.outtime;

-- 在mimiciv_ed.edstay_triage_extra表中增加一个新列invasive_ventilation_beyond_1h
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN invasive_ventilation_beyond_1h INT DEFAULT 0;

-- 更新mimiciv_ed.edstay_triage_extra表中的invasive_ventilation_beyond_1h列
UPDATE mimiciv_ed.edstay_triage_extra AS et
SET invasive_ventilation_beyond_1h = 1
FROM InvasiveVentilationBeyond1HDerived iv
WHERE et.stay_id = iv.stay_id;

-- 如果临时表存在则清空临时表
DROP TABLE IF EXISTS NonInvasiveVentilation;

-- 创建一个新的临时表来存储1小时内无创通气的stay_id
CREATE TEMPORARY TABLE NonInvasiveVentilation (
    stay_id INT PRIMARY KEY
);

-- 插入符合条件的stay_id到NonInvasiveVentilation表中
INSERT INTO NonInvasiveVentilation (stay_id)
SELECT DISTINCT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_hosp.poe AS poe
ON edstays.subject_id = poe.subject_id
WHERE poe.order_subtype IN ('BiPAP', 'CPAP for OSA')
AND poe.ordertime BETWEEN edstays.intime AND edstays.outtime;

-- 在mimiciv_ed.edstay_triage_extra表中添加non_invasive_ventilation列&#xff08;如果不存在&#xff09;
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN IF NOT EXISTS non_invasive_ventilation INT DEFAULT 0;

-- 更新mimiciv_ed.edstay_triage_extra表中的non_invasive_ventilation列
UPDATE mimiciv_ed.edstay_triage_extra AS triage
SET non_invasive_ventilation = 1
FROM NonInvasiveVentilation AS niv
WHERE triage.stay_id = niv.stay_id;

-- 如果临时表存在则清空临时表
DROP TABLE IF EXISTS transfer2surgeryin1h;

-- 创建一个新的临时表来存储1小时内从入院到手术室的stay_id
CREATE TEMPORARY TABLE transfer2surgeryin1h (
    stay_id INT PRIMARY KEY
);

-- 插入符合条件的stay_id到transfer2surgeryin1h表中
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

-- 在mimiciv_ed.edstay_triage_extra表中添加transfer2surgeryin1h列&#xff08;如果不存在&#xff09;
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN IF NOT EXISTS transfer2surgeryin1h INT DEFAULT 0;

-- 更新mimiciv_ed.edstay_triage_extra表中的transfer2surgeryin1h列
UPDATE mimiciv_ed.edstay_triage_extra AS triage
SET transfer2surgeryin1h = 1
FROM transfer2surgeryin1h AS ts
WHERE triage.stay_id = ts.stay_id;

-- 删除临时表如果已经存在
DROP TABLE IF EXISTS transfer2surgerybeyond1h;

-- 创建临时表用于存储1小时外从入院到手术室的stay_id
CREATE TEMPORARY TABLE transfer2surgerybeyond1h (
    stay_id INT PRIMARY KEY
);

-- 插入符合条件的stay_id到临时表中
INSERT INTO transfer2surgerybeyond1h (stay_id)
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
    AND transfers.intime > (edstays.intime + INTERVAL '1 hour')
    AND procedures.chartdate BETWEEN edstays.intime AND edstays.outtime;

-- 在mimiciv_ed.edstay_triage_extra表中添加transfer_to_surgery_beyond_1h列&#xff08;如果不存在&#xff09;
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN IF NOT EXISTS transfer_to_surgery_beyond_1h INT DEFAULT 0;

-- 更新mimiciv_ed.edstay_triage_extra表中的transfer_to_surgery_beyond_1h列
UPDATE mimiciv_ed.edstay_triage_extra AS triage
SET transfer_to_surgery_beyond_1h = 1
FROM transfer2surgerybeyond1h AS t
WHERE triage.stay_id = t.stay_id;

-- 删除临时表如果已经存在
DROP TABLE IF EXISTS transfer2ICUbeyond1h;

-- 创建临时表用于存储1小时外从入院到ICU的stay_id
CREATE TEMPORARY TABLE transfer2ICUbeyond1h (
    stay_id INT PRIMARY KEY
);

-- 插入符合条件的stay_id到临时表中
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
    AND transfers.intime BETWEEN edstays.intime AND edstays.outtime
    AND transfers.intime > (edstays.intime + INTERVAL '1 hour');

-- 在mimiciv_ed.edstay_triage_extra表中添加transfer_to_ICU_beyond_1h列&#xff08;如果不存在&#xff09;
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN IF NOT EXISTS transfer_to_ICU_beyond_1h INT DEFAULT 0;

-- 更新mimiciv_ed.edstay_triage_extra表中的transfer_to_ICU_beyond_1h列
UPDATE mimiciv_ed.edstay_triage_extra AS triage
SET transfer_to_ICU_beyond_1h = 1
FROM transfer2ICUbeyond1h AS t
WHERE triage.stay_id = t.stay_id;

-- 删除临时表如果已经存在
DROP TABLE IF EXISTS edstaysTransferWithin1h;

-- 创建临时表用于存储1小时内转院的stay_id
CREATE TEMPORARY TABLE edstaysTransferWithin1h (
    stay_id INT PRIMARY KEY
);

-- 插入符合条件的stay_id到临时表中
INSERT INTO edstaysTransferWithin1h (stay_id)
SELECT DISTINCT stay_id
FROM mimiciv_ed.edstays
WHERE disposition = 'TRANSFER'
    AND outtime BETWEEN intime AND (intime + INTERVAL '1 hour');

-- 在mimiciv_ed.edstay_triage_extra表中添加transfer_within_1h列&#xff08;如果不存在&#xff09;
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN IF NOT EXISTS transfer_within_1h INT DEFAULT 0;

-- 更新mimiciv_ed.edstay_triage_extra表中的transfer_within_1h列
UPDATE mimiciv_ed.edstay_triage_extra AS triage
SET transfer_within_1h = 1
FROM edstaysTransferWithin1h AS t
WHERE triage.stay_id = t.stay_id;

-- 删除临时表如果已经存在
DROP TABLE IF EXISTS edstaysTransferBeyond1h;

-- 创建临时表用于存储1小时外转院的stay_id
CREATE TEMPORARY TABLE edstaysTransferBeyond1h (
    stay_id INT PRIMARY KEY
);

-- 插入符合条件的stay_id到临时表中
INSERT INTO edstaysTransferBeyond1h (stay_id)
SELECT DISTINCT stay_id
FROM mimiciv_ed.edstays
WHERE disposition = 'TRANSFER'
    AND outtime > (intime + INTERVAL '1 hour');

-- 在mimiciv_ed.edstay_triage_extra表中添加transfer_beyond_1h列&#xff08;如果不存在&#xff09;
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN IF NOT EXISTS transfer_beyond_1h INT DEFAULT 0;

-- 更新mimiciv_ed.edstay_triage_extra表中的transfer_beyond_1h列
UPDATE mimiciv_ed.edstay_triage_extra AS triage
SET transfer_beyond_1h = 1
FROM edstaysTransferBeyond1h AS t
WHERE triage.stay_id = t.stay_id;

-- 删除临时表如果已经存在
DROP TABLE IF EXISTS edstaysExpiredWithin1h;

-- 创建临时表用于存储1小时内死亡的stay_id
CREATE TEMPORARY TABLE edstaysExpiredWithin1h (
    stay_id INT PRIMARY KEY
);

-- 插入符合条件的stay_id到临时表中
INSERT INTO edstaysExpiredWithin1h (stay_id)
SELECT DISTINCT stay_id
FROM mimiciv_ed.edstays
WHERE disposition = 'EXPIRED'
    AND outtime <= (intime + INTERVAL '1 hour');

-- 在mimiciv_ed.edstay_triage_extra表中添加expired_within_1h列&#xff08;如果不存在&#xff09;
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN IF NOT EXISTS expired_within_1h INT DEFAULT 0;

-- 更新mimiciv_ed.edstay_triage_extra表中的expired_within_1h列
UPDATE mimiciv_ed.edstay_triage_extra AS triage
SET expired_within_1h = 1
FROM edstaysExpiredWithin1h AS t
WHERE triage.stay_id = t.stay_id;

-- 删除临时表如果已经存在
DROP TABLE IF EXISTS edstaysExpiredBeyond1h;

-- 创建临时表用于存储1小时外死亡的stay_id
CREATE TEMPORARY TABLE edstaysExpiredBeyond1h (
    stay_id INT PRIMARY KEY
);

-- 插入符合条件的stay_id到临时表中
INSERT INTO edstaysExpiredBeyond1h (stay_id)
SELECT DISTINCT stay_id
FROM mimiciv_ed.edstays
WHERE disposition = 'EXPIRED'
    AND outtime > (intime + INTERVAL '1 hour');

-- 在mimiciv_ed.edstay_triage_extra表中添加expired_beyond_1h列&#xff08;如果不存在&#xff09;
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN IF NOT EXISTS expired_beyond_1h INT DEFAULT 0;

-- 更新mimiciv_ed.edstay_triage_extra表中的expired_beyond_1h列
UPDATE mimiciv_ed.edstay_triage_extra AS triage
SET expired_beyond_1h = 1
FROM edstaysExpiredBeyond1h AS t
WHERE triage.stay_id = t.stay_id;

-- 删除临时表如果已经存在
DROP TABLE IF EXISTS Tier1MedUsage1H;

-- 创建临时表用于存储1小时内使用一类药物的stay_id
CREATE TEMPORARY TABLE Tier1MedUsage1H (
    stay_id INT PRIMARY KEY
);

-- 插入符合条件的stay_id到临时表中
INSERT INTO Tier1MedUsage1H (stay_id)
SELECT DISTINCT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_ed.pyxis AS pyxis
ON edstays.stay_id = pyxis.stay_id
WHERE (pyxis.charttime BETWEEN edstays.intime AND (edstays.intime + INTERVAL '1 hour'))
AND (
    pyxis.name ILIKE '%epinephrine%'       -- 包括所有epinephrine的变体
    OR pyxis.name ILIKE '%norepinephrine%' -- 包括所有norepinephrine的变体
    OR pyxis.name ILIKE '%vasopressin%'    -- 包括所有vasopressin的变体
    OR pyxis.name ILIKE '%dopamine%'       -- 包括所有dopamine的变体
    OR pyxis.name ILIKE '%dobutamine%'     -- 包括所有dobutamine的变体
    OR pyxis.name ILIKE '%phenylephrine%'  -- 包括所有phenylephrine的变体
    OR pyxis.name ILIKE '%isoproterenol%'  -- 包括所有isoproterenol的变体
    OR pyxis.name ILIKE '%atropine%'       -- 包括所有atropine的变体
    OR pyxis.name ILIKE '%tenecteplase%'   -- 包括所有tenecteplase的变体
    OR pyxis.name ILIKE '%alteplase%'      -- 包括所有alteplase的变体
)
ON CONFLICT (stay_id) DO NOTHING;

-- 在mimiciv_ed.edstay_triage_extra表中添加tier1_med_usage_1h列&#xff08;如果不存在&#xff09;
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN IF NOT EXISTS tier1_med_usage_1h INT DEFAULT 0;

-- 更新mimiciv_ed.edstay_triage_extra表中的tier1_med_usage_1h列
UPDATE mimiciv_ed.edstay_triage_extra AS triage
SET tier1_med_usage_1h = 1
FROM Tier1MedUsage1H AS t
WHERE triage.stay_id = t.stay_id;

-- 删除临时表如果已经存在
DROP TABLE IF EXISTS Tier1MedUsageBeyond1H;

-- 创建临时表用于存储1小时外使用一类药物的stay_id
CREATE TEMPORARY TABLE Tier1MedUsageBeyond1H (
    stay_id INT PRIMARY KEY
);

-- 插入符合条件的stay_id到临时表中
INSERT INTO Tier1MedUsageBeyond1H (stay_id)
SELECT DISTINCT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_ed.pyxis AS pyxis
ON edstays.stay_id = pyxis.stay_id
WHERE pyxis.charttime BETWEEN (edstays.intime + INTERVAL '1 hour') AND edstays.outtime
AND (
    pyxis.name ILIKE '%epinephrine%'       -- 包括所有epinephrine的变体
    OR pyxis.name ILIKE '%norepinephrine%' -- 包括所有norepinephrine的变体
    OR pyxis.name ILIKE '%vasopressin%'    -- 包括所有vasopressin的变体
    OR pyxis.name ILIKE '%dopamine%'       -- 包括所有dopamine的变体
    OR pyxis.name ILIKE '%dobutamine%'     -- 包括所有dobutamine的变体
    OR pyxis.name ILIKE '%phenylephrine%'  -- 包括所有phenylephrine的变体
    OR pyxis.name ILIKE '%isoproterenol%'  -- 包括所有isoproterenol的变体
    OR pyxis.name ILIKE '%atropine%'       -- 包括所有atropine的变体
    OR pyxis.name ILIKE '%tenecteplase%'   -- 包括所有tenecteplase的变体
    OR pyxis.name ILIKE '%alteplase%'      -- 包括所有alteplase的变体
)
ON CONFLICT (stay_id) DO NOTHING;

-- 在mimiciv_ed.edstay_triage_extra表中添加tier1_med_usage_beyond_1h列&#xff08;如果不存在&#xff09;
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN IF NOT EXISTS tier1_med_usage_beyond_1h INT DEFAULT 0;

-- 更新mimiciv_ed.edstay_triage_extra表中的tier1_med_usage_beyond_1h列
UPDATE mimiciv_ed.edstay_triage_extra AS triage
SET tier1_med_usage_beyond_1h = 1
FROM Tier1MedUsageBeyond1H AS t
WHERE triage.stay_id = t.stay_id;

-- 删除临时表如果已经存在
DROP TABLE IF EXISTS Tier2MedUsage;

-- 创建临时表用于存储使用二类药物的stay_id
CREATE TEMPORARY TABLE Tier2MedUsage (
    stay_id INT PRIMARY KEY
);

-- 插入符合条件的stay_id到临时表中
INSERT INTO Tier2MedUsage (stay_id)
SELECT DISTINCT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_ed.pyxis AS pyxis
ON edstays.stay_id = pyxis.stay_id
WHERE (
    pyxis.name ILIKE '%nicardipine%'
    OR pyxis.name ILIKE '%sodium nitroprusside%'
    OR pyxis.name ILIKE '%esmolol%'
    OR pyxis.name ILIKE '%milrinone%'
    OR pyxis.name ILIKE 'Labetalol'
    OR pyxis.name ILIKE 'Labetalol 100mg/20mL 20mL VIAL'
    OR pyxis.name ILIKE 'Nitroglycerin'
    OR pyxis.name ILIKE 'Nitroglycerin SL'
    OR pyxis.name ILIKE 'Nitroglycerin SL 0.3mg BTL'
    OR pyxis.name ILIKE 'Nitroglycerin SL 0.4mg BTL'
    OR pyxis.name ILIKE '%dextrose 50%%'
    OR pyxis.name ILIKE '%naloxone%'
    OR pyxis.name ILIKE '%calcium gluconate%'
    OR pyxis.name ILIKE '%calcium chloride%'
    OR pyxis.name ILIKE '%sodium bicarbonate%'
)
ON CONFLICT (stay_id) DO NOTHING;

-- 在mimiciv_ed.edstay_triage_extra表中添加tier2_med_usage列&#xff08;如果不存在&#xff09;
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN IF NOT EXISTS tier2_med_usage INT DEFAULT 0;

-- 更新mimiciv_ed.edstay_triage_extra表中的tier2_med_usage列
UPDATE mimiciv_ed.edstay_triage_extra AS triage
SET tier2_med_usage = 1
FROM Tier2MedUsage AS t
WHERE triage.stay_id = t.stay_id;

-- 删除临时表如果已经存在
DROP TABLE IF EXISTS Tier3MedUsage;

-- 创建临时表用于存储使用三类药物的stay_id
CREATE TEMPORARY TABLE Tier3MedUsage (
    stay_id INT PRIMARY KEY
);

-- 插入符合条件的stay_id到临时表中
INSERT INTO Tier3MedUsage (stay_id)
SELECT DISTINCT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_ed.pyxis AS pyxis
ON edstays.stay_id = pyxis.stay_id
WHERE (
    pyxis.name ILIKE '%procainamide%'     -- 包括所有形式的普鲁卡因胺
    OR pyxis.name ILIKE '%amiodarone%'    -- 包括所有形式的胺碘酮
    OR pyxis.name ILIKE '%ibutilide%'     -- 包括所有形式的伊布利特
    OR pyxis.name ILIKE '%heparin%'       -- 包括所有形式的肝素
    OR pyxis.name ILIKE '%insulin%'       -- 包括所有形式的胰岛素
    OR pyxis.name ILIKE '%albuterol%'     -- 包括所有形式的连续使用沙丁胺醇
)
ON CONFLICT (stay_id) DO NOTHING;

-- 在mimiciv_ed.edstay_triage_extra表中添加tier3_med_usage列&#xff08;如果不存在&#xff09;
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN IF NOT EXISTS tier3_med_usage INT DEFAULT 0;

-- 更新mimiciv_ed.edstay_triage_extra表中的tier3_med_usage列
UPDATE mimiciv_ed.edstay_triage_extra AS triage
SET tier3_med_usage = 1
FROM Tier3MedUsage AS t
WHERE triage.stay_id = t.stay_id;

-- 删除临时表如果已经存在
DROP TABLE IF EXISTS Tier4MedUsage;

-- 创建临时表用于存储使用四类药物的stay_id
CREATE TEMPORARY TABLE Tier4MedUsage (
    stay_id INT PRIMARY KEY
);

-- 插入符合条件的stay_id到临时表中
INSERT INTO Tier4MedUsage (stay_id)
SELECT DISTINCT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_ed.pyxis AS pyxis
ON edstays.stay_id = pyxis.stay_id
WHERE (
    pyxis.name ILIKE '%etomidate%'     -- 包括所有形式的艾托美酯
    OR pyxis.name ILIKE '%ketamine%'   -- 包括所有形式的氯胺酮
    OR pyxis.name ILIKE '%propofol%'   -- 包括所有形式的丙泊酚
    OR pyxis.name ILIKE '%metoprolol%' -- 包括所有形式的美托洛尔
    OR pyxis.name ILIKE '%diltiazem%'  -- 包括所有形式的地尔硫卓
    OR pyxis.name ILIKE '%adenosine%'  -- 包括所有形式的腺苷
    OR pyxis.name ILIKE '%digoxin%'    -- 包括所有形式的地高辛
    OR pyxis.name ILIKE '%hydralazine%'-- 包括所有形式的肼屈嗪
    OR pyxis.name ILIKE '%labetalol%'  -- 包括所有形式的拉贝洛尔
    OR pyxis.name ILIKE '%nitroglycerin%' -- 包括所有形式的舌下或经皮硝酸甘油
)
ON CONFLICT (stay_id) DO NOTHING;

-- 在mimiciv_ed.edstay_triage_extra表中添加tier4_med_usage列&#xff08;如果不存在&#xff09;
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN IF NOT EXISTS tier4_med_usage INT DEFAULT 0;

-- 更新mimiciv_ed.edstay_triage_extra表中的tier4_med_usage列
UPDATE mimiciv_ed.edstay_triage_extra AS triage
SET tier4_med_usage = 1
FROM Tier4MedUsage AS t
WHERE triage.stay_id = t.stay_id;

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

-- 更新 edstay_triage_extra 表，增加 psychotropic_med_within_120min 列并记录数据
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN psychotropic_med_within_120min INT DEFAULT 0;

UPDATE mimiciv_ed.edstay_triage_extra extra
SET psychotropic_med_within_120min = 1
FROM edstaysPsychotropicMedications meds
WHERE extra.stay_id = meds.stay_id;

-- 检查并删除表 edstaysTransfusionWithin1h 如果存在
DROP TABLE IF EXISTS edstaysTransfusionWithin1h;

-- 创建新表 edstaysTransfusionWithin1h
CREATE TABLE edstaysTransfusionWithin1h (
    stay_id INT PRIMARY KEY
);

-- 插入符合条件的数据到 edstaysTransfusionWithin1h 表中
INSERT INTO edstaysTransfusionWithin1h (stay_id)
SELECT DISTINCT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_hosp.poe AS poe
ON edstays.subject_id = poe.subject_id
WHERE poe.order_subtype IN (
        'Frozen Plasma Product Order',
        'Platelet Product Order',
        'Red Cell Product Order'
    )
    AND poe.ordertime BETWEEN edstays.intime AND (edstays.intime + INTERVAL '1 hour')
ON CONFLICT (stay_id) DO NOTHING;

-- 更新 edstay_triage_extra 表，增加 transfusion_within_1h 列并记录数据
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN transfusion_within_1h INT DEFAULT 0;

UPDATE mimiciv_ed.edstay_triage_extra extra
SET transfusion_within_1h = 1
FROM edstaysTransfusionWithin1h trans
WHERE extra.stay_id = trans.stay_id;

-- 检查并删除表 edstaysTransfusionBeyond1h 如果存在
DROP TABLE IF EXISTS edstaysTransfusionBeyond1h;

-- 创建新表 edstaysTransfusionBeyond1h
CREATE TABLE edstaysTransfusionBeyond1h (
    stay_id INT PRIMARY KEY
);

-- 插入满足条件的数据到 edstaysTransfusionBeyond1h 表中
INSERT INTO edstaysTransfusionBeyond1h (stay_id)
SELECT DISTINCT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_hosp.poe AS poe
ON edstays.subject_id = poe.subject_id
WHERE poe.order_subtype IN (
        'Frozen Plasma Product Order',
        'Platelet Product Order',
        'Red Cell Product Order',
        'Cryoprecipitate Product Order'
    )
    AND poe.ordertime BETWEEN (edstays.intime + INTERVAL '1 hour') AND (edstays.intime + INTERVAL '7 days')
ON CONFLICT (stay_id) DO NOTHING;

-- 更新 edstay_triage_extra 表，增加 transfusion_beyond_1h 列并记录数据
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN transfusion_beyond_1h INT DEFAULT 0;

UPDATE mimiciv_ed.edstay_triage_extra extra
SET transfusion_beyond_1h = 1
FROM edstaysTransfusionBeyond1h trans
WHERE extra.stay_id = trans.stay_id;

-- 统计插入的数据量
SELECT COUNT(*) AS total_count FROM edstaysTransfusionBeyond1h;

-- 检查并删除表 edstaysRedCellOrderMoreThan1 如果存在
DROP TABLE IF EXISTS edstaysRedCellOrderMoreThan1;

-- 创建新表 edstaysRedCellOrderMoreThan1
CREATE TABLE edstaysRedCellOrderMoreThan1 (
    stay_id INT PRIMARY KEY,
    order_count INT
);

-- 插入满足条件的数据到 edstaysRedCellOrderMoreThan1 表中
INSERT INTO edstaysRedCellOrderMoreThan1 (stay_id, order_count)
SELECT 
    edstays.stay_id,
    COUNT(poe.poe_id) AS order_count
FROM 
    mimiciv_ed.edstays AS edstays
JOIN 
    mimiciv_hosp.poe AS poe
ON 
    edstays.subject_id = poe.subject_id 
    AND edstays.hadm_id = poe.hadm_id
WHERE 
    poe.order_subtype = 'Red Cell Product Order'
    AND poe.ordertime BETWEEN (edstays.intime + INTERVAL '1 hour') AND (edstays.intime + INTERVAL '7 days')
GROUP BY 
    edstays.stay_id
HAVING 
    COUNT(poe.poe_id) > 1
ON CONFLICT (stay_id) DO NOTHING;

-- 更新 edstay_triage_extra 表，增加 red_cell_order_more_than_1 列并记录数据
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN red_cell_order_more_than_1 INT DEFAULT 0;

UPDATE mimiciv_ed.edstay_triage_extra extra
SET red_cell_order_more_than_1 = 1
FROM edstaysRedCellOrderMoreThan1 redcell
WHERE extra.stay_id = redcell.stay_id;

-- 统计插入的数据量
SELECT COUNT(*) AS total_count FROM edstaysRedCellOrderMoreThan1;

-- 检查并删除表 edstaysIntraosseousLinePlaced 如果存在
DROP TABLE IF EXISTS edstaysIntraosseousLinePlaced;

-- 创建新表 edstaysIntraosseousLinePlaced
CREATE TABLE edstaysIntraosseousLinePlaced (
    stay_id INT PRIMARY KEY
);

-- 插入满足条件的数据到 edstaysIntraosseousLinePlaced 表中
INSERT INTO edstaysIntraosseousLinePlaced (stay_id)
SELECT DISTINCT edstays.stay_id
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_hosp.procedures_icd AS procedures
ON edstays.subject_id = procedures.subject_id
WHERE procedures.icd_code IN ('4192', '07HT33Z', '07HT03Z')
AND procedures.chartdate BETWEEN edstays.intime AND (edstays.intime + INTERVAL '7 days')
ON CONFLICT (stay_id) DO NOTHING;

-- 更新 edstay_triage_extra 表，增加 intraosseous_line_placed 列并记录数据
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN intraosseous_line_placed INT DEFAULT 0;

UPDATE mimiciv_ed.edstay_triage_extra extra
SET intraosseous_line_placed = 1
FROM edstaysIntraosseousLinePlaced intraosseous
WHERE extra.stay_id = intraosseous.stay_id;

-- 统计插入的数据量
SELECT COUNT(*) AS total_count FROM edstaysIntraosseousLinePlaced;

-- 检查并删除表 edstaysCriticalProcedures 如果存在
DROP TABLE IF EXISTS edstaysCriticalProcedures;

-- 创建新表 edstaysCriticalProcedures
CREATE TABLE edstaysCriticalProcedures (
    stay_id INT PRIMARY KEY,
    icd_code VARCHAR(10)
);

-- 插入满足条件的数据到 edstaysCriticalProcedures 表中
INSERT INTO edstaysCriticalProcedures (stay_id, icd_code)
SELECT DISTINCT edstays.stay_id, procedures.icd_code
FROM mimiciv_ed.edstays AS edstays
JOIN mimiciv_hosp.procedures_icd AS procedures
ON edstays.subject_id = procedures.subject_id
WHERE procedures.icd_code IN (
    '3893','3895','3897','8962', -- Central line ICD-9 codes
    '05HM03Z', '05H503Z', '05H50DZ', '05H533Z', '05H53DZ', '05H543Z', '05H54DZ',
    '05H603Z', '05H60DZ', '05H633Z', '05H63DZ', '05H643Z', '05H64DZ',
    '05H703Z', '05H70DZ', '05H733Z', '05H73DZ', '05H743Z', '05H74DZ',
    '05H803Z', '05H80DZ', '05H833Z', '05H83DZ', '05H843Z', '05H84DZ',
    '05HB03Z', '05HB0DZ', '05HB33Z', '05HB3DZ', '05HB43Z', '05HB4DZ',
    '05HC03Z', '05HC0DZ', '05HC33Z', '05HC3DZ', '05HC43Z', '05HC4DZ',
    '05HD03Z', '05HD0DZ', '05HD33Z', '05HD3DZ', '05HD43Z', '05HD4DZ',
    '05HF03Z', '05HF0DZ', '05HF33Z', '05HF3DZ', '05HF43Z', '05HF4DZ',
    '05HM0DZ', '05HM33Z', '05HM3DZ', '05HM43Z', '05HM4DZ',
    '05HN03Z', '05HN0DZ', '05HN33Z', '05HN3DZ', '05HN43Z', '05HN4DZ',
    '05HP03Z', '05HP0DZ', '05HP33Z', '05HP3DZ', '05HP43Z', '05HP4DZ',
    '05HQ03Z', '05HQ0DZ', '05HQ33Z', '05HQ3DZ', '05HQ43Z', '05HQ4DZ',
    '06H003Z', '06H00DZ', '06H033Z', '06H03DZ', '06H043Z', '06H04DZ', -- Central line ICD-10 codes
    '3891','8960','8961', -- Arterial line ICD-9 codes
    '0W9G00Z', '0W9G0ZX', '0W9G0ZZ', '0W9G30Z', '0W9G3ZX', '0W9G3ZZ', '0W9G40Z', '0W9G4ZX', '0W9G4ZZ', -- Paracentesis ICD-10 codes
    '0W9B3ZX', '0W9B3ZZ', '0W9B4ZX', '0W9B4ZZ', '0W993ZX', '0W993ZZ', '0W994ZX', '0W994ZZ', -- Thoracentesis ICD-10 codes
    '0W9B00Z', '0W9B30Z', '0W9B40Z', '0W9900Z', '0W9930Z', '0W9940Z', -- Tube thoracostomy ICD-10 codes
    '00JU0ZZ', '00JU3ZZ', '00JU4ZZ' -- Lumbar puncture ICD-10 codes
)
AND DATE(procedures.chartdate) BETWEEN DATE(edstays.intime) AND DATE(edstays.outtime + INTERVAL '1 day')
ON CONFLICT (stay_id) DO NOTHING;

-- 删除已经存在的 critical_procedure 列
ALTER TABLE mimiciv_ed.edstay_triage_extra
DROP COLUMN IF EXISTS critical_procedure;

-- 更新 edstay_triage_extra 表，增加 critical_procedure 列并记录数据
ALTER TABLE mimiciv_ed.edstay_triage_extra
ADD COLUMN critical_procedure INT DEFAULT 0;

UPDATE mimiciv_ed.edstay_triage_extra extra
SET critical_procedure = 1
FROM edstaysCriticalProcedures critical
WHERE extra.stay_id = critical.stay_id;

-- 统计插入的数据量
SELECT COUNT(*) AS total_count FROM edstaysCriticalProcedures;

