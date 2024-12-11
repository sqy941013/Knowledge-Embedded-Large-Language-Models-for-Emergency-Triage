CREATE TABLE IF NOT EXISTS Tier3MedUsage (
    stay_id INT PRIMARY KEY
);
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