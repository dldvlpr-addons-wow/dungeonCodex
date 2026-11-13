-- Loot.lua
-- Relevé en jeu : boss tués (coches), butin vu tomber (db.recorded), boss absents de Data.lua (db.found),
-- alertes de la liste de souhaits et rappel à l'entrée d'un donjon. Chargé après Journal.lua, dont il
-- reprend les fonctions par NS.
local _, NS = ...
local L = NS.L

local isSecret = _G.issecretvalue or function() return false end
local Print, BossName, DungeonName = NS.Print, NS.BossName, NS.DungeonName
local ItemInfo, ItemIDFromLink, BossItems, RecordKey = NS.ItemInfo, NS.ItemIDFromLink, NS.BossItems, NS.RecordKey
local MarkKilled, MarkKilledByName, ClearKills = NS.MarkKilled, NS.MarkKilledByName, NS.ClearKills
local CurrentDungeon, IsWished = NS.CurrentDungeon, NS.IsWished
local bossByNpc, bossByRecordKey = NS.BossByNpc, NS.BossByRecordKey
local ALERT_SECONDS = 180   -- un jet de dés dure jusqu'à 60 s, puis le butin arrive : une seule alerte

--- npcID et zoneUID d'un GUID Creature-0-serveur-instance-zoneUID-npcID-spawnUID. GUID secret : rien.
-- ponytail: zoneUID supposé propre à chaque exemplaire d'instance (format non documenté par Blizzard) ; s'il
-- change d'une créature à l'autre dans un même run, les coches s'effacent trop tôt : retirer `zone` de MarkKilled.
local function NpcFromGUID(guid)
    if type(guid) ~= "string" or isSecret(guid) then return nil end
    local kind, _, _, _, zone, npcID = strsplit("-", guid)
    if kind ~= "Creature" then return nil end
    return tonumber(npcID), tonumber(zone)
end

--- Alerte (une par objet et par ALERT_SECONDS) quand un objet de la liste de souhaits tombe. `link` : lien ou
--- chaîne « item:ID ».
local alerted = {}
local function AlertWish(link)
    if type(link) ~= "string" or isSecret(link) then return end
    local itemID = ItemIDFromLink(link)
    local now = GetTime()
    if not (itemID and IsWished(itemID)) or (alerted[itemID] or -ALERT_SECONDS) > now - ALERT_SECONDS then return end
    alerted[itemID] = now
    local _, fullLink = ItemInfo(itemID)
    local text = L.WISH_DROPPED:format(fullLink or link)
    Print(text)
    local color = _G.ChatTypeInfo and ChatTypeInfo["RAID_WARNING"]
    if _G.RaidWarningUtil and RaidWarningUtil.AddMessage then
        RaidWarningUtil.AddMessage(text, color)
    elseif _G.RaidNotice_AddMessage and _G.RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, text, color)
    end
    if _G.FlashClientIcon then FlashClientIcon() end
    if _G.PlaySound and not NS.db.muteAlert then PlaySound(_G.SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959) end
end

