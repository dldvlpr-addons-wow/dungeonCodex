-- Usage : lua atlasloot_export.lua <AtlasLootClassic_DungeonsAndRaids/data.lua>
-- Écrit sur stdout une ligne par boss : clé|instanceID|niveaux|ordre|npcID|nom|itemIDs
local path = assert(arg[1], "chemin de data.lua attendu")

local data = {}
local counter = 0
local function nextIndex() counter = counter + 1 return counter end
local database = setmetatable({}, { __index = function(_, key)
    if key == "AddDifficulty" or key == "AddItemTableType" or key == "AddExtraItemTableType" then
        return nextIndex
    elseif key == "AddContentType" then
        return function(_, name) return name end
    end
end })
local identity = setmetatable({}, { __index = function(_, key) return key end })

AtlasLoot = {
    ItemDB = { Add = function() return setmetatable(data, { __index = database }) end },
    Locales = identity,
    IngameLocales = identity,
    ReturnForGameVersion = function(classic) return classic end,
    CLASSIC_VERSION_NUM = 1,
    BC_VERSION_NUM = 2,
    WRATH_VERSION_NUM = 3,
}
function AtlasLoot:GameVersion_GE(version, value) if self.CLASSIC_VERSION_NUM >= version then return value end end
function AtlasLoot:GameVersion_LT(version, value) if self.CLASSIC_VERSION_NUM < version then return value end end
UnitFactionGroup = function() return "Alliance" end
FACTION_HORDE, FACTION_ALLIANCE = "Horde", "Alliance"
setmetatable(_G, { __index = function(_, key) if key:match("^[A-Z_0-9]+$") then return key end end })
C_Map = { GetAreaInfo = function(areaID) return "Area" .. areaID end }

assert(loadfile(path))("AtlasLootClassic_DungeonsAndRaids")

local keys = {}
for key, instance in pairs(data) do
    if type(instance) == "table" and instance.ContentType == "Dungeons" then keys[#keys + 1] = key end
end
table.sort(keys)

for _, key in ipairs(keys) do
    local instance = data[key]
    local levels = type(instance.LevelRange) == "table" and table.concat(instance.LevelRange, ",") or ""
    for order, boss in ipairs(instance.items) do
        if type(boss) == "table" and not boss.ExtraList and boss.name then
            local items, seen = {}, {}
            for field, list in pairs(boss) do
                if type(field) == "number" and type(list) == "table" then
                    for _, entry in ipairs(list) do
                        local itemID = type(entry) == "table" and entry[2]
                        if type(itemID) == "number" and not seen[itemID] then
                            seen[itemID] = true
                            items[#items + 1] = { entry[1], itemID }
                        end
                    end
                end
            end
            table.sort(items, function(a, b) return a[1] < b[1] end)
            local ids = {}
            for i, item in ipairs(items) do ids[i] = item[2] end
            print(table.concat({ key, instance.InstanceID or "", levels, order, type(boss.npcID) == "table" and table.concat(boss.npcID, ",") or boss.npcID or "",
                (boss.name:gsub("%s+$", "")), table.concat(ids, ",") }, "|"))
        end
    end
end
