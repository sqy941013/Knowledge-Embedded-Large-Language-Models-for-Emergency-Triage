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

-- 统计插入的数据量
SELECT COUNT(*) AS total_count FROM edstaysIntraosseousLinePlaced;