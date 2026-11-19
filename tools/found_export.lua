-- Usage : lua tools/found_export.lua <WTF/Account/<compte>/SavedVariables/AeonDungeonJournal.lua> >> tools/forever_dungeons.txt
-- Lit les boss relevés en jeu (db.found, rencontre réussie puis butin d'une créature absente de Data.lua) et écrit
-- une ligne par boss au format de forever_dungeons.txt : clé|instanceID|niveaux|ordre|npcID|nom|itemIDs.
-- Boss déjà dans Data.lua (même npcID ou même nom) : ignoré. Donjon absent de Data.lua : clé UNKNOWN_<instanceID>
-- et niveaux vides, à compléter à la main (note sur stderr). Sur stderr aussi : quêtes que le serveur ne connaît
-- pas (db.missingQuests), niveaux de boss relevés en jeu qui manquent ou diffèrent dans Data.lua (db.bossLevels) et
-- entrées relevées en jeu (db.entrances) à plus de 0.02 de celles de Data.lua (arrondies à 0.01), à reporter dans
-- tools/manual_positions.py.
local path = assert(arg[1], "chemin du fichier SavedVariables attendu")
local here = arg[0]:match("^(.*)[/\\]") or "."

local NS = {}
assert(loadfile(here .. "/../Data.lua"))("AeonDungeonJournal", NS)
assert(loadfile(path))()
local db = assert(_G.AeonDungeonJournalDB, "AeonDungeonJournalDB absent du fichier")

local instanceIDs = {}
for instanceID in pairs(db.found or {}) do instanceIDs[#instanceIDs + 1] = instanceID end
table.sort(instanceIDs)

for _, instanceID in ipairs(instanceIDs) do
    local found = db.found[instanceID]
    local dungeon
    for _, candidate in ipairs(NS.Dungeons) do
        if candidate.instance == instanceID and not candidate.upcoming then dungeon = dungeon or candidate end
    end
    local key, levels, order = "UNKNOWN_" .. instanceID, "", 0
    if dungeon then
        key, levels, order = dungeon.key, table.concat(dungeon.levels, ","), #dungeon.bosses
    else
        io.stderr:write(("instance %d (%s) absente de Data.lua : clé et niveaux à compléter\n")
            :format(instanceID, tostring(found.name)))
    end
    local known = {}
    for _, boss in ipairs(dungeon and dungeon.bosses or {}) do
        known[boss.name] = true
        if boss.npc then known[boss.npc] = true end
    end
    local encounterIDs = {}
    for encounterID, entry in pairs(found.encounters or {}) do
        if entry.npc and not known[entry.npc] and not known[entry.name] then encounterIDs[#encounterIDs + 1] = encounterID end
    end
    table.sort(encounterIDs)
    for _, encounterID in ipairs(encounterIDs) do
        local entry = found.encounters[encounterID]
        local items = {}
        for itemID in pairs(db.recorded and db.recorded["e" .. encounterID] or {}) do items[#items + 1] = itemID end
        table.sort(items)
        order = order + 1
        print(table.concat({ key, instanceID, levels, order, entry.npc, entry.name:gsub('"', '\\"'), table.concat(items, ",") }, "|"))
    end
end

for questID in pairs(db.missingQuests or {}) do
    io.stderr:write(("quête %d absente du serveur\n"):format(questID))
end
for npcID, level in pairs(db.bossLevels or {}) do
    for _, dungeon in ipairs(NS.Dungeons) do
        for _, boss in ipairs(dungeon.bosses) do
            if boss.npc == npcID and tostring(boss.level) ~= tostring(level) then
                io.stderr:write(("%s|%s : niveau %d relevé en jeu, %s dans Data.lua\n"):format(dungeon.key, boss.name, level, tostring(boss.level)))
            end
        end
    end
end
-- Bilan toujours écrit : « 0 relevée » après des donjons faits = relevé en jeu muet, à examiner.
local recorded, gaps, unknown = 0, 0, 0
for key, seen in pairs(db.entrances or {}) do
    recorded = recorded + 1
    local matched = false
    for _, dungeon in ipairs(NS.Dungeons) do
        matched = matched or dungeon.key == key
        local spot = dungeon.key == key and dungeon.entrance
        local second = dungeon.key == key and dungeon.secondEntrance
        local function near(entry) return entry and entry.map == seen[1] and math.abs(entry.x - seen[2]) <= 0.02
            and math.abs(entry.y - seen[3]) <= 0.02 end
        if dungeon.key == key and not near(spot) and not near(second) then
            io.stderr:write(("%s : entrée relevée en jeu (%d, %.3f, %.3f), Data.lua %s\n"):format(key, seen[1], seen[2], seen[3],
                spot and ("(%d, %s, %s)"):format(spot.map, spot.x, spot.y) or "sans entrée"))
            gaps = gaps + 1
        end
    end
    if not matched then
        unknown = unknown + 1
        io.stderr:write(("%s : entrée relevée pour une clé absente de Data.lua\n"):format(key))
    end
end
io.stderr:write(("entrées relevées : %d, écarts : %d, clés inconnues : %d\n"):format(recorded, gaps, unknown))
