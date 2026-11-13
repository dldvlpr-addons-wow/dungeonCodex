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
        if key == "SetText" then   -- comme le client : une zone de saisie annonce le changement
            return function(r, t) r.text = t local s = r.scripts.OnTextChanged if s then s(r) end end
        end
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
function CreateFrame(kind, name, parent, template)
    local frame = Region()
    frame.name, frame.parent = name, parent
    frames[#frames + 1] = frame
    if kind == "Button" then buttons[#buttons + 1] = frame end
    if template == "UICheckButtonTemplate" then frame.Text = Region() end
    local registered = {}
    local register = function(f, event)
        events[event] = true
        if not next(registered) then eventFrames[#eventFrames + 1] = f end
        registered[event] = true
    end
    rawset(frame, "RegisterEvent", register)
    rawset(frame, "registeredEvents", registered)
    if name then _G[name] = frame end
    return frame
end
local function Fire(event, ...)
    for _, frame in ipairs(eventFrames) do
        local handler = frame.scripts.OnEvent
        if handler and frame.registeredEvents[event] then handler(frame, event, ...) end
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
local cursorX, cursorY, mouseDown = 300, 300, false
GetCursorPosition = function() return cursorX, cursorY end
IsMouseButtonDown = function() return mouseDown end
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
    GetItemCount = function() return 0 end,
    GetItemInfoInstant = function(item)
        local id = tonumber(tostring(item):match("item:(%d+)") or tostring(item):match("(%d+)"))
        -- Armure (classID 4) : tissu (1) pour les pairs, cuir (2) pour les impairs.
        return id, "Armure", id % 2 == 0 and "Tissu" or "Cuir", id % 3 == 0 and "INVTYPE_HEAD" or "", 134400, 4, 1 + id % 2
    end,
}
local activeQuest
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return id % 2 == 0 end,
               IsOnQuest = function(id) return id == activeQuest or id % 2 == 0 end }   -- pair : rendue, jamais « en cours »
UnitLevel = function() return 20 end
UnitClass = function() return "Mage", "MAGE", 8 end
INSTANCE_RESET_SUCCESS = "%s has been reset."
UnitFactionGroup = function() return "Alliance", "Alliance" end
local clock = 100000
time = function() return clock end
local inGroup, chatLocked, sent = true, false, {}
IsInGroup = function() return inGroup end
IsInRaid = function() return false end
C_ChatInfo = { SendChatMessage = function(text, channel) sent[#sent + 1] = { text = text, channel = channel } end,
               InChatMessagingLockdown = function() return chatLocked end }
local addonSent, addonResults, members, equipped = {}, {}, {}, {}
C_ChatInfo.RegisterAddonMessagePrefix = function() return 0 end
C_ChatInfo.SendAddonMessage = function(prefix, text, channel)
    addonSent[#addonSent + 1] = { prefix = prefix, text = text, channel = channel }
    return table.remove(addonResults, 1) or 0
end
UnitName = function() return "Moi" end
GetNormalizedRealmName = function() return "Royaume" end
LE_PARTY_CATEGORY_HOME, LE_PARTY_CATEGORY_INSTANCE = 1, 2
Ambiguate = function(name) return (name:gsub("%-.*", "")) end
UnitInParty = function(name) return members[name] == true end
UnitInRaid = function() return nil end
GetNumGroupMembers = function()
    local count = 1
    for _ in pairs(members) do count = count + 1 end
    return count
end
GetInventoryItemLink = function(_, slot) return equipped[slot] end
INVTYPE_HEAD = "Tête"
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

local optionsPanel, optionsOpened, compartment
Settings = { RegisterCanvasLayoutCategory = function(panel) optionsPanel = panel return { GetID = function() return 7 end } end,
             RegisterAddOnCategory = NOOP, OpenToCategory = function(id) optionsOpened = id end }
AddonCompartmentFrame = { RegisterAddon = function(_, data) compartment = data end }

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
                         "QUEST_ACCEPTED", "QUEST_REMOVED", "PLAYER_LEVEL_UP", "UNIT_DIED", "BOSS_KILL",
                         "ENCOUNTER_END", "PLAYER_ENTERING_WORLD", "CHAT_MSG_SYSTEM" }) do
    assert(events[event], "événement enregistré : " .. event)
end
Fire("LOOT_OPENED")   -- avant le chargement des réglages : ignoré
Fire("ADDON_LOADED", "AutreAddon")
assert(_G[ADDON .. "DB"] == nil, "ADDON_LOADED d'un autre addon : rien de chargé")
_G[ADDON .. "DB"] = { wishlist = { [1234] = true } }   -- liste commune d'avant 1.5
Fire("ADDON_LOADED", ADDON)
Fire("PLAYER_LOGIN")
local db = _G[ADDON .. "DB"]
local wishes = db.wishlists["Moi-Royaume"]
assert(wishes and wishes[1234] and db.wishlist == nil, "ancienne liste reprise par le premier personnage connecté")
wishes[1234] = nil
assert(db and db.pins and db.recorded, "base de réglages")
for _, dungeon in ipairs(NS.Dungeons) do
    for _, floor in ipairs(dungeon.floors) do
        local art = NS.Floors[floor]
        assert(art and #art > 0 and #art <= 12 and #art % (art.cols or 4) == 0, "tuiles de l'étage " .. floor)
    end
end

Fire("LOOT_OPENED")
assert(db.recorded[639][99999] and db.recorded[639][5193], "butin relevé sur VanCleef")

-- Réglages : la case de la minicarte cache le bouton ; /codex options ouvre le panneau.
assert(compartment and compartment.text == NS.L.TITLE and compartment.func, "entrée du compartiment d'addons")
SlashCmdList.AEONDUNGEONJOURNAL("options")
assert(optionsOpened == 7, "/codex options ouvre le panneau")
optionsPanel.scripts.OnShow(optionsPanel)
local minimapBox
for _, box in ipairs(frames) do
    if rawget(box, "Text") and box.Text.text == NS.L.OPT_MINIMAP then minimapBox = box end
end
assert(AeonDungeonJournalMinimapButton.shown, "bouton de la minicarte affiché par défaut")
minimapBox.scripts.OnClick(minimapBox)   -- GetChecked du mock rend nil : case décochée
assert(db.hideMinimap and not AeonDungeonJournalMinimapButton.shown, "case décochée : bouton de la minicarte caché")
db.hideMinimap = nil

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
-- Grille triée : conseillés (bordure dorée) d'abord, puis niveau minimum croissant. dungeonRows est ensuite
-- rangé dans l'ordre de NS.Dungeons pour la suite du test (niveau fixe à 20 : l'ordre ne bouge plus).
local gridCards, dungeonIndex, dungeonRows, upcoming = {}, {}, {}, 0
for i, dungeon in ipairs(NS.Dungeons) do dungeonIndex[dungeon] = i end
for _, button in ipairs(buttons) do
    if button.shown and rawget(button, "edges") and rawget(button, "levels") then gridCards[#gridCards + 1] = button end
end
for i, card in ipairs(gridCards) do
    dungeonRows[dungeonIndex[card.dungeon]] = card
    local previous = gridCards[i - 1]
    if previous then
        local gold, previousGold = card.edges[1].color[1] == 1, previous.edges[1].color[1] == 1
        assert(previousGold or not gold, "donjons conseillés en tête de grille")
        assert(gold ~= previousGold or previous.dungeon.levels[1] <= card.dungeon.levels[1], "grille triée par niveau minimum")
    end
end
for i, dungeon in ipairs(NS.Dungeons) do
    if dungeon.upcoming then
        upcoming = upcoming + 1
        assert(dungeonRows[i].text.text == dungeon.name and dungeonRows[i].levels.text:find(NS.L.UPCOMING, 1, true),
            "donjon annoncé : nom et badge, " .. dungeon.key)
    end
end
assert(#dungeonRows == #NS.Dungeons and #Visible("^Zone%d+") == #NS.Dungeons - upcoming and upcoming == 5,
    "34 donjons listés, dont 5 annoncés : " .. #dungeonRows)
-- Donjons conseillés : bordure dorée sur ceux dont la tranche contient le niveau du joueur (20), et eux seuls.
local advised = 0
for i, card in ipairs(dungeonRows) do
    local levels = NS.Dungeons[i].levels
    local expected = levels[1] <= 20 and 20 <= levels[3]
    assert((card.edges[1].color[1] == 1) == expected, "bordure du donjon " .. NS.Dungeons[i].key)
    if expected then advised = advised + 1 end
end
assert(advised > 0 and advised < #dungeonRows, "donjons conseillés : " .. advised)
db.hideUpcoming = true
Click(Visible("^" .. NS.L.HOME .. "$")[1])
local listed = 0
for _, card in ipairs(gridCards) do
    if card.shown then listed = listed + 1 end
    assert(not (card.shown and card.dungeon.upcoming), "donjon annoncé masqué")
end
assert(listed == #NS.Dungeons - upcoming, "option : donjons annoncés masqués")
db.hideUpcoming = nil
Click(Visible("^" .. NS.L.HOME .. "$")[1])
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
local function OpenTab(key)
    for _, tab in ipairs(tabs) do
        if tab.key == key then Click(tab) end
    end
end
local bossesSeen, lootRows, markedSeen, plainSeen, spellsSeen, notesSeen = 0, 0, 0, 0, 0, 0
for dungeonIndex, dungeonRow in ipairs(dungeonRows) do
    Click(dungeonRow)
    OpenTab("quests")
    local marked, plain = QuestMarks()
    markedSeen, plainSeen = markedSeen + marked, plainSeen + plain
    local bossRows = BossRows()
    assert(#bossRows > 0 or NS.Dungeons[dungeonIndex].upcoming, "boss listés pour " .. dungeonRow.text.text)
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
assert(bossesSeen == 252, "252 boss parcourus, vu " .. bossesSeen)
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
OpenTab("quests")
local markedBefore = QuestMarks()
Fire("QUEST_TURNED_IN", pending, 100, 0)
assert(QuestMarks() == markedBefore + 1, "quête cochée dès qu'elle est rendue")

-- Infobulle d'objet : donjon, boss et chance de butin ; masquée par /codex tooltip.
local function TooltipLines(itemID)
    local lines = {}
    local tooltip = { AddDoubleLine = function(_, left, right) lines[#lines + 1] = left .. " | " .. right end,
                      AddLine = function(_, text) lines[#lines + 1] = text end }
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

-- Partage dans le groupe : listes reçues dans l'infobulle, oubliées au départ du membre ; liste envoyée en morceaux.
local function HasLine(lines, text)
    for _, line in ipairs(lines) do if line == text then return true end end
    return false
end
local wishedByAmi = NS.L.WISHED_BY:format("Ami")
members.Ami = true
local sentBefore = #addonSent
Fire("CHAT_MSG_ADDON", "DCodexWish", "!5193", "PARTY", "Ami-Royaume")
assert(#addonSent == sentBefore + 1 and addonSent[#addonSent].text == "=" and addonSent[#addonSent].channel == "PARTY",
    "membre qui demande les listes : la sienne reçue, la nôtre (vide) renvoyée sans demande")
Fire("CHAT_MSG_ADDON", "DCodexWish", "+42", "PARTY", "Ami-Royaume")
Fire("CHAT_MSG_ADDON", "DCodexWish", "=5193", "PARTY", "Moi-Royaume")
Fire("CHAT_MSG_ADDON", "AutrePrefixe", "=5193", "PARTY", "Autre-Royaume")
Fire("CHAT_MSG_ADDON", "DCodexWish", "=5193", "GUILD", "Guilde-Royaume")
Fire("CHAT_MSG_ADDON", "DCodexWish", "=5193", "PARTY", "Inconnu-Royaume")
assert(HasLine(TooltipLines(5193), wishedByAmi), "objet souhaité par un membre : nommé dans l'infobulle")
assert(#NS.WishedBy(42) == 1 and #NS.WishedBy(5193) == 1, "suite ajoutée ; soi, autre préfixe, guilde et non-membre ignorés")
members.Ami = nil
Fire("GROUP_ROSTER_UPDATE")
assert(#addonSent == sentBefore + 1 and #NS.WishedBy(5193) == 0, "membre parti : sa liste oubliée, rien renvoyé")
inGroup = false
Fire("GROUP_ROSTER_UPDATE")
inGroup = true
Fire("GROUP_ROSTER_UPDATE")
assert(#addonSent == sentBefore + 2 and addonSent[#addonSent].text == "!", "entrée dans un groupe : liste envoyée avec demande")
for id = 100000, 100059 do wishes[id] = true end
addonResults = { 3 }
sentBefore = #addonSent
NS.ShareWishes()
local parts = {}
for i = sentBefore + 1, #addonSent do parts[#parts + 1] = addonSent[i].text end
assert(parts[1]:find("^=") and #parts >= 3 and parts[2]:find("^=") and parts[#parts]:find("^%+"),
    "limite de débit : liste renvoyée en entier, en plusieurs messages")
for _, part in ipairs(parts) do assert(#part <= 255, "message d'addon de 255 octets au plus") end
for id = 100000, 100059 do wishes[id] = nil end

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
    if candidate.scripts.OnTextChanged and candidate.width == 160 then searchBox = candidate end
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
assert(#kinds == 4 and kinds[2].text == NS.L.MY_CLASS and kinds[3].text == "Cuir" and kinds[4].text == "Tissu",
    "choix du menu des types, « ma classe » en tête")
kinds[2].setSelected(kinds[2].data)
local mageHeads = LootRows()
assert(#mageHeads > 0 and #mageHeads < #headRows, "filtre de classe : " .. #mageHeads .. " / " .. #headRows)
for _, row in ipairs(mageHeads) do assert(row.slot.text == "Tête, Tissu", "mage : tissu seulement, vu " .. row.slot.text) end
kinds[3].setSelected(kinds[3].data)
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
assert(wishes[5202] and Starred(LootRows()) == 1, "objet ajouté à la liste de souhaits")
assert(Starred(BossRows()) >= 1, "étoile sur le boss")
Click(Visible("^" .. NS.L.HOME .. "$")[1])
assert(#Visible("^|TInterface.*Zone36") == 1 and #Visible("^|TInterface.*Zone%d+") == 1, "étoile sur le donjon, et lui seul")
loot[#loot + 1] = { link = "|Hitem:5202|h", quality = 3, guid = "Creature-0-1-2-3-639-0000" }
local printedBefore = #printed
Fire("LOOT_OPENED")
assert(#printed == printedBefore + 1 and printed[#printed]:find("item:5202", 1, true), "alerte quand l'objet tombe")
Fire("LOOT_OPENED")
Fire("START_LOOT_ROLL", 1, 60)
Fire("ENCOUNTER_LOOT_RECEIVED", 1, 5202, "|Hitem:5202|h", 1, "Objet5202", "Joueur")
Fire("CHAT_MSG_LOOT", "Joueur reçoit le butin : |Hitem:5202|h.")
assert(#printed == printedBefore + 1, "une seule alerte par objet en 3 minutes, tous signaux confondus")
now = now + 200
Fire("CHAT_MSG_LOOT", "Joueur reçoit le butin : |cff0070dd|Hitem:5202::::|h[Objet5202]|h|r.")
assert(#printed == printedBefore + 2 and printed[#printed]:find("item:5202", 1, true),
    "alerte du message de butin à lien coloré, le délai passé")
now = now + 200
Fire("START_LOOT_ROLL", 1, 60)
assert(#printed == printedBefore + 3 and printed[#printed]:find("item:5202", 1, true), "alerte au jet de groupe")
printedBefore = printedBefore + 1
SlashCmdList.AEONDUNGEONJOURNAL("wishlist")
assert(#printed == printedBefore + 3 and printed[#printed]:find("5202", 1, true), "/codex wishlist liste l'objet")
printedBefore = printedBefore + 1
equipped[1] = "|Hitem:5202|h"
Click(Visible(NS.L.WISHLIST .. "$")[1])
local wishRow, headerRow
for _, row in ipairs(LootRows()) do
    if row.text.text == "Objet5202" and tostring(row.slot.text):find("^Zone36, ") then wishRow = row end
    if row.text.text == NS.L.EQUIPPED:format("Objet5202") and row.slot.text == "Tête" then headerRow = row end
end
assert(wishRow, "bouton liste de souhaits : l'objet, son donjon et son boss")
assert(headerRow, "liste rangée par emplacement : objet porté en tête du groupe")
assert(tostring(wishRow.source.text):find(NS.L.OBTAINED, 1, true), "objet porté : marqué obtenu")
equipped[1] = nil
Fire("PLAYER_EQUIPMENT_CHANGED", 1, false)
assert(not tostring(wishRow.source.text):find(NS.L.OBTAINED, 1, true), "objet retiré : plus marqué obtenu")
wishRow.scripts.OnClick(wishRow, "LeftButton")
assert(#Visible("^Zone36$") == 1, "clic sur l'objet : ouvre son donjon")
OpenDeadminesLoot()
wished = LootRow("Objet5202")
wished.scripts.OnClick(wished, "RightButton")
assert(wishes[5202] == nil and Starred(LootRows()) == 0 and Starred(BossRows()) == 0, "objet retiré de la liste")
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
OpenTab("quests")
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
    if dungeon.instance ~= 36 and dungeon.bosses[1] and dungeon.bosses[1].npc then elsewhere = elsewhere or dungeon.bosses[1].npc end
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

-- Recherche dans tout le butin, depuis l'accueil : casse et accents ignorés, latin et cyrillique.
local homeSearch
for _, candidate in ipairs(frames) do
    if candidate.scripts.OnTextChanged and candidate.width == 180 then homeSearch = candidate end
end
local realItemInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id)
    if id == 5202 then return "Épée Ёлка", "|Hitem:5202|h", 3 end
    return realItemInfo(id)
end
local function HomeSearch(text)
    homeSearch.text = text
    homeSearch.scripts.OnTextChanged(homeSearch)
    local found = {}
    for _, row in ipairs(LootRows()) do
        if tostring(row.text.text):find("Épée", 1, true) and tostring(row.slot.text):find("^Zone%d+, ") then
            found[#found + 1] = row
        end
    end
    return found
end
assert(#HomeSearch("É") == 0, "un seul caractère : pas de recherche")
local hits = HomeSearch("EPEE")
assert(#hits >= 1 and tostring(hits[1].slot.text):find("^Zone36, "), "recherche sans accent : " .. #hits)
assert(#HomeSearch("ЁЛКА") == #hits, "recherche en cyrillique majuscule")
hits[1].scripts.OnClick(hits[1], "RightButton")
assert(wishes[5202], "clic droit sur un résultat : liste de souhaits")
local wishLines = TooltipLines(5202)
assert(wishLines[1] == NS.WISH_MARK .. NS.L.WISHLIST, "infobulle : objet de la liste de souhaits")
hits[1].scripts.OnClick(hits[1], "LeftButton")
assert(homeSearch.text == "" and #Visible("^Zone36$") == 1, "clic sur un résultat : recherche vidée, boss ouvert")
C_Item.GetItemInfo = realItemInfo

-- Prérequis et objets à rapporter sous la quête.
local prereq, withPre = NS.L.PREREQ:match("^(.-)%%s"), nil
for i, dungeon in ipairs(NS.Dungeons) do
    for _, quest in ipairs(dungeon.quests) do
        if quest.pre and quest.side ~= "h" then withPre = withPre or i end
    end
end
Click(dungeonRows[withPre])
OpenTab("quests")
local prereqShown = false
for _, row in ipairs(frames) do
    local need = rawget(row, "need")
    if row.shown and type(need) == "table" and tostring(need.text):find(prereq, 1, true) then prereqShown = true end
end
assert(prereqShown, "prérequis affiché pour " .. NS.Dungeons[withPre].key)

-- Point de route sur l'entrée du donjon.
local waypoint
C_Map = { CanSetUserWaypointOnMap = function() return true end, SetUserWaypoint = function(point) waypoint = point end }
UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { map = map, x = x, y = y } end }
Click(dungeonRows[deadmines])
local entrance = NS.Dungeons[deadmines].entrance
local waypointButton = Visible("^" .. NS.L.WAYPOINT .. "$")[1]
assert(entrance and waypointButton, "bouton de point de route sur un donjon qui a une entrée")
Click(waypointButton)
assert(waypoint and waypoint.map == entrance.map and waypoint.x == entrance.x, "point de route posé sur l'entrée")

-- Zone du donneur de quête : nom de la carte donné par le client.
C_Map.GetMapInfo = function(map) return { name = "Carte" .. map } end
Click(dungeonRows[withPre])
OpenTab("quests")
local zoneShown = false
for _, row in ipairs(frames) do
    local giver = rawget(row, "giver")
    if row.shown and type(giver) == "table" and tostring(giver.text):find(", Carte14%d%d$") then zoneShown = true end
end
assert(zoneShown, "zone de quête traduite par le client")

-- Quête sans donneur lancée par un objet : nom de l'objet à la place du donneur.
local withItem, startItem
for index, dungeon in ipairs(NS.Dungeons) do
    for _, quest in ipairs(dungeon.quests or {}) do
        if not withItem and quest.startItem and not quest.giver and not quest.side and quest.startItem % 2 == 0 then
            withItem, startItem = index, quest.startItem
        end
    end
end
assert(withItem, "une quête neutre lancée par un objet")
Click(dungeonRows[withItem])
OpenTab("quests")
local itemShown = false
for _, row in ipairs(frames) do
    local giver = rawget(row, "giver")
    if row.shown and type(giver) == "table" and tostring(giver.text) == NS.L.QUEST_ITEM:format("Objet" .. startItem) then
        itemShown = true
    end
end
assert(itemShown, "objet qui lance la quête affiché")

-- Rappel de la liste de souhaits à l'entrée du donjon, une fois par entrée.
printedBefore = #printed
Fire("PLAYER_ENTERING_WORLD")
assert(#printed > printedBefore and printed[printedBefore + 1]:find(NS.L.MSG_WISH_HERE:match("^(.-)%%s"), 1, true),
    "rappel des objets voulus du donjon")
printedBefore = #printed
Fire("PLAYER_ENTERING_WORLD")
assert(#printed == printedBefore, "pas de second rappel dans le même donjon")
-- Objet voulu pas encore chargé (id impair dans le mock) : rappel différé jusqu'à GET_ITEM_INFO_RECEIVED.
local unloaded
for _, boss in ipairs(NS.Dungeons[deadmines].bosses) do
    for _, itemID in ipairs(boss.items or {}) do
        if itemID % 2 == 1 then unloaded = unloaded or itemID end
    end
end
assert(unloaded, "objet impair dans les Mortemines")
local inDeadmines = GetInstanceInfo
GetInstanceInfo = function() return "Elwynn", "none", 0, "", 0, 0, false, 0 end
Fire("PLAYER_ENTERING_WORLD")
GetInstanceInfo = inDeadmines
wishes[unloaded] = true
printedBefore = #printed
Fire("PLAYER_ENTERING_WORLD")
assert(#printed == printedBefore, "objet non chargé : rappel en attente")
local loadedInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id) return "Objet" .. id, "|Hitem:" .. id .. "|h", 3 end
Fire("GET_ITEM_INFO_RECEIVED", unloaded, true)
C_Item.GetItemInfo = loadedInfo
assert(#printed > printedBefore and table.concat(printed, "\n", printedBefore + 1):find("|Hitem:" .. unloaded .. "|h", 1, true), "rappel une fois l'objet chargé")
slash("clearwishlist")
assert(next(wishes) == nil and printed[#printed]:find(NS.L.MSG_WISHLIST_CLEARED, 1, true), "/codex clearwishlist")

-- Fin de rencontre : boss coché par son nom ; rencontre ratée ignorée.
slash("resetkills")
assert(next(db.kills) == nil and printed[#printed]:find(NS.L.MSG_KILLS_RESET, 1, true), "/codex resetkills")
Fire("ENCOUNTER_END", 1, byName.name, 1, 5, 0)
assert(next(db.kills) == nil, "rencontre ratée : rien de coché")
Fire("ENCOUNTER_END", 1, byName.name, 1, 5, 1)
assert(db.kills[byName.npc], "rencontre réussie : boss coché")

-- Message système de réinitialisation : coches effacées ; autre message : rien.
Fire("CHAT_MSG_SYSTEM", "Vous avez rejoint le groupe.")
assert(db.kills[byName.npc], "autre message système : coches gardées")
Fire("CHAT_MSG_SYSTEM", "The Deadmines has been reset.")
assert(next(db.kills) == nil, "instance réinitialisée : coches effacées")

-- Boss inconnu de Data.lua, dans un donjon bêta : rencontre puis butin d'une créature inconnue, relevés.
local realInstance = GetInstanceInfo
local excavation
for _, dungeon in ipairs(NS.Dungeons) do
    if dungeon.key == "ExcavationSite" then excavation = dungeon end
end
GetInstanceInfo = function() return "Excavation", "party", 1, "", 5, 0, false, excavation.instance end
local bossCount = #excavation.bosses
-- Client allemand : un boss sans nom deDE, la rencontre ne se compare pas ; le butin du npc connu n'ajoute pas de doublon.
local firstNames = excavation.bosses[1].names
excavation.bosses[1].names = nil
GetLocale = function() return "deDE" end
Fire("ENCOUNTER_END", 776, "Salzstachel", 1, 5, 1)
loot = { { link = "|Hitem:123455|h", quality = 3, guid = "Creature-0-1-2-3-" .. excavation.bosses[1].npc .. "-0000" } }
Fire("LOOT_OPENED")
assert(db.found[excavation.instance] == nil and #excavation.bosses == bossCount, "deDE : aucun doublon de boss")
Fire("ENCOUNTER_END", 776, "Salzstachel", 1, 5, 1)
loot = { { link = "|Hitem:123454|h", quality = 3, guid = "Creature-0-1-2-3-44444-0000" } }
Fire("LOOT_OPENED")
assert(db.found[excavation.instance] == nil and #excavation.bosses == bossCount, "deDE : butin d'un trash, aucun doublon")
excavation.bosses[1].names = firstNames
GetLocale = function() return "esMX" end
local spanish = { npc = 1, name = "Saltspine", names = { esES = "Espinasal" } }
assert(NS.BossName(spanish) == "Espinasal", "esMX : nom de boss repris d'esES")
-- esMX : le repli esES n'est pas une traduction sûre, la rencontre au nom différent reste ignorée.
Fire("ENCOUNTER_END", 776, "Espina de sal", 1, 5, 1)
loot = { { link = "|Hitem:123453|h", quality = 3, guid = "Creature-0-1-2-3-44444-0000" } }
Fire("LOOT_OPENED")
assert(db.found[excavation.instance] == nil and #excavation.bosses == bossCount, "esMX : butin d'un trash, aucun doublon")
GetLocale = function() return "frFR" end
Fire("ENCOUNTER_END", 777, "Nouveau boss", 1, 5, 1)
loot = { { link = "|Hitem:123456|h", quality = 3, guid = "Creature-0-1-2-3-55555-0000" } }
Fire("LOOT_OPENED")
local found = db.found[excavation.instance]
assert(found and found.encounters[777] and found.encounters[777].npc == 55555, "boss inconnu relevé dans db.found")
assert(db.recorded.e777 and db.recorded.e777[123456], "butin du boss inconnu relevé")
assert(#excavation.bosses == bossCount + 1 and excavation.bosses[bossCount + 1].name == "Nouveau boss", "boss ajouté au donjon")
local recordedLines = TooltipLines(123456)
assert(#recordedLines == 1 and recordedLines[1]:find(NS.L.RECORDED, 1, true), "infobulle : source vue en jeu")
slash("resetkills")
Died(55555)
assert(db.kills["Nouveau boss"], "run suivant : mort du boss relevé reconnue")
GetInstanceInfo = realInstance   -- Deadmines, donjon vérifié : pas de boss en plus
Fire("ENCOUNTER_END", 778, "Pas un boss", 1, 5, 1)
loot = { { link = "|Hitem:123457|h", quality = 3, guid = "Creature-0-1-2-3-66666-0000" } }
Fire("LOOT_OPENED")
assert(db.found[36] == nil and db.recorded[66666] == nil, "donjon vérifié : aucun boss ajouté")

-- Carte : traits reçus d'un membre, dessinés, partagés par tranches, effacés ; zoom autour du curseur, déplacement.
local viewport, canvas, drawButton, clearButton
for _, candidate in ipairs(frames) do
    if candidate.scripts.OnMouseWheel and candidate.scripts.OnMouseDown then viewport = candidate end
    if candidate.text == NS.L.DRAW then drawButton = candidate end
    if candidate.text == NS.L.CLEAR_DRAWING then clearButton = candidate end
end
for _, candidate in ipairs(frames) do
    if candidate.parent == viewport then canvas = candidate end
end
assert(viewport and canvas and drawButton and clearButton, "vue, carte et boutons de dessin")
local lines, lastPoint = {}, nil
rawset(canvas, "CreateLine", function() local line = Region() lines[#lines + 1] = line return line end)
rawset(canvas, "SetPoint", function(_, _, _, _, x, y) lastPoint = { x, y } end)
local function ShownLines()
    local count = 0
    for _, line in ipairs(lines) do if line.shown then count = count + 1 end end
    return count
end
local mapDungeon
for index, dungeon in ipairs(NS.Dungeons) do
    if #dungeon.floors > 1 and not mapDungeon then mapDungeon = index end
end
Click(dungeonRows[mapDungeon])
OpenTab("map")
local floor = NS.Dungeons[mapDungeon].floors[1]
members.Ami = true
Fire("CHAT_MSG_ADDON", "DCodexDraw", "S" .. floor .. ":000000500500999999", "PARTY", "Ami-Royaume")
assert(ShownLines() == 2, "trait reçu d'un membre : 2 segments")
Fire("CHAT_MSG_ADDON", "DCodexDraw", "S" .. floor .. ":000000999999", "PARTY", "Inconnu-Royaume")
Fire("CHAT_MSG_ADDON", "DCodexDraw", "S999999:000000999999", "PARTY", "Ami-Royaume")
Fire("CHAT_MSG_ADDON", "DCodexDraw", "S" .. floor .. ":00000099999", "PARTY", "Ami-Royaume")
assert(ShownLines() == 2, "non-membre, étage inconnu, message tronqué : ignorés")
sentBefore = #addonSent
Click(drawButton)
cursorX, cursorY, mouseDown = 110, 300, true   -- carte de 540 px : pas de 5 px, au-dessus du minimum
viewport.scripts.OnMouseDown(viewport, "LeftButton")
for step = 1, 99 do
    cursorX, cursorY = 110 + 4 * step, 300 + step
    viewport.scripts.OnUpdate(viewport)
end
mouseDown = false
viewport.scripts.OnUpdate(viewport)
assert(viewport.scripts.OnUpdate == nil, "bouton relâché : geste terminé")
assert(ShownLines() == 2 + 99, "trait dessiné : 99 segments")
local drawn = {}
for i = sentBefore + 1, #addonSent do
    assert(addonSent[i].prefix == "DCodexDraw" and #addonSent[i].text <= 255, "tranche sous 255 octets")
    drawn[#drawn + 1] = addonSent[i].text
end
assert(#drawn == 3 and drawn[1]:sub(-6) == drawn[2]:sub(#("S" .. floor .. ":") + 1, #("S" .. floor .. ":") + 6),
    "100 points en 3 tranches raccordées")
Click(drawButton)
Click(clearButton)
assert(ShownLines() == 0 and addonSent[#addonSent].text == "C" .. floor, "effacer : traits cachés, effacement partagé")
Fire("CHAT_MSG_ADDON", "DCodexDraw", "S" .. floor .. ":000000999999", "PARTY", "Ami-Royaume")
Fire("CHAT_MSG_ADDON", "DCodexDraw", "C" .. floor, "PARTY", "Ami-Royaume")
assert(ShownLines() == 0, "effacement reçu d'un membre")
cursorX, cursorY = 300, 300   -- vue à (100, 500) : curseur en (200, 200) dans la vue
viewport.scripts.OnMouseWheel(viewport, 1)
assert(math.abs(lastPoint[1] - 200 * (1 - 1.25) / 1.25) < 1e-6 and math.abs(lastPoint[2] - 200 * 0.25 / 1.25) < 1e-6,
    "zoom : le point sous le curseur reste")
for _ = 1, 20 do viewport.scripts.OnMouseWheel(viewport, 1) end
local width, height = canvas:GetWidth(), canvas:GetHeight()
mouseDown = true
viewport.scripts.OnMouseDown(viewport, "LeftButton")
cursorX, cursorY = 300 + 10000, 300 - 10000
viewport.scripts.OnUpdate(viewport)
assert(math.abs(lastPoint[1] - 0) < 1e-6 and math.abs(lastPoint[2] - 0) < 1e-6, "déplacement borné au coin haut gauche")
cursorX, cursorY = 300 - 10000, 300 + 10000
viewport.scripts.OnUpdate(viewport)
assert(math.abs(lastPoint[1] - width * (1 - 4) / 4) < 1e-6 and math.abs(lastPoint[2] - height * 3 / 4) < 1e-6,
    "zoom borné à 4, déplacement borné au coin bas droit")
mouseDown = false
viewport.scripts.OnUpdate(viewport)
Click(dungeonRows[mapDungeon == 1 and 2 or 1])
OpenTab("map")
assert(lastPoint[1] == 0 and lastPoint[2] == 0, "autre étage : zoom remis à 1")
slash("resetpins")
slash("wipe")
assert(next(db.recorded) == nil, "butin oublié")
slash("")
assert(not frame:IsShown(), "fenêtre fermée")
print("smoke ok")