--- Boss absent de Data.lua, relevé sur ENCOUNTER_END : ajouté au donjon. Boss déjà présent (même rencontre
--- ou même nom) : rendu tel quel. Rend le boss et vrai s'il vient d'être ajouté.
local function AddFoundBoss(dungeon, encounterID, name)
    for _, boss in ipairs(dungeon.bosses) do
        if boss.encounter == encounterID or name == boss.name or name == BossName(boss) then return boss, false end
    end
    local boss = { name = name, encounter = encounterID, items = {}, dungeon = dungeon, found = true }
    dungeon.bosses[#dungeon.bosses + 1] = boss
    bossByRecordKey[RecordKey(boss)] = boss
    return boss, true
end

local OnEncounterEnd, RecordLoot
do
local FOUND_LOOT_SECONDS = 120
local pendingEncounter   -- { id, name, instanceID, instanceName, at } : rencontre réussie sans boss connu

--- ENCOUNTER_END réussi en donjon : coche le boss qui porte ce nom. Sinon, hors donjon vérifié, la rencontre attend
--- le pillage d'une créature inconnue (FoundBossOf) pour être relevée.
function OnEncounterEnd(encounterID, name, success)
    pendingEncounter = nil
    if isSecret(success) or success ~= 1 or type(name) ~= "string" or type(encounterID) ~= "number" or isSecret(name) or isSecret(encounterID)
        or not _G.GetInstanceInfo then
        return
    end
    local instanceName, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if isSecret(instanceID) or type(instanceID) ~= "number" or isSecret(instanceType) or instanceType ~= "party" then return end
    local dungeon = CurrentDungeon()
    for _, boss in ipairs(dungeon and dungeon.bosses or {}) do
        if boss.encounter == encounterID or name == boss.name or name == BossName(boss) then
            MarkKilled(boss)
            return
        end
    end
    if dungeon and dungeon.status == "verified" then return end   -- liste complète : nom différent, pas un boss en plus
    local locale = GetLocale()
    if locale ~= "enUS" and locale ~= "enGB" then
        for _, boss in ipairs(dungeon and dungeon.bosses or {}) do
            -- Boss sans nom traduit : le nom localisé de la rencontre ne peut pas lui être comparé.
            -- Pas de BossName : le repli esMX -> esES n'est pas une traduction sûre du nom de rencontre.
            local translated = (NS.BossNames[locale] or {})[boss.npc or 0] or boss.names and boss.names[locale]
            if (translated or boss.name) == boss.name then return end
        end
    end
    pendingEncounter = { id = encounterID, name = name, instanceID = instanceID, at = GetTime(),
                         instanceName = not isSecret(instanceName) and instanceName or nil }
end

--- Créature sans boss dans Data.lua, pillée peu après une rencontre en attente : c'est ce boss. Le relève dans
--- db.found (gardé pour tools/found_export.lua) et, si le donjon est dans Data.lua, l'ajoute à sa liste.
--- Rend la clé du butin relevé.
local function FoundBossOf(npcID)
    local pending = pendingEncounter
    if not (pending and GetTime() - pending.at <= FOUND_LOOT_SECONDS) then return nil end
    local found = NS.db.found[pending.instanceID] or { name = pending.instanceName, encounters = {} }
    NS.db.found[pending.instanceID] = found
    local entry = found.encounters[pending.id] or { name = pending.name }
    found.encounters[pending.id] = entry
    -- ponytail: première créature pillée dans la fenêtre fixée comme boss ; un trash pillé avant le boss prend sa place.
    if entry.npc and entry.npc ~= npcID then return nil end   -- autre créature que celle déjà fixée
    entry.npc = npcID
    local dungeon = CurrentDungeon()
    if dungeon then
        local boss = AddFoundBoss(dungeon, pending.id, pending.name)
        bossByNpc[npcID] = bossByNpc[npcID] or boss   -- runs suivants : butin et mort reconnus sans rencontre
        MarkKilled(boss, true)
    end
    return "e" .. pending.id
end

function RecordLoot()
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        AlertWish(link)
        local sources = { GetLootSourceInfo(slot) }
        for i = 1, #sources, 2 do
            local npcID, zone = NpcFromGUID(sources[i])
            local boss = bossByNpc[npcID or 0]
            if boss then
                pendingEncounter = nil   -- butin d'un boss connu : la rencontre en attente était lui
                MarkKilled(boss, true, zone)
            end
        end
        local _, _, _, _, quality, _, isQuestItem = GetLootSlotInfo(slot)
        if type(link) == "string" and not isSecret(link) and not isSecret(quality)
            and (quality or 0) >= 2 and not isSecret(isQuestItem) and not isQuestItem then
            local itemID = ItemIDFromLink(link)
            for i = 1, #sources, 2 do
                local npcID = NpcFromGUID(sources[i])
                local boss = npcID and bossByNpc[npcID]
                local key = boss and RecordKey(boss) or npcID and FoundBossOf(npcID)
                if itemID and key then
                    NS.db.recorded[key] = NS.db.recorded[key] or {}
                    NS.db.recorded[key][itemID] = true
                end
            end
        end
    end
end
end

--- Boss relevés en jeu (db.found) remis dans leur donjon. Appelé une fois les réglages chargés.
function NS.LoadFoundBosses()
    for instanceID, found in pairs(NS.db.found) do
        for _, dungeon in ipairs(NS.Dungeons) do
            if dungeon.instance == instanceID then
                for encounterID, entry in pairs(found.encounters or {}) do
                    if entry.npc then
                        bossByNpc[entry.npc] = bossByNpc[entry.npc] or AddFoundBoss(dungeon, encounterID, entry.name)
                    end
                end
            end
        end
    end
end

--- Entrée dans un donjon : rappelle les objets de la liste de souhaits qui y tombent, une fois par entrée.
local remind = {}   -- instance : donjon déjà rappelé ; waiting : objets en cours de chargement par le client
local function RemindWishes()
    local dungeon = CurrentDungeon()
    remind.waiting = nil
    if not dungeon then remind.instance = nil return end
    if remind.instance == dungeon.instance then return end
    local lines = {}
    for _, boss in ipairs(dungeon.bosses) do
        for _, item in ipairs(BossItems(boss)) do
            if IsWished(item.id) then
                local name, link = ItemInfo(item.id)
                -- ponytail: objet jamais chargé par le client = pas de rappel, sans délai de repli.
                if not (link or name) then remind.waiting = true return end   -- GET_ITEM_INFO_RECEIVED relance
                lines[#lines + 1] = (link or name) .. " - " .. BossName(boss)
            end
        end
    end
    remind.instance = dungeon.instance
    if #lines == 0 then return end
    Print(L.MSG_WISH_HERE:format(DungeonName(dungeon)))
    for _, line in ipairs(lines) do Print(line) end
end

--- Message système de réinitialisation (« %s has been reset. ») : coches effacées. Texte secret : ignoré.
local function ResetPattern()
    local text = _G.INSTANCE_RESET_SUCCESS
    if type(text) ~= "string" or isSecret(text) or not text:find("%s", 1, true) then return nil end
    local before, after = text:match("^(.-)%%s(.*)$")
    local function Escape(part) return (part:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end
    -- Codes de grammaire (koKR « |1이;가; ») : n'importe quel texte.
    return (("^" .. Escape(before) .. ".+" .. Escape(after) .. "$"):gsub("|1[^;]*;[^;]*;", ".-"))
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "LOOT_OPENED", "START_LOOT_ROLL", "UNIT_DIED", "BOSS_KILL", "ENCOUNTER_END",
                         "PLAYER_ENTERING_WORLD", "GET_ITEM_INFO_RECEIVED", "CHAT_MSG_SYSTEM" }) do
    events:RegisterEvent(event)
end
-- Signaux d'alerte en plus : un build qui ne les connaît pas ne doit pas couper le reste du fichier.
pcall(events.RegisterEvent, events, "ENCOUNTER_LOOT_RECEIVED")
pcall(events.RegisterEvent, events, "CHAT_MSG_LOOT")
events:SetScript("OnEvent", function(_, event, first, second, ...)
    if not NS.db then return end   -- réglages pas encore chargés (ADDON_LOADED, Journal.lua)
    if event == "LOOT_OPENED" then
        RecordLoot()
        NS.Refresh()
    elseif event == "START_LOOT_ROLL" and _G.GetLootRollItemLink then
        AlertWish(GetLootRollItemLink(first))
    elseif event == "ENCOUNTER_LOOT_RECEIVED" then   -- (encounterID, itemID, itemLink, ...) : butin personnel
        AlertWish((...))
    elseif event == "CHAT_MSG_LOOT" then   -- (text, ...) ; en donjon seulement (achat, craft, quête : pas une chute)
        if type(first) == "string" and not isSecret(first) and CurrentDungeon() then AlertWish(first:match("|c.-|Hitem:.-|h|r") or first:match("item:%d+")) end
    elseif event == "UNIT_DIED" then   -- (unitGUID), parfois secret : NpcFromGUID l'écarte
        local npcID, zone = NpcFromGUID(first)
        local boss = bossByNpc[npcID or 0]
        if boss then MarkKilled(boss, false, zone) end
    elseif event == "BOSS_KILL" then   -- (encounterID, encounterName)
        MarkKilledByName(second)
    elseif event == "ENCOUNTER_END" then   -- (encounterID, encounterName, difficultyID, groupSize, success)
        OnEncounterEnd(first, second, select(3, ...))
    elseif event == "PLAYER_ENTERING_WORLD" then
        RemindWishes()
    elseif event == "GET_ITEM_INFO_RECEIVED" then   -- objet voulu enfin chargé
        if second and not isSecret(second) and remind.waiting then RemindWishes() end
    elseif event == "CHAT_MSG_SYSTEM" then   -- (text, ...) ; secret en donjon, mais un reset se fait dehors
        local pattern = ResetPattern()
        if pattern and type(first) == "string" and not isSecret(first) and first:find(pattern) then
            ClearKills()
            NS.Refresh()
        end
    end
end)
