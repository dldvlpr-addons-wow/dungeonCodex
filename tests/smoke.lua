-- Charge l'addon hors du jeu sur un mock permissif, ouvre le journal, parcourt chaque donjon,
-- chaque étage et chaque boss, relève un butin. Usage (depuis la racine) : lua tests/smoke.lua
local NOOP = function() end
local ADDON = "AeonDungeonJournal"

local function Region()
    local region = { shown = false, points = {}, scripts = {}, width = 0, height = 0 }
    return setmetatable(region, { __index = function(self, key)
        if key == "Show" then return function(r) r.shown = true local s = r.scripts.OnShow if s then s(r) end end end
        if key == "Hide" then return function(r) r.shown = false end end
        if key == "IsShown" then return function(r) return r.shown end end
        if key == "SetShown" then return function(r, v) r.shown = v and true or false end end
        if key == "SetScript" then return function(r, name, fn) r.scripts[name] = fn end end
        if key == "GetScript" then return function(r, name) return r.scripts[name] end end
        if key == "HookScript" then return function(r, name, fn) r.scripts[name] = fn end end
        if key == "SetColorTexture" then return function(r, red, green, blue) r.color = { red, green, blue } end end
        if key == "SetupMenu" then   -- comme le client : le générateur tourne dès la pose du menu
            return function(r, generator) r.generator = generator generator(r, { CreateRadio = NOOP }) end
        end
        if key == "SetSize" then return function(r, w, h) r.width, r.height = w, h end end
        if key == "SetWidth" then return function(r, w) r.width = w end end
        if key == "SetHeight" then return function(r, h) r.height = h end end
        if key == "GetWidth" then return function(r) return r.width end end
        if key == "GetHeight" then return function(r) return r.height end end
        if key == "GetText" then return function(r) return r.text end end
        if key == "SetText" then return function(r, t) r.text = t end end
        if key == "GetName" then return function(r) return r.name end end
        if key == "GetFrameLevel" then return function() return 1 end end
        if key == "GetEffectiveScale" then return function() return 1 end end
        if key == "GetLeft" then return function() return 100 end end
        if key == "GetTop" then return function() return 500 end end
        if key == "GetCenter" then return function() return 500, 400 end end
        if key == "GetVerticalScrollRange" then return function() return 0 end end
        if key == "GetVerticalScroll" then return function() return 0 end end
        if key:match("^Create") then return function() return Region() end end
        return NOOP
    end })
end

