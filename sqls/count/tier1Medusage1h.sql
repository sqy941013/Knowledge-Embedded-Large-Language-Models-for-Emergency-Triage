CREATE TABLE IF NOT EXISTS Tier1MedUsage1H (
    stay_id INT PRIMARY KEY
);
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