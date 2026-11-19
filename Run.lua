-- Run.lua
-- Suivi de run dans le donjon (boss tués, prochain boss et son conseil, souhaits encore possibles), préparation
-- avant le run (/codex prep), valeur d'un donjon pour le personnage (/codex value), taux de butin observé, et relevé
-- en jeu étendu (niveaux des boss, quêtes absentes du serveur). Chargé après Loot.lua, reprend Journal.lua par NS.
local _, NS = ...
local L = NS.L

local isSecret = _G.issecretvalue or function(_) return false end
local Print, BossName, DungeonName = NS.Print, NS.BossName, NS.DungeonName
local ItemInfo, BossItems, RecordKey, IsWished = NS.ItemInfo, NS.BossItems, NS.RecordKey, NS.IsWished
local CurrentDungeon, IsKilled, Tactic = NS.CurrentDungeon, NS.IsKilled, NS.Tactic
local HUD_WIDTH, ROW_HEIGHT, MAX_WISH_LINES = 230, 16, 4

--------------------------------------------------------------------------------
-- Taux de butin observé : db.bossKills[clé du boss] = kills, db.drops[itemID] = { count, run, first }
--------------------------------------------------------------------------------

--- Butin d'un boss connu vu tomber : compté une fois par run. `first` : kills du boss au premier butin.
function NS.CountDrop(itemID, boss)
    local db = NS.db
    local drop = db.drops[itemID] or {}
    db.drops[itemID] = drop
    local run = db.killsStart or db.killsAt   -- coches d'avant 1.5 : début du run inconnu, dernier kill en repli
    if drop.run == run then return end
    drop.count, drop.run = (drop.count or 0) + 1, run
    drop.first = drop.first or db.bossKills[RecordKey(boss)]
end

--- « vu 2/7 » : runs où l'objet est tombé sur kills relevés du boss. Aucun kill relevé : nil.
function NS.DropStats(itemID, boss)
    local kills = boss and NS.db.bossKills[RecordKey(boss)]
    if not kills or kills == 0 then return nil end
    local drop = NS.db.drops[itemID]
    return L.OBSERVED:format(drop and drop.count or 0, kills)
end

--------------------------------------------------------------------------------
-- Gain de niveau d'objet sur l'équipement porté
--------------------------------------------------------------------------------

-- Emplacements d'équipement par equipLoc ; deux emplacements : le plus faible est remplacé.
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 },
    INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
    INVTYPE_RELIC = { 18 },
}

-- Classes qui manient deux armes (Ambidextrie) : les autres ne portent une arme à une main qu'en main droite.
-- ponytail: classe seule, sans le niveau d'apprentissage (10 voleur, 20 guerrier et chasseur).
local DUAL_WIELD = { WARRIOR = true, ROGUE = true, HUNTER = true }

local function ItemLevel(item)
    local level = C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(item)
    return type(level) == "number" and not isSecret(level) and level or nil
end

--- Niveaux d'objet gagnés en le portant à la place de la pièce la plus faible de son emplacement. Objet non
--- équipable par la classe : nil. Objet ou pièce portée dont le niveau est illisible (pas encore chargé) : nil, true.
-- ponytail: niveau d'objet comme seul critère, sans poids de stats ; pondérer par classe si les joueurs le demandent.
function NS.ItemGain(itemID)
    if not (C_Item and C_Item.GetItemInfoInstant) or not NS.UsableByClass(itemID) then return nil end
    local slots = SLOTS[select(4, C_Item.GetItemInfoInstant(itemID)) or ""]
    if not slots then return nil end
    local classFile = _G.UnitClass and select(2, UnitClass("player"))
    if #slots == 2 and slots[2] == 17 and not (type(classFile) == "string" and not isSecret(classFile) and DUAL_WIELD[classFile]) then
        slots = { 16 }
    end
    local level = ItemLevel(itemID)
    if not level then return nil, true end
    local worst
    for _, slot in ipairs(slots) do
        local link = _G.GetInventoryItemLink and GetInventoryItemLink("player", slot)
        if link == nil and slot == 17 then   -- main gauche vide sous une arme à deux mains : c'est elle qui est remplacée
            local main = GetInventoryItemLink("player", 16)
            if type(main) == "string" and not isSecret(main)
                and select(4, C_Item.GetItemInfoInstant(main)) == "INVTYPE_2HWEAPON" then link = main end
        end
        local equipped = 0   -- emplacement vide
        if link ~= nil then
            equipped = type(link) == "string" and not isSecret(link) and ItemLevel(link)
            if not equipped then return nil, true end
        end
        worst = math.min(worst or equipped, equipped)
    end
    return level - worst
