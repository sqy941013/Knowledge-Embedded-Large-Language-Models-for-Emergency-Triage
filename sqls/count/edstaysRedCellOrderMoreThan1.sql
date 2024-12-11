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
    AND poe.ordertime BETWEEN edstays.intime AND (edstays.intime + INTERVAL '7 days')
GROUP BY 
    edstays.stay_id
HAVING 
    COUNT(poe.poe_id) > 1
ON CONFLICT (stay_id) DO NOTHING;

-- 统计插入的数据量
SELECT COUNT(*) AS total_count FROM edstaysRedCellOrderMoreThan1;