local events = {}
local eventFrames = {}
local buttons = {}
local frames = {}
function CreateFrame(kind, name, _, template)
    local frame = Region()
    frame.name = name
    frames[#frames + 1] = frame
    if kind == "Button" then buttons[#buttons + 1] = frame end
    local register = function(f, event) events[event] = true eventFrames[#eventFrames + 1] = f end
    rawset(frame, "RegisterEvent", register)
    if name then _G[name] = frame end
    return frame
end
local function Fire(event, ...)
    for _, frame in ipairs(eventFrames) do
        local handler = frame.scripts.OnEvent
        if handler then handler(frame, event, ...) end
    end
end

UIParent = Region()
Minimap = Region()
math.atan2 = math.atan2 or math.atan
GameTooltip = Region()
UISpecialFrames = {}
SlashCmdList = {}
ITEM_QUALITY_COLORS = { [2] = { hex = "|cff1eff00" }, [3] = { hex = "|cff0070dd" } }
GetLocale = function() return "frFR" end
INVTYPE_HEAD = "Tête"
GetRealZoneText = function(id) return "Zone" .. id end
GetInstanceInfo = function() return "Deadmines", "party", 1, "", 5, 0, false, 36 end
GetCursorPosition = function() return 300, 300 end
IsShiftKeyDown = function() return true end
GameTooltip_Hide = NOOP
HandleModifiedItemClick = NOOP
IsModifiedClick = function() return false end
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
strsplit = function(sep, text)
    local parts = {}
    for part in (text .. sep):gmatch("(.-)" .. sep) do parts[#parts + 1] = part end
    return unpack(parts)
end
C_Timer = { After = function(_, fn) fn() end }
C_CVar = { RegisterCVar = NOOP, GetCVar = function() return "" end, SetCVar = function() return true end }
g_addonCategoriesCollapsed = {}
C_Item = {
    GetItemInfo = function(id) if id % 2 == 0 then return "Objet" .. id, "|Hitem:" .. id .. "|h", 3 end end,
    GetItemIconByID = function() return 134400 end,
    RequestLoadItemDataByID = NOOP,
    GetItemInfoInstant = function(item)
        local id = tonumber(tostring(item):match("(%d+)"))
        return id, "Armure", id % 2 == 0 and "Tissu" or "Cuir", id % 3 == 0 and "INVTYPE_HEAD" or ""
    end,
}
local activeQuest
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return id % 2 == 0 end,
               IsOnQuest = function(id) return id == activeQuest or id % 2 == 0 end }   -- pair : rendue, jamais « en cours »
UnitLevel = function() return 20 end
UnitFactionGroup = function() return "Alliance", "Alliance" end
local clock = 100000
time = function() return clock end
local inGroup, chatLocked, sent = true, false, {}
IsInGroup = function() return inGroup end
IsInRaid = function() return false end
C_ChatInfo = { SendChatMessage = function(text, channel) sent[#sent + 1] = { text = text, channel = channel } end,
               InChatMessagingLockdown = function() return chatLocked end }
C_Spell = { GetSpellName = function(id) return "Sort" .. id end }
local tooltipPostCall
TooltipDataProcessor = { AddTooltipPostCall = function(_, callback) tooltipPostCall = callback end }
Enum = { TooltipDataType = { Item = 0 } }
local now = 1000
GetTime = function() return now end
GetLootRollItemLink = function() return "|Hitem:5202|h" end
local printed, realPrint = {}, print
print = function(text, ...)
    printed[#printed + 1] = text
    realPrint(text, ...)
end
local loot = { { link = "|Hitem:99999|h", quality = 3, guid = "Creature-0-1-2-3-639-0000" },
               { link = "|Hitem:5193|h", quality = 3, guid = "Creature-0-1-2-3-639-0000" } }
GetNumLootItems = function() return #loot end
GetLootSlotLink = function(slot) return loot[slot].link end
GetLootSlotInfo = function(slot) return nil, nil, 1, nil, loot[slot].quality, false, false end
GetLootSourceInfo = function(slot) return loot[slot].guid, 1 end

local NS = {}
local files, textLocales = {}, {}
for line in io.lines(ADDON .. ".toc") do
    line = line:gsub("\r", ""):gsub("\\", "/")
    if line ~= "" and not line:match("^#") then
        files[#files + 1] = line
        textLocales[#textLocales + 1] = line:match("^Tactics/(%a+)%.lua$")
    end
end
for _, file in ipairs(files) do
    assert(loadfile(file))(ADDON, NS)
end

-- Chaque langue (esMX lit le fichier esES) : un texte par capacité de chaque combat.
assert(textLocales[1] == "enUS" and #textLocales == 10, "enUS en premier, 10 langues de textes")
textLocales[#textLocales + 1] = "esMX"
for _, locale in ipairs(textLocales) do
    local texts = {}
    GetLocale = function() return locale end
    assert(loadfile("Tactics/" .. (locale == "esMX" and "esES" or locale) .. ".lua"))(ADDON, texts)
    for _, dungeon in ipairs(NS.Dungeons) do
        for _, boss in ipairs(dungeon.bosses) do
            local tactic = boss.tactic and texts.Tactics and texts.Tactics[boss.tactic]
            assert(not boss.abilities or boss.tactic, "combat numéroté : " .. boss.name)
            assert(not boss.tactic or tactic and #tactic == #(boss.abilities or {}),
                "textes " .. locale .. " du combat de " .. boss.name)
            for _, ability in ipairs(tactic or {}) do
                assert(ability[1] ~= "" and ability[2], "capacité " .. locale .. " de " .. boss.name)
            end
        end
    end
end
GetLocale = function() return "frFR" end
for _, event in ipairs({ "ADDON_LOADED", "LOOT_OPENED", "GET_ITEM_INFO_RECEIVED", "QUEST_TURNED_IN", "START_LOOT_ROLL",
                         "QUEST_ACCEPTED", "QUEST_REMOVED", "PLAYER_LEVEL_UP", "UNIT_DIED", "BOSS_KILL" }) do
    assert(events[event], "événement enregistré : " .. event)
end
Fire("LOOT_OPENED")   -- avant le chargement des réglages : ignoré
Fire("ADDON_LOADED", "AutreAddon")
assert(_G[ADDON .. "DB"] == nil, "ADDON_LOADED d'un autre addon : rien de chargé")
Fire("ADDON_LOADED", ADDON)
local db = _G[ADDON .. "DB"]
assert(db and db.pins and db.recorded, "base de réglages")
for _, dungeon in ipairs(NS.Dungeons) do
    for _, floor in ipairs(dungeon.floors) do
        local art = NS.Floors[floor]
        assert(art and #art > 0 and #art <= 12 and #art % (art.cols or 4) == 0, "tuiles de l'étage " .. floor)
    end
end

Fire("LOOT_OPENED")
assert(db.recorded[639][99999] and db.recorded[639][5193], "butin relevé sur VanCleef")

local slash = SlashCmdList.AEONDUNGEONJOURNAL
slash("")
local frame = AeonDungeonJournalFrame
assert(frame and frame:IsShown(), "fenêtre ouverte")
assert(frame.scripts.OnShow, "rafraîchissement à l'ouverture")

local function Click(button) button.scripts.OnClick(button) end
local function Visible(pattern)
    local found = {}
    for _, button in ipairs(buttons) do
        local label = type(button.text) == "table" and button.text.text or button.text
        if button.shown and type(label) == "string" and label:match(pattern) then found[#found + 1] = button end
    end
    return found
end

local function BossRows()
    local found = {}
    for _, button in ipairs(buttons) do
        local number = type(button.number) == "table" and button.number.text and tostring(button.number.text)
        if button.shown and not rawget(button, "skull") and type(number) == "string" and number:match("^%d+$") then
            found[#found + 1] = button
        end
    end
    return found
end

--- Lignes de quête affichées : avec la coche de quête rendue, sans la coche.
local function QuestMarks()
    local marked, plain = 0, 0
    for _, row in ipairs(frames) do
        local title = rawget(row, "title")
        if row.shown and rawget(row, "rewards") and type(title) == "table" and type(title.text) == "string" then
            if title.text:find("^|A:common%-icon%-checkmark") then marked = marked + 1 else plain = plain + 1 end
        end
    end
    return marked, plain
end

--- Lignes de capacité affichées : leur texte vient de Tactics/. Rend le nombre de noms de sort et de notes.
local tacticTexts, tacticNotes = {}, {}
for _, tactic in pairs(NS.Tactics) do
    if tactic.note then tacticNotes[tactic.note] = true end
    for _, ability in ipairs(tactic) do tacticTexts[ability[2]] = true end
end
local function AbilityRows()
    local spells, notes = 0, 0
    for _, row in ipairs(frames) do
        local name, text = rawget(row, "name"), rawget(row, "text")
        if row.shown and rawget(row, "flags") and rawget(row, "source") and type(text) == "table" then
            assert(tacticTexts[text.text] or tacticNotes[text.text], "texte de capacité hors de Tactics/ : " .. tostring(text.text))
            if tostring(name.text):match("^Sort%d+$") then spells = spells + 1 end
            if tacticNotes[text.text] then notes = notes + 1 end
        end
    end
    return spells, notes
end

assert(#BossRows() > 0, "ouverture sur le donjon en cours")
Click(Visible("^" .. NS.L.HOME .. "$")[1])
local dungeonRows = Visible("^Zone%d+")
assert(#dungeonRows == 27, "27 donjons listés, vu " .. #dungeonRows)
-- Donjons conseillés : bordure dorée sur ceux dont la tranche contient le niveau du joueur (20), et eux seuls.
local advised = 0
for i, card in ipairs(dungeonRows) do
    local levels = NS.Dungeons[i].levels
    local expected = levels[1] <= 20 and 20 <= levels[3]
    assert((card.edges[1].color[1] == 1) == expected, "bordure du donjon " .. NS.Dungeons[i].key)
    if expected then advised = advised + 1 end
end
assert(advised > 0 and advised < #dungeonRows, "donjons conseillés : " .. advised)
-- Donjons sans image : miniature faite des tuiles de leur premier étage.
for i, dungeon in ipairs(NS.Dungeons) do
    if dungeon.instance == 2999 or dungeon.instance == 3065 then
        local shown = 0
        for _, tile in ipairs(dungeonRows[i].tiles) do
            if tile.shown then shown = shown + 1 end
        end
        assert(shown > 0, "miniature de " .. dungeon.key)
    end
end

local tabs, shareButton = {}, nil
for _, button in ipairs(buttons) do
    if rawget(button, "key") then tabs[#tabs + 1] = button end
    if button.text == NS.L.SHARE then shareButton = button end
end
assert(shareButton and not shareButton.shown, "bouton de partage caché sans boss choisi")
assert(#tabs == 4, "4 onglets latéraux")
local bossesSeen, lootRows, markedSeen, plainSeen, spellsSeen, notesSeen = 0, 0, 0, 0, 0, 0
for dungeonIndex, dungeonRow in ipairs(dungeonRows) do
    Click(dungeonRow)
    local marked, plain = QuestMarks()
    markedSeen, plainSeen = markedSeen + marked, plainSeen + plain
    local bossRows = BossRows()
    assert(#bossRows > 0, "boss listés pour " .. dungeonRow.text.text)
    for index = 1, #bossRows do
        Click(BossRows()[index])
        bossesSeen = bossesSeen + 1
        lootRows = lootRows + #Visible("Objet%d+") + #Visible("^%.%.%.")
        for _, tab in ipairs(tabs) do Click(tab) end
        local spells, notes = AbilityRows()
        spellsSeen, notesSeen = spellsSeen + spells, notesSeen + notes
        local boss = NS.Dungeons[dungeonIndex].bosses[index]
        assert(shareButton.shown == (boss.tactic ~= nil), "bouton de partage seulement pour un boss qui a une tactique")
        if shareButton.shown then Click(shareButton) end
    end
end
-- Partage au groupe : une ligne par boss et par capacité, coupée à 250 octets au plus.
assert(#sent > 61 + 113, "tactiques envoyées, lignes longues coupées : " .. #sent)
for _, message in ipairs(sent) do
    assert(message.channel == "PARTY" and #message.text > 0 and #message.text <= 250, "message de " .. #message.text .. " octets")
end
assert(spellsSeen > 0 and notesSeen > 0, "noms de sort du client et notes de combat affichés : " .. spellsSeen .. " / " .. notesSeen)
assert(bossesSeen == 239, "239 boss parcourus, vu " .. bossesSeen)
assert(lootRows > 1000, "lignes de butin affichées : " .. lootRows)
assert(markedSeen > 0 and plainSeen > 0, "quêtes rendues cochées, les autres non : " .. markedSeen .. " / " .. plainSeen)

-- Une quête rendue pendant que le journal est ouvert est cochée aussitôt.
local target, pending
for i, dungeon in ipairs(NS.Dungeons) do
    for _, quest in ipairs(dungeon.quests) do
        if not target and quest.id % 2 == 1 and quest.side ~= "h" then target, pending = i, quest.id end
    end
end
Click(dungeonRows[target])
local markedBefore = QuestMarks()
Fire("QUEST_TURNED_IN", pending, 100, 0)
assert(QuestMarks() == markedBefore + 1, "quête cochée dès qu'elle est rendue")

-- Infobulle d'objet : donjon, boss et chance de butin ; masquée par /codex tooltip.
local function TooltipLines(itemID)
    local lines = {}
    local tooltip = { AddDoubleLine = function(_, left, right) lines[#lines + 1] = left .. " | " .. right end }
    tooltipPostCall(tooltip, { id = itemID })
    return lines
end
local lines = TooltipLines(5193)
assert(#lines >= 1 and lines[1]:find("Zone36", 1, true) and lines[1]:find("23.08 %", 1, true),
    "source dans l'infobulle : " .. tostring(lines[1]))
assert(#TooltipLines(1) == 0, "objet hors donjon : infobulle intacte")
slash("tooltip")
assert(#TooltipLines(5193) == 0, "infobulle masquée")
slash("tooltip")
assert(#TooltipLines(5193) >= 1, "infobulle réaffichée")

-- Filtres du butin, sur Deadmines : recherche par nom, menu des emplacements, remise à zéro au changement de donjon.
local function LootRows()
    local found = {}
    for _, row in ipairs(buttons) do
        if row.shown and rawget(row, "iconBorder") then found[#found + 1] = row end
    end
    return found
end
local function LootRow(pattern)
    for _, row in ipairs(LootRows()) do
        if row.text.text:find(pattern, 1, true) then return row end
    end
end
local deadmines, lootTab, searchBox
local menus = {}
for i, dungeon in ipairs(NS.Dungeons) do
    if dungeon.instance == 36 then deadmines = i end
end
for _, tab in ipairs(tabs) do
    if tab.key == "loot" then lootTab = tab end
end
for _, candidate in ipairs(frames) do
    if candidate.scripts.OnTextChanged then searchBox = candidate end
    if rawget(candidate, "generator") then menus[#menus + 1] = candidate end
end
local function OpenDeadminesLoot()
    Click(dungeonRows[deadmines])
    Click(lootTab)
end
local function Search(text)
    searchBox.text = text
    searchBox.scripts.OnTextChanged(searchBox)
end
local function Radios(menu)
    local radios = {}
    menu.generator(menu, { CreateRadio = function(_, text, isSelected, setSelected, data)
        radios[#radios + 1] = { text = text, isSelected = isSelected, setSelected = setSelected, data = data }
    end })
    return radios
end
OpenDeadminesLoot()
local allLoot = #LootRows()
Search("OBJET5202")
assert(#LootRows() == 1 and LootRow("Objet5202"), "recherche par nom : " .. #LootRows())
Search("")
assert(#LootRows() == allLoot, "recherche vidée : tout le butin")
assert(#menus == 2, "menus des emplacements et des types")
local slots = Radios(menus[1])
assert(#slots == 2 and slots[1].text == NS.L.ALL_SLOTS and slots[2].text == "Tête", "choix du menu des emplacements")
assert(slots[1].isSelected(slots[1].data) and not slots[2].isSelected(slots[2].data), "aucun filtre au départ")
slots[2].setSelected(slots[2].data)
local headRows = LootRows()
assert(#headRows > 0 and #headRows < allLoot, "filtre par emplacement : " .. #headRows .. " / " .. allLoot)
for _, row in ipairs(headRows) do assert(row.slot.text:find("Tête", 1, true), "ligne hors filtre") end
local kinds = Radios(menus[2])
assert(#kinds == 3 and kinds[2].text == "Cuir" and kinds[3].text == "Tissu", "choix du menu des types")
kinds[2].setSelected(kinds[2].data)
local leatherHeads = LootRows()
assert(#leatherHeads > 0 and #leatherHeads < #headRows, "filtre par type : " .. #leatherHeads .. " / " .. #headRows)
for _, row in ipairs(leatherHeads) do assert(row.slot.text == "Tête, Cuir", "ligne hors filtre : " .. row.slot.text) end
Click(dungeonRows[deadmines == 1 and 2 or 1])
OpenDeadminesLoot()
assert(#LootRows() == allLoot and slots[1].isSelected(slots[1].data), "filtres remis à zéro au changement de donjon")

-- Liste de souhaits : clic droit, étoile sur l'objet, le boss et le donjon, alerte quand l'objet tombe.
local function Starred(list)
    local count = 0
    for _, button in ipairs(list) do
        if button.text.text:find("^|TInterface") then count = count + 1 end
    end
    return count
end
local wished = LootRow("Objet5202")
wished.scripts.OnClick(wished, "RightButton")
assert(db.wishlist[5202] and Starred(LootRows()) == 1, "objet ajouté à la liste de souhaits")
assert(Starred(BossRows()) >= 1, "étoile sur le boss")
Click(Visible("^" .. NS.L.HOME .. "$")[1])
assert(#Visible("^|TInterface.*Zone36") == 1 and #Visible("^|TInterface.*Zone%d+") == 1, "étoile sur le donjon, et lui seul")
loot[#loot + 1] = { link = "|Hitem:5202|h", quality = 3, guid = "Creature-0-1-2-3-639-0000" }
local printedBefore = #printed
Fire("LOOT_OPENED")
assert(#printed == printedBefore + 1 and printed[#printed]:find("item:5202", 1, true), "alerte quand l'objet tombe")
Fire("LOOT_OPENED")
Fire("START_LOOT_ROLL", 1, 60)
assert(#printed == printedBefore + 1, "une seule alerte par minute")
now = now + 120
Fire("START_LOOT_ROLL", 1, 60)
assert(#printed == printedBefore + 2 and printed[#printed]:find("item:5202", 1, true), "alerte au jet de groupe, la minute passée")
SlashCmdList.AEONDUNGEONJOURNAL("wishlist")
assert(#printed == printedBefore + 3 and printed[#printed]:find("5202", 1, true), "/codex wishlist liste l'objet")
printedBefore = printedBefore + 1
Click(Visible(NS.L.WISHLIST .. "$")[1])
local wishRow
for _, row in ipairs(LootRows()) do
    if row.text.text == "Objet5202" and tostring(row.slot.text):find("^Zone36, ") then wishRow = row end
end
assert(wishRow, "bouton liste de souhaits : l'objet, son donjon et son boss")
wishRow.scripts.OnClick(wishRow, "LeftButton")
assert(#Visible("^Zone36$") == 1, "clic sur l'objet : ouvre son donjon")
OpenDeadminesLoot()
wished = LootRow("Objet5202")
wished.scripts.OnClick(wished, "RightButton")
assert(db.wishlist[5202] == nil and Starred(LootRows()) == 0 and Starred(BossRows()) == 0, "objet retiré de la liste")
now = now + 120
Fire("LOOT_OPENED")
assert(#printed == printedBefore + 2, "pas d'alerte pour un objet hors de la liste")
SlashCmdList.AEONDUNGEONJOURNAL("wishlist")
assert(printed[#printed]:find(NS.L.MSG_WISHLIST_EMPTY, 1, true), "/codex wishlist : liste vide")

-- Quêtes : celles de la Horde cachées à un joueur de l'Alliance, quête du journal de quêtes marquée « en cours ».
local function QuestLevels(pattern)
    local found = 0
    for _, row in ipairs(frames) do
        local level = rawget(row, "level")
        if row.shown and rawget(row, "rewards") and type(level) == "table" and tostring(level.text):find(pattern, 1, true) then
            found = found + 1
        end
    end
    return found
end
local mixed, kept
for i, dungeon in ipairs(NS.Dungeons) do
    local mine, active = 0, nil
    for _, quest in ipairs(dungeon.quests) do
        if quest.side ~= "h" then
            mine = mine + 1
            if quest.id % 2 == 1 then active = quest.id end
        end
    end
    if not mixed and mine > 0 and mine < #dungeon.quests and active then mixed, kept, activeQuest = i, mine, active end
end
assert(mixed, "un donjon avec des quêtes de la Horde et une quête à prendre")
Click(dungeonRows[mixed])
local marked, plain = QuestMarks()
assert(marked + plain == kept, "quêtes de la Horde cachées : " .. marked + plain .. " / " .. kept)
assert(QuestLevels(NS.L.QUEST_ACTIVE) == 1 and QuestLevels("Horde") == 0, "une quête en cours, aucune de la Horde")
activeQuest = nil
Fire("QUEST_REMOVED", 1)
assert(QuestLevels(NS.L.QUEST_ACTIVE) == 0, "quête abandonnée : plus en cours")

-- Boss tués pendant le run, sur Deadmines : mort de l'unité, rencontre terminée, butin ; nouveau run.
local function Checked()
    local count = 0
    for _, button in ipairs(BossRows()) do
        if button.text.text:find("|A:common-icon-checkmark", 1, true) then count = count + 1 end
    end
    return count
end
local function PinsChecked()
    local count = 0
    for _, pin in ipairs(buttons) do
        if pin.shown and rawget(pin, "skull") and tostring(pin.number.text):find("|A:common-icon-checkmark", 1, true) then
            count = count + 1
        end
    end
    return count
end
local function Died(npc) Fire("UNIT_DIED", "Creature-0-1-2-3-" .. npc .. "-0000") end
local deadminesBosses = NS.Dungeons[deadmines].bosses
local byName, byLocalName
for _, boss in ipairs(deadminesBosses) do
    if boss.npc ~= 639 and boss.npc ~= 644 and not boss.otherNpcs then
        if NS.BossName(boss) ~= boss.name then   -- deux boss au nom traduit : l'un annoncé traduit, l'autre en anglais
            if not byLocalName then byLocalName = boss else byName = byName or boss end
        end
    end
end
assert(byName and byLocalName, "Deadmines : deux boss au nom traduit")
Click(dungeonRows[deadmines])
assert(Checked() == 1 and db.kills[639], "VanCleef coché par son butin")
Died(644)
assert(Checked() == 2 and PinsChecked() >= 1, "boss coché à sa mort, dans la liste et sur la carte")
Fire("UNIT_DIED", nil)
Fire("BOSS_KILL", 1, byName.name)
Fire("BOSS_KILL", 2, NS.BossName(byLocalName))
Fire("BOSS_KILL", 3, NS.Dungeons[deadmines == 1 and 2 or 1].bosses[1].name)   -- boss d'un autre donjon : ignoré
assert(Checked() == 4 and db.kills[639] and db.kills[644],
    "boss cochés à la fin de la rencontre : " .. byName.name .. ", " .. NS.BossName(byLocalName))
clock = clock + 700
Fire("LOOT_OPENED")
assert(Checked() == 4, "butin tardif d'un boss déjà coché : rien d'effacé")
Died(644)
assert(Checked() == 1 and db.kills[644] and not db.kills[639], "boss retué : nouveau run")
local elsewhere
for _, dungeon in ipairs(NS.Dungeons) do
    if dungeon.instance ~= 36 and dungeon.bosses[1].npc then elsewhere = elsewhere or dungeon.bosses[1].npc end
end
Died(elsewhere)
assert(db.kills[elsewhere] and not db.kills[644], "boss d'un autre donjon : nouveau run")
local multi, mate   -- boss fait de plusieurs créatures, et un autre boss de son donjon
for _, dungeon in ipairs(NS.Dungeons) do
    for _, boss in ipairs(dungeon.bosses) do
        if not multi and boss.npc and boss.otherNpcs then
            multi = boss
            for _, other in ipairs(dungeon.bosses) do
                if other.npc and not other.otherNpcs then mate = mate or other end
            end
        end
    end
end
Died(multi.npc)
Died(mate.npc)
clock = clock + 700
Died(multi.otherNpcs[1])
assert(db.kills[mate.npc] and db.kills[multi.npc], "autre créature du même boss, plus tard : rien d'effacé")
Died(644)
clock = clock + 7300
Click(dungeonRows[deadmines])
assert(Checked() == 0 and PinsChecked() == 0, "coches oubliées après deux heures sans kill")
Died(639)
assert(Checked() == 1 and not db.kills[644], "premier kill après deux heures : nouveau run")

-- Partage au groupe : gardes, et coupe d'un texte sans espace au bord d'un caractère UTF-8.
local vanCleef
for i, boss in ipairs(deadminesBosses) do
    if boss.npc == 639 then vanCleef = i end
end
Click(BossRows()[vanCleef])
assert(shareButton.shown, "bouton de partage affiché pour un boss qui a une tactique")
local sentBefore = #sent
inGroup = false
Click(shareButton)
assert(#sent == sentBefore and printed[#printed]:find(NS.L.MSG_NOT_IN_GROUP, 1, true), "pas de groupe : rien d'envoyé")
inGroup, chatLocked = true, true
Click(shareButton)
assert(#sent == sentBefore and printed[#printed]:find(NS.L.MSG_CHAT_LOCKED, 1, true), "chat verrouillé : rien d'envoyé")
chatLocked = false
local tactic = NS.Tactics[deadminesBosses[vanCleef].tactic]
local original, long = tactic[1][2], ("首领"):rep(100)
tactic[1][2] = long
Click(shareButton)
tactic[1][2] = original
local glued = ""
for i = sentBefore + 1, #sent do
    local first = sent[i].text:byte(1)
    assert(#sent[i].text <= 250 and (first < 128 or first >= 192), "message coupé au milieu d'un caractère")
    glued = glued .. sent[i].text
end
assert(glued:find(long, 1, true), "texte long envoyé en entier, dans l'ordre")

slash("resetpins")
slash("wipe")
assert(next(db.recorded) == nil, "butin oublié")
slash("")
assert(not frame:IsShown(), "fenêtre fermée")
print("smoke ok")