end

--- Niveaux d'objet attendus par run : somme de gain × chance sur les boss du donjon. Rend aussi le meilleur objet.
--- Objets au niveau illisible : chargement demandé, comptés dans `pending`.
local function DungeonValue(dungeon, pending)
    local total, best, bestScore = 0, nil, 0
    for _, boss in ipairs(dungeon.bosses) do
        for itemID, chance in pairs(boss.drops or {}) do
            local gain, unknown = NS.ItemGain(itemID)
            if unknown then
                pending.count = pending.count + 1
                if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
            end
            local score = gain and gain > 0 and (tonumber(chance) or 0) / 100 * gain or 0
            total = total + score
            if score > bestScore then best, bestScore = { id = itemID, gain = gain, chance = chance }, score end
        end
    end
    return total, best
end

local function ShowValues()
    local ranked, pending = {}, { count = 0 }
    for _, dungeon in ipairs(NS.Dungeons) do
        if not dungeon.upcoming then
            local value, best = DungeonValue(dungeon, pending)
            if value > 0 then ranked[#ranked + 1] = { dungeon = dungeon, value = value, best = best } end
        end
    end
    table.sort(ranked, function(a, b) return a.value > b.value end)
    for i = 1, math.min(#ranked, 10) do
        local entry = ranked[i]
        local name, link = ItemInfo(entry.best.id)
        Print(L.VALUE_LINE:format(DungeonName(entry.dungeon), entry.value, link or name or "item:" .. entry.best.id,
            entry.best.gain, tostring(entry.best.chance)))
    end
    if pending.count > 0 then
        Print(L.VALUE_PENDING:format(pending.count))
    elseif #ranked == 0 then
        Print(L.VALUE_NONE)
    end
end

--------------------------------------------------------------------------------
-- Préparation avant le run
--------------------------------------------------------------------------------

local function ShowPreparation()
    local dungeon = CurrentDungeon() or NS.current.dungeon
    if not dungeon then Print(L.PREP_NO_DUNGEON) return end
    local faction = _G.UnitFactionGroup and UnitFactionGroup("player")
    local other = faction == "Alliance" and "h" or faction == "Horde" and "a"
    local level = _G.UnitLevel and UnitLevel("player")
    if isSecret(level) or type(level) ~= "number" then level = nil end
    local lines, locked = {}, 0
    for _, quest in ipairs(dungeon.quests or {}) do
        if not (other and quest.side == other) and not NS.db.missingQuests[quest.id] and not NS.QuestDone(quest) then
            local ready = not (level and quest.min and level < quest.min)
            for _, previous in ipairs(quest.pre or {}) do
                ready = ready and (NS.QuestDone(previous) or NS.db.missingQuests[previous.id])
            end
            local title = NS.QuestTitle(quest)
            if C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(quest.id) then
                lines[#lines + 1] = L.PREP_ACTIVE:format(title)
            elseif not ready then
                locked = locked + 1
            elseif quest.startItem then
                local name, link = ItemInfo(quest.startItem)
                local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(quest.startItem) or 0
                lines[#lines + 1] = L.PREP_ITEM:format(title, link or name or "item:" .. quest.startItem,
                    (not isSecret(count) and count > 0) and L.PREP_IN_BAGS or "")
            else
                lines[#lines + 1] = L.PREP_TAKE:format(title, (quest.giver or "?") .. (quest.zone and ", " .. quest.zone or ""))
            end
        end
    end
    Print(L.PREP_TITLE:format(DungeonName(dungeon)))
    for _, line in ipairs(lines) do Print(line) end
    if locked > 0 then Print(L.PREP_LOCKED:format(locked)) end
    if #lines == 0 and locked == 0 then Print(L.PREP_NOTHING) end
    NS.CheckQuests(dungeon.quests or {})
end

--------------------------------------------------------------------------------
-- Suivi de run : cadre déplaçable, affiché dans un donjon connu
--------------------------------------------------------------------------------

local hud, rows = nil, {}

--- Note du boss, puis une ligne par capacité, comme l'envoi au groupe.
local function ShowTactic(boss)
    local note = Tactic(boss).note
    local hasNote = type(note) == "string" and note ~= ""
    if hasNote then Print(BossName(boss) .. " : " .. note) end
    for index, ability in ipairs(boss.abilities or {}) do
        local name, text = NS.AbilityTexts(boss, index, ability)
        if text and text ~= "" then Print((name or "?") .. " : " .. text) hasNote = true end
    end
    if not hasNote then Print(L.HUD_NO_TIP:format(BossName(boss))) end
end

local function HudRow(index)
    local row = rows[index]
    if row then return row end
    row = CreateFrame("Button", nil, hud)
    row:SetSize(HUD_WIDTH - 16, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 8, -8 - index * ROW_HEIGHT)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetAllPoints()
    row.text:SetJustifyH("LEFT")
    row:SetScript("OnClick", function(self)
        if not self.boss then return end
        if IsShiftKeyDown() then NS.OpenBoss(self.boss) else ShowTactic(self.boss) end
    end)
    row:SetScript("OnEnter", function(self)
        if not self.boss then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(BossName(self.boss))
        GameTooltip:AddLine(L.HUD_HINT, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    rows[index] = row
    return row
end

local function CreateHud()
    hud = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    hud:SetSize(HUD_WIDTH, 60)
    hud:SetFrameStrata("MEDIUM")
    hud:SetClampedToScreen(true)
    hud:SetMovable(true)
    hud:EnableMouse(true)
    hud:RegisterForDrag("LeftButton")
    if hud.SetBackdrop then
        hud:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        hud:SetBackdropColor(0, 0, 0, 0.7)
    end
    local point = NS.db.hudPoint
    if point then hud:SetPoint(point[1], UIParent, point[1], point[2], point[3]) else hud:SetPoint("RIGHT", -40, 120) end
    hud:SetScript("OnDragStart", hud.StartMoving)
    hud:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local anchor, _, _, x, y = self:GetPoint()
        NS.db.hudPoint = { anchor, math.floor(x + 0.5), math.floor(y + 0.5) }
    end)
    hud.title = hud:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hud.title:SetPoint("TOPLEFT", 8, -8)
    hud.title:SetWidth(HUD_WIDTH - 16)
    hud.title:SetJustifyH("LEFT")
end

--- Redessine le suivi : boss du donjon (coche, prochain en or), puis objets voulus des boss pas encore tués.
function NS.UpdateRunHud()
    if not NS.db then return end
    local dungeon = not NS.db.hideHud and CurrentDungeon()
    if not dungeon then
        if hud then hud:Hide() end
        return
    end
    if not hud then CreateHud() end
    local killed, total, nextBoss, used = 0, 0, nil, 0
    for _, boss in ipairs(dungeon.bosses) do
      if boss.npc or boss.encounter then   -- listes annexes (trash, coffres, livres) : pas un boss à tuer
        used, total = used + 1, total + 1
        local row = HudRow(used)
        row.boss = boss
        local dead = IsKilled(boss)
        if dead then
            killed = killed + 1
            row.text:SetText(NS.DONE_MARK .. "|cff808080" .. BossName(boss) .. "|r")
        elseif not nextBoss and not boss.rare then
            nextBoss = boss
            row.text:SetText("|cffffd100> " .. BossName(boss) .. "|r")
        else
            row.text:SetText(BossName(boss))
        end
        row:Show()
      end
    end
    local wishes = {}
    hud.namesPending = nil
    for _, boss in ipairs(dungeon.bosses) do
        if not IsKilled(boss) then
            for _, item in ipairs(BossItems(boss)) do
                if IsWished(item.id) then
                    local name, link = ItemInfo(item.id)
                    if not (link or name) then hud.namesPending = true end   -- redessiné à GET_ITEM_INFO_RECEIVED
                    wishes[#wishes + 1] = (link or name or "...") .. " - " .. BossName(boss)
                end
            end
        end
    end
    if #wishes > 0 then
        used = used + 1
        local header = HudRow(used)
        header.boss = nil
        header.text:SetText(L.HUD_WISHES)
        header:Show()
        for i = 1, math.min(#wishes, MAX_WISH_LINES) do
            used = used + 1
            local row = HudRow(used)
            row.boss = nil
            row.text:SetText(wishes[i])
            row:Show()
        end
    end
    for i = used + 1, #rows do rows[i]:Hide() end
    hud.title:SetText(DungeonName(dungeon) .. "  " .. killed .. "/" .. total)
    hud:SetHeight(16 + (used + 1) * ROW_HEIGHT)
    hud:Show()
end

--------------------------------------------------------------------------------
-- Relevé étendu : niveaux des boss ciblés, quêtes que le serveur ne connaît pas
--------------------------------------------------------------------------------

--- Niveau d'un boss ciblé ou survolé, relevé dans db.bossLevels[npcID]. GUID ou niveau secret : rien.
-- ponytail: GUID des créatures probablement secret en instance (identité restreinte) : relevé peut-être vide
-- dans les donjons, à vérifier en jeu (/dump UnitGUID("target") sur un boss).
local function RecordBossLevel(unit)
    local guid = _G.UnitGUID and UnitGUID(unit)
    if type(guid) ~= "string" or isSecret(guid) then return end
    local kind, _, _, _, _, npcID = strsplit("-", guid)
    npcID = kind == "Creature" and tonumber(npcID)
    if not (npcID and NS.BossByNpc[npcID]) then return end
    local level = UnitLevel(unit)
    if type(level) == "number" and not isSecret(level) and level > 0 then NS.db.bossLevels[npcID] = level end
end

--- Demande au serveur les quêtes pas encore demandées pendant la session. Réponse : QUEST_DATA_LOAD_RESULT.
local requested, events = {}, CreateFrame("Frame")
local hasQuestEvent = pcall(events.RegisterEvent, events, "QUEST_DATA_LOAD_RESULT")
function NS.CheckQuests(quests)
    if not (hasQuestEvent and C_QuestLog and C_QuestLog.RequestLoadQuestByID) then return end
    for _, quest in ipairs(quests) do
        if not requested[quest.id] then
            requested[quest.id] = true
            C_QuestLog.RequestLoadQuestByID(quest.id)
        end
    end
end

--- Commandes de ce fichier. Rend vrai si la commande est traitée.
function NS.RunCommand(message)
    if message == "hud" then
        NS.db.hideHud = not NS.db.hideHud or nil
        Print(NS.db.hideHud and L.MSG_HUD_OFF or L.MSG_HUD_ON)
        NS.UpdateRunHud()
    elseif message == "prep" then
        ShowPreparation()
    elseif message == "value" then
        ShowValues()
    else
        return false
    end
    return true
end

--- Niveaux de la recherche de groupe du client (activité relevée dans Data.lua) ; sinon ceux de Data.lua restent.
local function ReadActivityLevels()
    if not (C_LFGList and C_LFGList.GetActivityInfoTable) then return end
    for _, dungeon in ipairs(NS.Dungeons) do
        if dungeon.activity then
            local ok, info = pcall(C_LFGList.GetActivityInfoTable, dungeon.activity)
            local low, high = ok and type(info) == "table" and info.minLevel, ok and type(info) == "table" and info.maxLevelSuggestion
            if type(low) == "number" and type(high) == "number" and not isSecret(low) and not isSecret(high)
                and low > 0 and high >= low then
                dungeon.levels = { low, low, high }
            end
        end
    end
end

--- Relevé d'entrée : dernière position en extérieur, rangée dans db.entrances[clé] à l'entrée du donjon si elle
-- est récente et proche d'une entrée connue (pierre de rencontre, téléportation : position sans rapport, écartée).
local lastOutside, positionTicker   -- { map, x, y, GetTime() } ; relevé toutes les 2 s
local function NotePosition()
    local inInstance = IsInInstance()
    if isSecret(inInstance) or inInstance or not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
    local map = C_Map.GetBestMapForUnit("player")
    if type(map) ~= "number" or isSecret(map) then return end
    local position = C_Map.GetPlayerMapPosition(map, "player")
    if not position then return end
    local x, y = position:GetXY()
    if type(x) == "number" and type(y) == "number" and not isSecret(x) and not isSecret(y) then
        lastOutside = { map, x, y, GetTime() }
    end
end

local function RecordEntrance()
    local inInstance, kind = IsInInstance()
    if isSecret(inInstance) or not inInstance or isSecret(kind) or (kind ~= "party" and kind ~= "raid") then return end
    local seen, dungeon = lastOutside, CurrentDungeon()
    lastOutside = nil
    -- ponytail: 30 s couvrent l'écran de chargement ; une entrée connue sur une autre carte écarte le relevé.
    if not (seen and dungeon and GetTime() - seen[4] < 30) then return end
    -- Aile d'une instance partagée (portes à moins de 0.03) : rangée seulement si la carte du joueur en est un étage.
    if dungeon.wing then
        local map = C_Map.GetBestMapForUnit("player")
        local onFloor = false
        for _, floorID in ipairs(dungeon.floors) do onFloor = onFloor or (not isSecret(map) and floorID == map) end
        if not onFloor then return end
    end
    local known = false
    for _, spot in ipairs({ dungeon.entrance, dungeon.secondEntrance }) do
        if spot.map == seen[1] and math.abs(spot.x - seen[2]) < 0.15 and math.abs(spot.y - seen[3]) < 0.15 then known = true end
    end
    if known or not dungeon.entrance then
        NS.db.entrances[dungeon.key] = { seen[1], math.floor(seen[2] * 1000 + 0.5) / 1000, math.floor(seen[3] * 1000 + 0.5) / 1000 }
    end
end

for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
                         "GET_ITEM_INFO_RECEIVED" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, first, second)
    if not NS.db then return end
    if event == "PLAYER_TARGET_CHANGED" then
        RecordBossLevel("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        RecordBossLevel("mouseover")
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if hud and hud.namesPending and hud:IsShown() then NS.UpdateRunHud() end
    elseif event == "QUEST_DATA_LOAD_RESULT" then   -- (questID, success)
        if type(first) ~= "number" or isSecret(first) or type(second) ~= "boolean" or isSecret(second)
            or not requested[first] then return end
        -- ponytail: un refus masque la quête jusqu'à la session suivante, où elle est redemandée ; un accord la rend.
        local missing = not second or nil
        if NS.db.missingQuests[first] ~= missing then
            NS.db.missingQuests[first] = missing
            if not events.refreshPending then   -- réponses en salve : un seul rafraîchissement
                events.refreshPending = true
                C_Timer.After(0.2, function() events.refreshPending = nil NS.Refresh() end)
            end
        end
    else
        if not positionTicker then   -- premier PLAYER_ENTERING_WORLD
            ReadActivityLevels()
            positionTicker = C_Timer.NewTicker(2, NotePosition)
        end
        RecordEntrance()
        NotePosition()
        NS.UpdateRunHud()
    end
end)
