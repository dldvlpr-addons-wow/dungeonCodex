-- Tooltip.lua
-- Infobulles d'objet du jeu : donjon, boss et chance de butin, d'après Data.lua.
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

local function AddSources(tooltip, data)
    local db = _G[ADDON_NAME .. "DB"]
    local itemID = data and data.id
    if db and db.hideTooltip or isSecret(itemID) or not (itemID and sources[itemID]) then return end
    for i = 1, math.min(MAX_SOURCES, #sources[itemID]) do
        local dungeon, boss = sources[itemID][i][1], sources[itemID][i][2]
        local chance = boss.drops and boss.drops[itemID]
        tooltip:AddDoubleLine(NS.DungeonName(dungeon) .. " - " .. NS.BossName(boss), chance and chance .. " %" or "",
            0.25, 0.66, 0.96, 1, 1, 1)
    end
end

if _G.TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddSources)
end
