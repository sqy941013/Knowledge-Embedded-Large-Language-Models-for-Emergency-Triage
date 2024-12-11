CREATE TABLE IF NOT EXISTS Tier4MedUsage (
    stay_id INT PRIMARY KEY
);
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