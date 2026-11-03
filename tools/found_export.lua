-- Usage : lua tools/found_export.lua <WTF/Account/<compte>/SavedVariables/AeonDungeonJournal.lua> >> tools/forever_dungeons.txt
-- Lit les boss relevés en jeu (db.found, rencontre réussie puis butin d'une créature absente de Data.lua) et écrit
-- une ligne par boss au format de forever_dungeons.txt : clé|instanceID|niveaux|ordre|npcID|nom|itemIDs.
-- Boss déjà dans Data.lua (même npcID ou même nom) : ignoré. Donjon absent de Data.lua : clé UNKNOWN_<instanceID>
-- et niveaux vides, à compléter à la main (note sur stderr).
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
