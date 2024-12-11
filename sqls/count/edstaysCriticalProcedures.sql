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
AND procedures.chartdate BETWEEN edstays.intime AND (edstays.intime + INTERVAL '7 days')
ON CONFLICT (stay_id) DO NOTHING;

-- 统计插入的数据量
SELECT COUNT(*) AS total_count FROM edstaysCriticalProcedures;