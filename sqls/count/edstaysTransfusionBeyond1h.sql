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

-- 统计插入的数据量
SELECT COUNT(*) AS total_count FROM edstaysTransfusionBeyond1h;