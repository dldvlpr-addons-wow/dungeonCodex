-- Tooltip.lua
-- Infobulles d'objet du jeu : liste de souhaits, puis donjon, boss et chance de butin, d'après Data.lua et
-- le butin vu tomber en jeu.
-- /codex tooltip pour masquer ou réafficher.
local ADDON_NAME, NS = ...

local MAX_SOURCES = 3
local isSecret = _G.issecretvalue or function() return false end

local sources = {}   -- itemID -> { { donjon, boss }, ... }
for _, dungeon in ipairs(NS.Dungeons) do
    for _, boss in ipairs(dungeon.bosses) do
        for _, itemID in ipairs(boss.items) do
            sources[itemID] = sources[itemID] or {}
            table.insert(sources[itemID], { dungeon, boss })
        end
    end
end

--- Boss qui ont laissé tomber l'objet en jeu sans que Data.lua le liste.
local function RecordedBosses(db, itemID)
    local bosses, listed = {}, {}
    for _, source in ipairs(sources[itemID] or {}) do listed[source[2]] = true end
    for key, items in pairs(db.recorded or {}) do
        local boss = items[itemID] and NS.BossByRecordKey[key]
        if boss and not listed[boss] then bosses[#bosses + 1] = boss end
    end
    return bosses
end

local function AddSources(tooltip, data)
    local db = _G[ADDON_NAME .. "DB"]
    local itemID = data and data.id
    if not db or db.hideTooltip or isSecret(itemID) or not itemID then return end
    if NS.IsWished(itemID) then tooltip:AddLine(NS.WISH_MARK .. NS.L.WISHLIST, 1, 0.82, 0) end
    local wishedBy = NS.WishedBy(itemID)
    if #wishedBy > 0 then tooltip:AddLine(NS.L.WISHED_BY:format(table.concat(wishedBy, ", ")), 1, 0.82, 0) end
    local shown = 0
    for _, source in ipairs(sources[itemID] or {}) do
        if shown == MAX_SOURCES then return end
        local dungeon, boss = source[1], source[2]
        local chance = boss.drops and boss.drops[itemID]
        tooltip:AddDoubleLine(NS.DungeonName(dungeon) .. " - " .. NS.BossName(boss), chance and chance .. " %" or "",
            0.25, 0.66, 0.96, 1, 1, 1)
        shown = shown + 1
    end
    for _, boss in ipairs(RecordedBosses(db, itemID)) do
        if shown == MAX_SOURCES then return end
        tooltip:AddDoubleLine(NS.DungeonName(boss.dungeon) .. " - " .. NS.BossName(boss), NS.L.RECORDED,
            0.25, 0.66, 0.96, 0.6, 0.6, 0.6)
        shown = shown + 1
    end
end

if _G.TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddSources)
end
