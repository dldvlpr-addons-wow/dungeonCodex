-- Journal.lua
-- Fenêtre façon Guide de l'aventurier : accueil en grille de donjons illustrés, puis page du
-- donjon avec la liste des boss à gauche et, à droite, la carte de l'étage, le butin, les
-- capacités des boss ou les quêtes.
-- Forever n'a aucune carte d'étage de donjon (C_Map.GetMapInfo(291) = nil) : les tuiles sont
-- posées par fileID (Data.lua), fichiers présents dans le client. Les donjons propres à Forever
-- n'ont pas de carte d'étage : leur carte est faite des tuiles de minicarte. Repères déplaçables en jeu
-- (Maj + glisser). Butin complété par ce qui tombe en jeu (LOOT_OPENED).
local ADDON_NAME, NS = ...
local L = NS.L
local DB_NAME = ADDON_NAME .. "DB"

local ART_WIDTH, ART_HEIGHT, TILE = 1002, 668, 256   -- zone utile des 4 x 3 tuiles de 256 px
local FRAME_WIDTH, FRAME_HEIGHT = 900, 560
local INSET_WIDTH, INSET_HEIGHT = FRAME_WIDTH - 12, FRAME_HEIGHT - 66
local LEFT_WIDTH = 320
local RIGHT_WIDTH = INSET_WIDTH - LEFT_WIDTH - 8
local MAP_WIDTH = RIGHT_WIDTH - 20
local MAP_HEIGHT = math.floor(MAP_WIDTH * ART_HEIGHT / ART_WIDTH + 0.5)
local CARD_WIDTH, CARD_HEIGHT, CARD_GAP, GRID_COLUMNS = 206, 112, 10, 4
local BOSS_HEIGHT, BOSS_STEP = 44, 48
local LOOT_HEIGHT = 46
local QUEST_HEIGHT = 74
local PIN_SIZE, PIN_SELECTED_SIZE = 28, 36
local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local ICON = "Interface\\Icons\\INV_Misc_Map_01"
local DONE_MARK = "|A:common-icon-checkmark:14:14:0:-1|a "   -- coche : quête déjà rendue, boss tué pendant le run
local RUN_SECONDS, SAME_KILL_SECONDS = 7200, 600
local QUEST_COLOR, QUEST_DONE_COLOR = { r = 1, g = 0.82, b = 0 }, { r = 0.1, g = 1, b = 0.1 }
local WISH_MARK = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14|t "   -- étoile de la liste de souhaits
local FILTER_HEIGHT = 26
local PORTRAIT = "Interface\\EncounterJournal\\UI-EJ-PortraitIcon"
local ICON_FRAME = "Interface\\Common\\WhiteIconFrame"
local EJ_ICONS = "Interface\\EncounterJournal\\UI-EJ-Icons"
local TIER_ATLAS = "UI-EJ-Classic"
local GOLD = { 0.62, 0.5, 0.26 }
local PAGE = { 0.07, 0.055, 0.04 }

-- Images des donjons (bouton, illustration), par instance.
local INSTANCE_ART = {
    [389] = { 608211, 608250 }, [43] = { 608229, 608313 }, [36] = { 522352, 526404 }, [33] = { 522358, 526410 },
    [48] = { 608195, 608234 }, [34] = { 608223, 608262 }, [90] = { 608202, 608241 }, [189] = { 608214, 608253 },
    [47] = { 608213, 608252 }, [349] = { 608209, 608248 }, [70] = { 608225, 608264 }, [429] = { 608200, 608239 },
    [129] = { 608212, 608251 }, [329] = { 608216, 608255 }, [209] = { 608230, 608267 }, [230] = { 608196, 608235 },
    [109] = { 608217, 608256 }, [289] = { 608215, 608254 }, [229] = { 608197, 608236 },
}

-- Pastilles de rôle (UI-EJ-Icons, 256 x 64) : gauche, droite, haut, bas en pixels.
local FLAG_ICONS = {
    tank = { 7, 25, 7, 25 }, damage = { 39, 57, 7, 25 }, healer = { 71, 89, 7, 25 }, deadly = { 135, 153, 7, 25 },
    important = { 167, 185, 7, 25 }, interrupt = { 199, 217, 7, 25 }, magic = { 231, 249, 7, 25 },
    curse = { 7, 25, 39, 57 }, poison = { 39, 57, 39, 57 }, disease = { 71, 89, 39, 57 }, enrage = { 103, 121, 39, 57 }, bleed = { 167, 185, 39, 57 },
}

local isSecret = _G.issecretvalue or function() return false end
local db
local frame, homeView, instanceView, mapFrame
local homeButton, dungeonCrumb, bossCrumb, pageTitle, floorText, previousButton, nextButton
local dungeonTitle, dungeonLevels, loreArt, emptyText, noMapText
local gridScroll, gridContent, bossScroll, bossContent, lootScroll, lootContent
local abilityScroll, abilityContent, questScroll, questContent
local wishView, wishScroll, wishContent, wishEmpty, wishButton
local searchUI, waypointButton = { rows = {} }   -- recherche globale : view, scroll, content, empty, box, rows
local dungeonCards, bossButtons, lootRows, abilityRows, questRows, wishRows = {}, {}, {}, {}, {}, {}
local pins, tiles, sideTabs, pages = {}, {}, {}, {}
local current = { floor = 1, tab = "map" }
local filter = { search = "", menus = {} }   -- butin : texte cherché, slot et kind choisis (nil = tous)
local refreshPending = false
local Refresh

local bossByNpc = {}
local bossByRecordKey = {}   -- clé de db.recorded (npcID, ou "e" .. encounterID d'un boss relevé en jeu) -> boss
for _, dungeon in ipairs(NS.Dungeons) do
    for _, boss in ipairs(dungeon.bosses) do
        boss.dungeon = dungeon
        if boss.npc then bossByNpc[boss.npc], bossByRecordKey[boss.npc] = boss, boss end
        for _, npcID in ipairs(boss.otherNpcs or {}) do bossByNpc[npcID] = boss end
    end
end

local function Print(text) print("|cff3fa9f5" .. ADDON_NAME .. "|r " .. text) end

local function BossName(boss)
    local locale = GetLocale()
    local names = NS.BossNames[locale]
    return names and boss.npc and names[boss.npc]
        or boss.names and (boss.names[locale] or locale == "esMX" and boss.names.esES) or boss.name
end

--- Portrait rond de la créature, sinon la tête de mort.
local function SetBossPortrait(texture, boss)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetTexture(SKULL)
    if boss.display and _G.SetPortraitTextureFromCreatureDisplayID then
        SetPortraitTextureFromCreatureDisplayID(texture, boss.display)
    end
end

local function DungeonName(dungeon)
    local name = not dungeon.upcoming and _G.GetRealZoneText and GetRealZoneText(dungeon.instance)
    if type(name) ~= "string" or name == "" then name = dungeon.name or dungeon.key end
    if dungeon.wing then name = name .. " - " .. L[dungeon.wing] end
    return name
end

NS.BossName, NS.DungeonName, NS.WISH_MARK = BossName, DungeonName, WISH_MARK   -- pour Tooltip.lua
NS.BossByRecordKey, NS.BossByNpc, NS.Print = bossByRecordKey, bossByNpc, Print
NS.current, NS.DONE_MARK = current, DONE_MARK   -- pour Run.lua

--- Étage et position du repère : déplacé en jeu d'abord, sinon Data.lua.
local function BossPosition(boss)
    local moved = boss.npc and db.pins[boss.npc]
    if moved then return moved[1], moved[2], moved[3] end
    return boss.floor, boss.x, boss.y
end

--------------------------------------------------------------------------------
-- Objets : infos du client, chargées à la demande
--------------------------------------------------------------------------------

local function ItemInfo(itemID)
    local name, link, quality
    if C_Item and C_Item.GetItemInfo then
        name, link, quality = C_Item.GetItemInfo(itemID)
    elseif _G.GetItemInfo then
        name, link, quality = GetItemInfo(itemID)
    end
    local icon
    if C_Item and C_Item.GetItemIconByID then icon = C_Item.GetItemIconByID(itemID)
    elseif _G.GetItemIcon then icon = GetItemIcon(itemID) end
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    return name, link, quality, icon
end

local function ItemIDFromLink(link)
    if C_Item and C_Item.GetItemInfoInstant then return (C_Item.GetItemInfoInstant(link)) end
    return tonumber(link:match("item:(%d+)"))
end

--- Emplacement (« Tête ») et type (« Tissu ») de l'objet, chaînes vides si inconnus.
local function ItemSlotAndType(itemID)
    if not (C_Item and C_Item.GetItemInfoInstant) then return "", "" end
    local _, _, subType, equipLoc = C_Item.GetItemInfoInstant(itemID)
    local slot = equipLoc and equipLoc ~= "" and _G[equipLoc] or ""
    return slot, subType or ""
end

-- Armures et armes que chaque classe peut équiper (compétences apprises en cours de jeu comprises).
-- Sous-classes : Enum.ItemArmorSubclass (1 tissu, 2 cuir, 3 mailles, 4 plaques, 6 bouclier, 7 libram,
-- 8 idole, 9 totem) et Enum.ItemWeaponSubclass (0 hache 1M, 1 hache 2M, 2 arc, 3 fusil, 4 masse 1M,
-- 5 masse 2M, 6 arme d'hast, 7 épée 1M, 8 épée 2M, 10 bâton, 13 pugilat, 15 dague, 16 jet, 18 arbalète, 19 baguette).
local CLASS_KIND = "\1class"   -- choix « ma classe » du menu des types
local ClassGear, UsableByClass
do
local CLASS_GEAR = {
    WARRIOR = { armor = { 1, 2, 3, 4, 6 }, weapon = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 } },
    PALADIN = { armor = { 1, 2, 3, 4, 6, 7 }, weapon = { 0, 1, 4, 5, 6, 7, 8 } },
    HUNTER = { armor = { 1, 2, 3 }, weapon = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 } },
    ROGUE = { armor = { 1, 2 }, weapon = { 2, 3, 4, 7, 13, 15, 16, 18 } },
    PRIEST = { armor = { 1 }, weapon = { 4, 10, 15, 19 } },
    SHAMAN = { armor = { 1, 2, 3, 6, 9 }, weapon = { 0, 1, 4, 5, 10, 13, 15 } },
    MAGE = { armor = { 1 }, weapon = { 7, 10, 15, 19 } },
    WARLOCK = { armor = { 1 }, weapon = { 7, 10, 15, 19 } },
    DRUID = { armor = { 1, 2, 8 }, weapon = { 4, 5, 10, 13, 15 } },
}
local ARMOR, WEAPON = 4, 2   -- Enum.ItemClass
local classGear
function ClassGear()
    if classGear == nil then
        classGear = false
        local classFile
        if _G.UnitClass then classFile = select(2, UnitClass("player")) end
        local gear = type(classFile) == "string" and not isSecret(classFile) and CLASS_GEAR[classFile]
        if gear then
            classGear = { [ARMOR] = {}, [WEAPON] = {} }
            for _, sub in ipairs(gear.armor) do classGear[ARMOR][sub] = true end
            for _, sub in ipairs(gear.weapon) do classGear[WEAPON][sub] = true end
        end
    end
    return classGear
end

--- Le personnage peut équiper l'objet. Classe inconnue, ou objet ni armure ni arme : oui.
--- Armure générique (anneau, cou, cape, bijou) et armes génériques (canne à pêche) : oui.
function UsableByClass(itemID)
    local gear = ClassGear()
    if not (gear and C_Item and C_Item.GetItemInfoInstant) then return true end
    local _, _, _, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    local allowed = gear[classID]
    if not allowed or subClassID == nil or classID == ARMOR and subClassID == 0
        or classID == ARMOR and equipLoc == "INVTYPE_CLOAK" or classID == WEAPON and (subClassID == 14 or subClassID == 20) then
        return true
    end
    return allowed[subClassID] == true
end
end

-- Recherche : minuscules, accents retirés (latin) et cyrillique en minuscules. ß : ss, œ : oe, ё : е.
local Fold
do
local FOLD = { ["ß"] = "ss", ["œ"] = "oe", ["Œ"] = "oe", ["æ"] = "ae", ["Æ"] = "ae", ["Ё"] = "е", ["ё"] = "е" }
for base, letters in pairs({ a = "àáâãäåÀÁÂÃÄÅ", c = "çÇ", e = "èéêëÈÉÊË", i = "ìíîïÌÍÎÏ", n = "ñÑ",
    o = "òóôõöøÒÓÔÕÖØ", u = "ùúûüÙÚÛÜ", y = "ýÿÝ" }) do
    for letter in letters:gmatch("[\192-\244][\128-\191]+") do FOLD[letter] = base end
end
for i = 0, 31 do   -- А-Я (D0 90-AF) vers а-я (D0 B0-BF, puis D1 80-8F)
    FOLD["\208" .. string.char(0x90 + i)] = i < 16 and "\208" .. string.char(0xB0 + i) or "\209" .. string.char(0x80 + i - 16)
end
function Fold(text)
    return (text:lower():gsub("[\192-\244][\128-\191]+", FOLD))
end
end

--- Clé du butin relevé : npcID du boss, ou "e" .. encounterID d'un boss relevé en jeu (sans npcID connu).
local function RecordKey(boss)
    return boss.encounter and "e" .. boss.encounter or boss.npc
end

--- Objets du boss : ceux de Data.lua, puis ceux vus tomber en jeu et absents de Data.lua.
local function BossItems(boss)
    local items, seen = {}, {}
    for _, itemID in ipairs(boss.items) do
        items[#items + 1] = { id = itemID, boss = boss }
        seen[itemID] = true
    end
    local key = RecordKey(boss)
    local recorded = key and db.recorded[key]
    if recorded then
        local extra = {}
        for itemID in pairs(recorded) do
            if not seen[itemID] then extra[#extra + 1] = itemID end
        end
        table.sort(extra)
        for _, itemID in ipairs(extra) do items[#items + 1] = { id = itemID, boss = boss, recorded = true } end
    end
    return items
end

NS.ItemInfo, NS.ItemIDFromLink, NS.BossItems, NS.RecordKey = ItemInfo, ItemIDFromLink, BossItems, RecordKey
NS.UsableByClass = UsableByClass

--- Liste de souhaits du personnage : itemID -> true. Rangée sous « Nom-Royaume », connu à PLAYER_LOGIN.
local character
local function Wishes()
    if not character then return {} end   -- avant PLAYER_LOGIN : nom du personnage inconnu
    local list = db.wishlists[character]
    if not list then
        list = {}
        db.wishlists[character] = list
    end
    return list
end
local function IsWished(itemID) return Wishes()[itemID] ~= nil end
NS.IsWished, NS.Wishes = IsWished, Wishes

--- Clic droit sur un objet : ajouté à la liste de souhaits ou retiré.
local function ToggleWish(itemID)
    Wishes()[itemID] = not IsWished(itemID) or nil
    NS.ShareWishes()
    Refresh()
end

--- Un objet de la liste de souhaits tombe sur ce boss.
local function HasWish(boss)
    if next(Wishes()) == nil then return false end
    for _, item in ipairs(BossItems(boss)) do
        if IsWished(item.id) then return true end
    end
    return false
end

--- Objets de la liste de souhaits, une entrée par boss qui les donne. Objet hors de toute liste de boss : sans boss.
local function WishList()
    local items, listed = {}, {}
    for _, dungeon in ipairs(NS.Dungeons) do
        for _, boss in ipairs(dungeon.bosses) do
            for _, item in ipairs(BossItems(boss)) do
                if IsWished(item.id) then
                    listed[item.id] = true
                    items[#items + 1] = item
                end
            end
        end
    end
    for itemID in pairs(Wishes()) do
        if not listed[itemID] then items[#items + 1] = { id = itemID } end
    end
    return items
end

--- Filtres du butin : emplacement et type affichés, texte cherché dans le nom.
local function ItemMatches(item)
    local slot, kind = ItemSlotAndType(item.id)
    if filter.slot and slot ~= filter.slot then return false end
    if filter.kind == CLASS_KIND then
        if not UsableByClass(item.id) then return false end
    elseif filter.kind and kind ~= filter.kind then
        return false
    end
    if filter.search == "" then return true end
    local name = ItemInfo(item.id)
    return name ~= nil and Fold(name):find(filter.search, 1, true) ~= nil
end

--- Recherche de l'accueil : objets de tous les donjons dont le nom contient le texte, une ligne par boss.
local SearchAllLoot
do
local foldedNames = {}   -- itemID vers nom replié : la frappe suivante ne relit pas le client
function SearchAllLoot(text)
    local items = {}
    for _, dungeon in ipairs(NS.Dungeons) do
        for _, boss in ipairs(dungeon.bosses) do
            for _, item in ipairs(BossItems(boss)) do
                local name = foldedNames[item.id]
                if not name then
                    name = ItemInfo(item.id)
                    name = name and Fold(name)
                    foldedNames[item.id] = name
                end
                if name and name:find(text, 1, true) then items[#items + 1] = item end
            end
        end
    end
    return items
end
end

--- Butin filtré du boss choisi, sinon celui de tout le donjon. `everything` : tout le donjon, sans filtre.
local function LootList(everything)
    local items = {}
    for _, boss in ipairs(current.boss and not everything and { current.boss } or current.dungeon.bosses) do
        for _, item in ipairs(BossItems(boss)) do
            if everything or ItemMatches(item) then items[#items + 1] = item end
        end
    end
    return items
end

--- Emplacements (rang 1) ou types (rang 2) présents dans le butin du donjon, triés : choix des menus.
local function FilterChoices(rank)
    local seen, choices = {}, {}
    if not current.dungeon then return choices end   -- SetupMenu appelle le générateur dès la création, sur l'accueil
    for _, item in ipairs(LootList(true)) do
        local value = select(rank, ItemSlotAndType(item.id))
        if value ~= "" and not seen[value] then
            seen[value] = true
            choices[#choices + 1] = value
        end
    end
    table.sort(choices)
    return choices
end

--------------------------------------------------------------------------------
-- Habillage
--------------------------------------------------------------------------------

--- Le modèle Blizzard s'il existe dans ce client, sinon un cadre nu.
local function TemplatedFrame(kind, name, parent, template)
    local ok, created = pcall(CreateFrame, kind, name, parent, template)
    if ok and created then return created end
    return CreateFrame(kind, name, parent)
end

local function AddBorder(region, r, g, b, a, layer)
    local EDGES = { { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }
    local edges = {}
    for i, corners in ipairs(EDGES) do
        local edge = region:CreateTexture(nil, layer or "BORDER")
        edge:SetColorTexture(r, g, b, a)
        edge:SetPoint(corners[1])
        edge:SetPoint(corners[2])
        if i <= 2 then edge:SetHeight(1) else edge:SetWidth(1) end
        edges[i] = edge
    end
    return edges
end

local function Fill(region, r, g, b, a, layer)
    local texture = region:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, a)
    return texture
end

--- Dégradé vertical d'une couleur, opaque en bas si `bottomAlpha` > `topAlpha`.
local function Gradient(texture, color, bottomAlpha, topAlpha)
    if not (texture.SetGradient and _G.CreateColor) then texture:Hide() return end
    texture:SetColorTexture(1, 1, 1, 1)
    texture:SetGradient("VERTICAL", CreateColor(color[1], color[2], color[3], bottomAlpha),
        CreateColor(color[1], color[2], color[3], topAlpha))
end

local function Highlight(button, alpha)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 0.85, 0.5, alpha)
    highlight:SetBlendMode("ADD")
end

local function ScrollTo(scroll, value)
    scroll.offset = math.max(0, math.min(scroll.range, value))
    scroll.bar:SetValue(scroll.offset)
    scroll:SetVerticalScroll(scroll.offset)
end

--- À appeler après chaque remplissage : `contentHeight` = hauteur totale des lignes.
local function UpdateScroll(scroll, contentHeight)
    scroll.content:SetHeight(math.max(1, contentHeight))
    scroll.range = math.max(0, contentHeight - scroll.visibleHeight)
    local bar = scroll.bar
    bar:SetMinMaxValues(0, scroll.range)
    bar:SetShown(scroll.range > 0)
    bar.thumb:SetHeight(math.max(24, scroll.visibleHeight * scroll.visibleHeight / math.max(contentHeight, scroll.visibleHeight)))
    ScrollTo(scroll, scroll.offset)
end

local function CreateScrollList(panel, width, height)
    local scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetSize(width - 18, height - 8)
    scroll.visibleHeight, scroll.range, scroll.offset = height - 8, 0, 0
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width - 18, 1)
    scroll:SetScrollChild(content)
    scroll.content = content

    local bar = CreateFrame("Slider", nil, panel)
    bar:SetOrientation("VERTICAL")
    bar:SetSize(6, height - 8)
    bar:SetPoint("TOPRIGHT", -4, -4)
    bar:EnableMouse(true)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(1, 1, 1, 0.06)
    bar.thumb = bar:CreateTexture(nil, "OVERLAY")
    bar.thumb:SetColorTexture(0.8, 0.7, 0.45, 0.8)
    bar.thumb:SetSize(6, 24)
    bar:SetThumbTexture(bar.thumb)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    bar:SetScript("OnValueChanged", function(_, value)
        scroll.offset = value
        scroll:SetVerticalScroll(value)
    end)
    scroll.bar = bar

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta) ScrollTo(self, self.offset - delta * 60) end)
    return scroll, content
end

local function HideFrom(list, from)
    for i = from, #list do list[i]:Hide() end
end

--------------------------------------------------------------------------------
-- Affichage
--------------------------------------------------------------------------------

local pinOfBoss = {}

--- Boss tué pendant le run en cours : db.kills[npcID ou nom] = heure du kill.
local function IsKilled(boss)
    return db.kills[boss.npc or boss.name] ~= nil and time() - (db.killsAt or 0) <= RUN_SECONDS
end

--- Efface les coches : nouveau run. Le run effacé rejoint l'historique (50 derniers, /codex runs).
local function ClearKills()
    local count = 0
    for _ in pairs(db.kills) do count = count + 1 end
    if count > 0 and db.killsInstance and db.killsAt then
        table.insert(db.runs, { instance = db.killsInstance, dungeon = db.killsDungeon, start = db.killsStart or db.killsAt,
            finish = db.killsAt, bosses = count })
        if #db.runs > 50 then table.remove(db.runs, 1) end
    end
    wipe(db.kills)
    db.killsAt, db.killsZone, db.killsStart, db.killsDungeon = nil, nil, nil, nil
end

--- Coche le boss. Nouveau run supposé, donc coches effacées : autre donjon, autre zoneUID dans le GUID d'une
--- créature (`zone`), boss déjà coché retué, ou plus de RUN_SECONDS sans kill. `looted` : signal du butin, qui
--- peut suivre le kill de loin et n'efface rien.
local function MarkKilled(boss, looted, zone)
    local key, now = boss.npc or boss.name, time()
    if zone and db.killsZone and zone ~= db.killsZone then ClearKills() end
    local last = db.kills[key]
    -- Même kill vu par un autre signal. Un boss fait de plusieurs créatures (otherNpcs) meurt en plusieurs fois.
    if last and (looted or boss.otherNpcs or now - last < SAME_KILL_SECONDS) then return end
    if last or db.killsInstance ~= boss.dungeon.instance or now - (db.killsAt or 0) > RUN_SECONDS then ClearKills() end
    db.kills[key], db.killsInstance, db.killsAt = now, boss.dungeon.instance, now
    db.killsStart, db.killsDungeon = db.killsStart or now, boss.dungeon.key
    db.killsZone = zone or db.killsZone
    db.bossKills[RecordKey(boss)] = (db.bossKills[RecordKey(boss)] or 0) + 1   -- taux de butin observé (Run.lua)
    Refresh()
end

--- BOSS_KILL ne donne que le nom de la rencontre : boss du donjon en cours qui porte ce nom.
NS.MarkKilled, NS.ClearKills, NS.IsKilled = MarkKilled, ClearKills, IsKilled

local function MarkKilledByName(name)
    local instanceID = _G.GetInstanceInfo and select(8, GetInstanceInfo())
    if type(name) ~= "string" or isSecret(name) or isSecret(instanceID) then return end
    for _, dungeon in ipairs(NS.Dungeons) do
        for _, boss in ipairs(dungeon.instance == instanceID and not dungeon.upcoming and dungeon.bosses or {}) do
            if name == boss.name or name == BossName(boss) then MarkKilled(boss) end
        end
    end
end

NS.MarkKilledByName = MarkKilledByName

local function SetPinHighlight(boss, on)
    local pin = pinOfBoss[boss]
    if not (pin and pin:IsShown()) then return end
    local size = (on or boss == current.boss) and PIN_SELECTED_SIZE or PIN_SIZE
    pin:SetSize(size, size)
    pin.glow:SetShown(on or boss == current.boss)
end

local function SelectTab(tab)
    current.tab = tab
    Refresh()
end

local function ResetPageScrolls()
    ScrollTo(lootScroll, 0)
    ScrollTo(abilityScroll, 0)
    ScrollTo(questScroll, 0)
end

--- Un clic sur le boss déjà choisi revient à tout le donjon. Depuis la carte ou les quêtes, ouvre le butin.
local function SelectBoss(boss)
    if boss == current.boss then boss = nil end
    current.boss = boss
    if boss then
        local floor = BossPosition(boss)
        for i, floorID in ipairs(current.dungeon.floors) do
            if floorID == floor then current.floor = i end
        end
        if current.tab == "map" or current.tab == "quests" then current.tab = "loot" end
    end
    ResetPageScrolls()
    Refresh()
end

local function SelectDungeon(dungeon)
    current.dungeon, current.boss, current.floor, current.tab, current.wishlist = dungeon, nil, 1, "map", nil
    filter.slot, filter.kind = nil, nil   -- les choix des menus changent d'un donjon à l'autre
    for _, menu in ipairs(filter.menus) do menu:GenerateMenu() end
    ScrollTo(bossScroll, 0)
    ResetPageScrolls()
    Refresh()
end

local function LevelColor(dungeon)
    if _G.GetQuestDifficultyColor then
        local color = GetQuestDifficultyColor(dungeon.levels[2])
        if color then return color.r, color.g, color.b end
    end
    return 0.6, 0.6, 0.6
end

--- Fiabilité des données du donjon : à venir, bêta (relevé partiel), non confirmé. Vérifié : rien.
local function StatusTag(dungeon)
    if dungeon.upcoming then return "|cffff8040" .. L.UPCOMING .. "|r" end
    if dungeon.status == "beta" then return "|cffffd100" .. L.STATUS_BETA .. "|r" end
    if dungeon.status == "unconfirmed" then return "|cffff8040" .. L.STATUS_UNCONFIRMED .. "|r" end
    return ""
end

local function DungeonCard(index)
    local card = dungeonCards[index]
    if card then card:Show() return card end
    card = CreateFrame("Button", nil, gridContent)
    card:SetSize(CARD_WIDTH, CARD_HEIGHT)
    local column, line = (index - 1) % GRID_COLUMNS, math.floor((index - 1) / GRID_COLUMNS)
    card:SetPoint("TOPLEFT", 8 + column * (CARD_WIDTH + CARD_GAP), -(8 + line * (CARD_HEIGHT + CARD_GAP)))
    Fill(card, 0.12, 0.1, 0.08, 1)
    card.image = card:CreateTexture(nil, "ARTWORK")
    card.image:SetAllPoints()
    card.image:SetTexCoord(0, 0.68359375, 0, 0.7421875)
    card.tiles = {}
    local top = card:CreateTexture(nil, "ARTWORK", nil, 1)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(40)
    Gradient(top, { 0, 0, 0 }, 0, 0.8)
    local bottom = card:CreateTexture(nil, "ARTWORK", nil, 1)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(26)
    Gradient(bottom, { 0, 0, 0 }, 0.8, 0)
    card.edges = AddBorder(card, 0, 0, 0, 1, "OVERLAY")
    Highlight(card, 0.15)
    card.text = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.text:SetPoint("TOPLEFT", 8, -8)
    card.text:SetPoint("TOPRIGHT", -8, -8)
    card.text:SetJustifyH("LEFT")
    card.text:SetWordWrap(false)
    card.text:SetShadowOffset(1, -1)
    card.levels = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.levels:SetPoint("BOTTOMRIGHT", -8, 6)
    card.levels:SetShadowOffset(1, -1)
    dungeonCards[index] = card
    card:Show()
    return card
end

--- Miniature d'un donjon sans image : son premier étage, tuiles rognées au cadre de la carte.
local function SetCardMap(card, art)
    if not art then return end
    local cols, left, top = art.cols or 4, art.left or 0, art.top or 0
    local size = TILE * CARD_WIDTH / ART_WIDTH * (art.scale or 1)
    local shift = (CARD_WIDTH * ART_HEIGHT / ART_WIDTH - CARD_HEIGHT) / 2
    for i, fileID in ipairs(art) do
        local tile = card.tiles[i] or card:CreateTexture(nil, "ARTWORK")
        card.tiles[i] = tile
        local x0 = ((i - 1) % cols - left) * size
        local y0 = (math.floor((i - 1) / cols) - top) * size - shift
        local x1, y1 = math.min(x0 + size, CARD_WIDTH), math.min(y0 + size, CARD_HEIGHT)
        local cx, cy = math.max(x0, 0), math.max(y0, 0)
        local visible = x1 > cx and y1 > cy
        tile:SetShown(visible)
        if visible then
            tile:SetTexture(fileID)
            tile:ClearAllPoints()
            tile:SetPoint("TOPLEFT", cx, -cy)
            tile:SetSize(x1 - cx, y1 - cy)
            tile:SetTexCoord((cx - x0) / size, (x1 - x0) / size, (cy - y0) / size, (y1 - y0) / size)
        end
    end
end

--- Grille : donjons conseillés (niveau du joueur dans la tranche) d'abord, puis par niveau minimum.
local function RefreshDungeons()
    local level = _G.UnitLevel and UnitLevel("player")
    if isSecret(level) or type(level) ~= "number" then level = nil end
    local advised, order, shown = {}, {}, {}
    for i, dungeon in ipairs(NS.Dungeons) do
        order[dungeon] = i
        advised[dungeon] = level ~= nil and level >= dungeon.levels[1] and level <= dungeon.levels[3]
        if not (db.hideUpcoming and dungeon.upcoming) then shown[#shown + 1] = dungeon end
    end
    table.sort(shown, function(a, b)
        if advised[a] ~= advised[b] then return advised[a] end
        if a.levels[1] ~= b.levels[1] then return a.levels[1] < b.levels[1] end
        return order[a] < order[b]
    end)
    for i, dungeon in ipairs(shown) do
        local card = DungeonCard(i)
        card.dungeon = dungeon
        for _, edge in ipairs(card.edges) do
            if advised[dungeon] then edge:SetColorTexture(1, 0.82, 0.3, 1) else edge:SetColorTexture(0, 0, 0, 1) end
        end
        local art = INSTANCE_ART[dungeon.instance]
        card.image:SetTexture(art and art[1])
        card.image:SetShown(art ~= nil)
        for _, tile in ipairs(card.tiles) do tile:Hide() end   -- la carte a pu montrer un autre donjon
        if not art then SetCardMap(card, NS.Floors[dungeon.floors[1]]) end
        local wished = false
        for _, boss in ipairs(dungeon.bosses) do wished = wished or HasWish(boss) end
        card.text:SetText((wished and WISH_MARK or "") .. DungeonName(dungeon))
        local tag = StatusTag(dungeon)
        card.levels:SetText((tag ~= "" and tag .. "  " or "") .. L.LEVELS:format(dungeon.levels[1], dungeon.levels[3]))
        card.levels:SetTextColor(LevelColor(dungeon))
        card:SetScript("OnClick", function() SelectDungeon(dungeon) end)
    end
    for i = #shown + 1, #dungeonCards do dungeonCards[i]:Hide() end
    UpdateScroll(gridScroll, 16 + math.ceil(#shown / GRID_COLUMNS) * (CARD_HEIGHT + CARD_GAP))
end

local function BossButton(index)
    local button = bossButtons[index]
    if button then button:Show() return button end
    button = CreateFrame("Button", nil, bossContent)
    button:SetSize(bossContent:GetWidth() - 4, BOSS_HEIGHT)
    button:SetPoint("TOPLEFT", 2, -(index - 1) * BOSS_STEP)
    Fill(button, 0.16, 0.12, 0.08, 0.92)
    button.edges = AddBorder(button, GOLD[1], GOLD[2], GOLD[3], 0.7)
    button.selected = Fill(button, 1, 0.8, 0.35, 0.18, "ARTWORK")
    button.selected:SetBlendMode("ADD")
    Highlight(button, 0.12)
    button.portrait = button:CreateTexture(nil, "OVERLAY")
    button.portrait:SetSize(BOSS_HEIGHT - 6, BOSS_HEIGHT - 6)
    button.portrait:SetPoint("LEFT", 4, 0)
    button.number = button:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    button.number:SetPoint("RIGHT", -10, 0)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.text:SetPoint("TOPLEFT", button.portrait, "TOPRIGHT", 8, -3)
    button.text:SetPoint("RIGHT", button.number, "LEFT", -6, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)
    button.detail = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.detail:SetPoint("BOTTOMLEFT", button.portrait, "BOTTOMRIGHT", 8, 3)
    button.detail:SetTextColor(0.7, 0.7, 0.7)
    bossButtons[index] = button
    button:Show()
    return button
end

local function RefreshBossList()
    local dungeon = current.dungeon
    dungeonTitle:SetText(DungeonName(dungeon))
    local tag = StatusTag(dungeon)
    dungeonLevels:SetText(L.LEVELS:format(dungeon.levels[1], dungeon.levels[3]) .. (tag ~= "" and "  " .. tag or ""))
    waypointButton:SetShown(dungeon.entrance ~= nil and C_Map ~= nil and C_Map.SetUserWaypoint ~= nil)
    dungeonLevels:SetTextColor(LevelColor(dungeon))
    local art = INSTANCE_ART[dungeon.instance]
    loreArt:SetTexture(art and art[2])
    loreArt:SetShown(art ~= nil)

    local floorID = dungeon.floors[current.floor]
    for i, boss in ipairs(dungeon.bosses) do
        local button = BossButton(i)
        button.number:SetText(i)
        button.text:SetText((HasWish(boss) and WISH_MARK or "") .. (IsKilled(boss) and DONE_MARK or "") .. BossName(boss))
        local rare = boss.rare and " (" .. (_G.ITEM_QUALITY3_DESC or "Rare") .. ")" or ""
        local level = boss.level or boss.npc and db.bossLevels[boss.npc]   -- relevé en jeu (Run.lua) faute de donnée
        button.detail:SetText(level and (_G.LEVEL or "Level") .. " " .. level .. rare or "")
        SetBossPortrait(button.portrait, boss)
        local floor = BossPosition(boss)
        local elsewhere = #dungeon.floors > 1 and floor ~= floorID
        button.text:SetAlpha(elsewhere and 0.55 or 1)
        local chosen = boss == current.boss
        button.selected:SetShown(chosen)
        for _, edge in ipairs(button.edges) do
            if chosen then edge:SetColorTexture(1, 0.82, 0.3, 1) else edge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.7) end
        end
        button:UnlockHighlight()
        button:SetScript("OnClick", function() SelectBoss(boss) end)
        button:SetScript("OnEnter", function() SetPinHighlight(boss, true) end)
        button:SetScript("OnLeave", function() SetPinHighlight(boss, false) end)
    end
    HideFrom(bossButtons, #dungeon.bosses + 1)
    UpdateScroll(bossScroll, #dungeon.bosses * BOSS_STEP)
end

local function LootRow(index, rows, content)
    rows, content = rows or lootRows, content or lootContent
    local row = rows[index]
    if row then row:Show() return row end
    row = CreateFrame("Button", nil, content)
    row:SetSize(content:GetWidth(), LOOT_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * LOOT_HEIGHT)
    row.stripe = Fill(row, 1, 1, 1, 0.035)
    Highlight(row, 0.1)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(38, 38)
    row.icon:SetPoint("LEFT", 6, 0)
    row.iconBorder = row:CreateTexture(nil, "OVERLAY")
    row.iconBorder:SetAllPoints(row.icon)
    row.iconBorder:SetTexture(ICON_FRAME)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -3)
    row.text:SetPoint("RIGHT", -150, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.source = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.source:SetPoint("TOPRIGHT", -10, -6)
    row.source:SetWidth(140)
    row.source:SetJustifyH("RIGHT")
    row.source:SetWordWrap(false)
    row.slot = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.slot:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 3)
    row.slot:SetTextColor(0.75, 0.75, 0.75)
    row.kind = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.kind:SetPoint("BOTTOMRIGHT", -10, 8)
    row.kind:SetTextColor(0.75, 0.75, 0.75)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnLeave", GameTooltip_Hide)
    rows[index] = row
    row:Show()
    return row
end

--- Bande alternée, icône et couleur de qualité de l'objet sur la ligne. Rend le nom et le lien.
local function ShowItem(row, index, itemID)
    row.stripe:SetShown(index % 2 == 0)
    local name, link, quality, icon = ItemInfo(itemID)
    row.icon:SetTexture(icon or 134400)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color and color.r then
        row.iconBorder:SetVertexColor(color.r, color.g, color.b)
        row.text:SetTextColor(color.r, color.g, color.b)
    else
        row.iconBorder:SetVertexColor(0.5, 0.5, 0.5)
        row.text:SetTextColor(1, 1, 1)
    end
    return name, link
end

local function RefreshLoot()
    local items = LootList()
    for i, item in ipairs(items) do
        local row = LootRow(i)
        local name, link = ShowItem(row, i, item.id)
        row.text:SetText((IsWished(item.id) and WISH_MARK or "") .. (name or "...") .. (item.recorded and " |cff3fa9f5*|r" or ""))
        local slot, kind = ItemSlotAndType(item.id)
        row.slot:SetText(slot ~= "" and kind ~= "" and slot .. ", " .. kind or slot .. kind)
        local status = NS.ItemStatus[item.id]
        local tag = status == "new" and "|cff40ff40" .. L.NEW .. "|r" or status == "changed" and "|cffffd100" .. L.CHANGED .. "|r" or ""
        local chance = item.boss.drops and item.boss.drops[item.id]
        local gain = NS.ItemGain(item.id)
        chance = (chance and chance .. " %" or "") .. (gain and gain > 0 and "  |cff40ff40+" .. gain .. "|r" or "")
        row.kind:SetText(tag .. (tag ~= "" and chance ~= "" and "  " or "") .. chance)
        row.source:SetText(current.boss and "" or BossName(item.boss))
        row:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                ToggleWish(item.id)
            elseif link then
                HandleModifiedItemClick(link)
            end
        end)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(item.id)
            if item.recorded then GameTooltip:AddLine(L.RECORDED, 0.25, 0.66, 0.96) end
            GameTooltip:AddLine(L.WISH_HINT, 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
    end
    HideFrom(lootRows, #items + 1)
    UpdateScroll(lootScroll, #items * LOOT_HEIGHT)
    return #items
end

-- Emplacements d'équipement (INVSLOT_*) de chaque type d'objet. Le premier range l'objet dans la liste de souhaits.
local EQUIP_SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 }, INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 },
    INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 }, INVTYPE_TABARD = { 19 },
}
local NO_SLOT = { 99 }   -- objet qui ne s'équipe pas : en fin de liste, sans ligne d'objet porté

local function EquipSlots(itemID)
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
    if equipLoc == "INVTYPE_ROBE" then equipLoc = "INVTYPE_CHEST" end
    return EQUIP_SLOTS[equipLoc] or NO_SLOT, equipLoc
end

--- Objet équipé ou dans les sacs ou la banque.
local function Obtained(itemID)
    if C_Item.GetItemCount(itemID, true) > 0 then return true end
    for _, slot in ipairs(EquipSlots(itemID)) do
        local link = GetInventoryItemLink("player", slot)
        if link and not isSecret(link) and ItemIDFromLink(link) == itemID then return true end
    end
    return false
end

--- Liste de souhaits rangée par type d'objet (une main, deux mains...) dans l'ordre des emplacements, chaque
--- groupe précédé d'une ligne (header) avec l'objet porté.
local function WishRowsBySlot()
    local groups, order = {}, {}
    for _, item in ipairs(WishList()) do
        local slots, equipLoc = EquipSlots(item.id)
        local key = slots == NO_SLOT and "" or equipLoc
        local group = groups[key]
        if not group then
            group = { slots = slots, label = _G[equipLoc] or "", key = key }
            groups[key] = group
            order[#order + 1] = group
        end
        group[#group + 1] = item
    end
    table.sort(order, function(a, b)
        if a.slots[1] ~= b.slots[1] then return a.slots[1] < b.slots[1] end
        return a.key < b.key
    end)
    local rows = {}
    for _, group in ipairs(order) do
        if group.slots ~= NO_SLOT then rows[#rows + 1] = { header = group } end
        for _, item in ipairs(group) do rows[#rows + 1] = item end
    end
    return rows
end

--- Ligne d'en-tête d'un emplacement : objet(s) porté(s), icône du premier.
local function ShowEquipped(row, index, group)
    local names, firstID, firstLink = {}, nil, nil
    for _, slot in ipairs(group.slots) do
        local link = GetInventoryItemLink("player", slot)
        local itemID = link and not isSecret(link) and ItemIDFromLink(link)
        if itemID then
            firstID, firstLink = firstID or itemID, firstLink or link
            names[#names + 1] = ItemInfo(itemID) or "..."
        end
    end
    if firstID then
        ShowItem(row, index, firstID)
    else
        row.stripe:SetShown(index % 2 == 0)
        row.icon:SetTexture(134400)
        row.iconBorder:SetVertexColor(0.5, 0.5, 0.5)
    end
    row.text:SetText(L.EQUIPPED:format(#names > 0 and table.concat(names, ", ") or L.NOTHING_EQUIPPED))
    row.text:SetTextColor(0.6, 0.6, 0.6)
    row.slot:SetText(group.label)
    row.kind:SetText("")
    row.source:SetText("")
    row:SetScript("OnClick", function() if firstLink and IsModifiedClick() then HandleModifiedItemClick(firstLink) end end)
    row:SetScript("OnEnter", function(self)
        if not firstID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(firstID)
        GameTooltip:Show()
    end)
end

local function RefreshWishlist()
    local items = WishRowsBySlot()
    for i, item in ipairs(items) do
        local row = LootRow(i, wishRows, wishContent)
        if item.header then
            ShowEquipped(row, i, item.header)
        else
            local name, link = ShowItem(row, i, item.id)
            local boss = item.boss
            row.text:SetText(name or "...")
            row.slot:SetText(boss and DungeonName(boss.dungeon) .. ", " .. BossName(boss) or "")
            local chance = boss and boss.drops and boss.drops[item.id]
            local seen = NS.DropStats(item.id, boss)
            row.kind:SetText((chance and chance .. " %" or "") .. (seen and "  |cffa0a0a0" .. seen .. "|r" or ""))
            row.source:SetText(Obtained(item.id) and "|cff40ff40" .. L.OBTAINED .. "|r" or "")
            row:SetScript("OnClick", function(_, button)
                if button == "RightButton" then
                    ToggleWish(item.id)
                elseif IsModifiedClick() then
                    if link then HandleModifiedItemClick(link) end
                elseif boss then
                    SelectDungeon(boss.dungeon)
                    SelectBoss(boss)
                end
            end)
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(item.id)
                GameTooltip:AddLine(L.WISHLIST_HINT, 0.6, 0.6, 0.6)
                GameTooltip:Show()
            end)
        end
    end
    HideFrom(wishRows, #items + 1)
    UpdateScroll(wishScroll, #items * LOOT_HEIGHT)
    wishEmpty:SetShown(#items == 0)
end

local function RefreshSearch()
    local items = SearchAllLoot(current.search)
    for i, item in ipairs(items) do
        local row = LootRow(i, searchUI.rows, searchUI.content)
        local name, link = ShowItem(row, i, item.id)
        local boss = item.boss
        row.text:SetText((IsWished(item.id) and WISH_MARK or "") .. (name or "..."))
        row.slot:SetText(DungeonName(boss.dungeon) .. ", " .. BossName(boss))
        local chance = boss.drops and boss.drops[item.id]
        row.kind:SetText(chance and chance .. " %" or "")
        row.source:SetText("")
        row:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                ToggleWish(item.id)
            elseif IsModifiedClick() then
                if link then HandleModifiedItemClick(link) end
            else
                searchUI.box:SetText("")
                searchUI.box:ClearFocus()
                SelectDungeon(boss.dungeon)
                SelectBoss(boss)
            end
        end)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(item.id)
            GameTooltip:AddLine(L.SEARCH_HINT, 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
    end
    HideFrom(searchUI.rows, #items + 1)
    UpdateScroll(searchUI.scroll, #items * LOOT_HEIGHT)
    searchUI.empty:SetShown(#items == 0)
end

local function FlagIcons(flags)
    local text = ""
    for flag in flags:gmatch("[^,]+") do
        local c = FLAG_ICONS[flag]
        if c then text = text .. ("|T%s:16:16:0:0:256:64:%d:%d:%d:%d|t"):format(EJ_ICONS, c[1], c[2], c[3], c[4]) end
    end
    return text
end

--- Textes du combat (Tactics/) : dans la langue du client, sinon en anglais.
local function Tactic(boss)
    return boss.tactic and NS.Tactics and NS.Tactics[boss.tactic] or {}
end
NS.Tactic = Tactic

--- Nom de la capacité : celui du sort dans le client, sinon celui de Tactics/. Texte : le conseil de Tactics/,
--- sinon la description du sort.
local function AbilityTexts(boss, index, ability)
    local texts = Tactic(boss)[index] or {}
    local name, text = texts[1], texts[2]
    if ability.spell and C_Spell then
        name = C_Spell.GetSpellName and C_Spell.GetSpellName(ability.spell) or name
        if not text or text == "" then
            text = C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(ability.spell)
        end
    end
    return name or "", text or ""
end

--- Capacités du boss choisi, sinon celles de tout le donjon. La note du combat ouvre la liste.
local function AbilityList()
    local list = {}
    local bosses = current.boss and { current.boss } or current.dungeon.bosses
    for _, boss in ipairs(bosses) do
        local note = Tactic(boss).note
        if note then list[#list + 1] = { boss = boss, note = note } end
        for index, ability in ipairs(boss.abilities or {}) do
            list[#list + 1] = { boss = boss, ability = ability, index = index }
        end
    end
    return list
end

--- Découpe en morceaux de `limit` octets au plus, à une espace si possible, jamais au milieu d'un caractère UTF-8.
local function Chunks(text, limit)
    local chunks = {}
    while #text > limit do
        local cut = limit
        local space = text:sub(1, limit + 1):match("^.*()%s")
        if space and space > 1 then
            cut = space - 1
        else
            while cut > 1 and text:byte(cut + 1) >= 128 and text:byte(cut + 1) < 192 do cut = cut - 1 end
        end
        chunks[#chunks + 1] = text:sub(1, cut)
        text = (text:sub(cut + 1):gsub("^%s+", ""))
    end
    if text ~= "" then chunks[#chunks + 1] = text end
    return chunks
end

NS.AbilityTexts = AbilityTexts

--- Envoie au chat de groupe la note et les capacités du boss, une ligne par capacité.
local function ShareTactic(boss)
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or _G.SendChatMessage
    if not (send and _G.IsInGroup and IsInGroup()) then Print(L.MSG_NOT_IN_GROUP) return end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        Print(L.MSG_CHAT_LOCKED)
        return
    end
    local channel = _G.IsInRaid and IsInRaid() and "RAID" or "PARTY"
    local note = Tactic(boss).note
    local lines = { BossName(boss) .. (note and ": " .. note or "") }
    for index, ability in ipairs(boss.abilities or {}) do
        local name, text = AbilityTexts(boss, index, ability)
        lines[#lines + 1] = name .. ": " .. text
    end
    for _, line in ipairs(lines) do
        for _, chunk in ipairs(Chunks(line, 250)) do send(chunk, channel) end
    end
end

local function AbilityRow(index)
    local row = abilityRows[index]
    if row then row:Show() return row end
    row = CreateFrame("Button", nil, abilityContent)
    row:SetWidth(abilityContent:GetWidth())
    row.stripe = Fill(row, 1, 1, 1, 0.035)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(30, 30)
    row.icon:SetPoint("TOPLEFT", 6, -6)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
    row.flags = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.flags:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
    row.source = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.source:SetPoint("TOPRIGHT", -10, -8)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -18)
    row.text:SetWidth(abilityContent:GetWidth() - 60)
    row.text:SetJustifyH("LEFT")
    row.text:SetSpacing(2)
    row:SetScript("OnLeave", GameTooltip_Hide)
    abilityRows[index] = row
    row:Show()
    return row
end

local function RefreshAbilities()
    local list = AbilityList()
    local top = 0
    for i, entry in ipairs(list) do
        local row = AbilityRow(i)
        row.stripe:SetShown(i % 2 == 0)
        local ability = entry.ability
        local name, text
        if ability then
            name, text = AbilityTexts(entry.boss, entry.index, ability)
            row.icon:SetTexture("Interface\\Icons\\" .. ability.icon)
            row.flags:SetText(FlagIcons(ability.flags))
        else
            name, text = BossName(entry.boss), entry.note
            SetBossPortrait(row.icon, entry.boss)
            row.flags:SetText("")
        end
        row.name:SetText(name)
        row.text:SetText(text)
        row.source:SetText(current.boss and "" or BossName(entry.boss))
        local height = math.max(42, 30 + (row.text:GetStringHeight() or 12))
        row:SetHeight(height)
        row:SetPoint("TOPLEFT", 0, -top)
        top = top + height
        row:SetScript("OnEnter", function(self)
            if not (ability and ability.spell) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(ability.spell)
            GameTooltip:Show()
        end)
    end
    HideFrom(abilityRows, #list + 1)
    UpdateScroll(abilityScroll, top)
    return #list
end

--- Point de carte suivi par la flèche du client ; false si la carte n'en accepte pas.
local function SetWaypoint(map, x, y)
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(map) then
        Print(L.NO_WAYPOINT)
        return false
    end
    local point = UiMapPoint and UiMapPoint.CreateFromCoordinates and UiMapPoint.CreateFromCoordinates(map, x, y)
        or { uiMapID = map, position = CreateVector2D(x, y) }
    C_Map.SetUserWaypoint(point)
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    return true
end

local function QuestRow(index)
    local row = questRows[index]
    if row then row:Show() return row end
    row = CreateFrame("Button", nil, questContent)
    -- Ligne cliquable quand le donneur a une position : point de route sur lui.
    row:SetScript("OnClick", function(self)
        local quest = self.quest
        if quest.giverMap and C_Map.SetUserWaypoint and SetWaypoint(quest.giverMap, quest.gx, quest.gy) then
            Print(L.GIVER_WAYPOINT_SET:format(quest.giver or quest.title))
        end
    end)
    row:SetScript("OnEnter", function(self)
        if not (self.quest.giverMap and C_Map.SetUserWaypoint) then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(L.GIVER_WAYPOINT_HINT, 1, 1, 1)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetSize(questContent:GetWidth(), QUEST_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * QUEST_HEIGHT)
    row.stripe = Fill(row, 1, 1, 1, 0.035)
    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.title:SetPoint("TOPLEFT", 10, -7)
    row.title:SetPoint("RIGHT", -170, 0)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    row.level = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.level:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
    row.giver = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.giver:SetPoint("TOPLEFT", row.level, "BOTTOMLEFT", 0, -3)
    row.giver:SetPoint("RIGHT", -170, 0)
    row.giver:SetJustifyH("LEFT")
    row.giver:SetWordWrap(false)
    row.need = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.need:SetPoint("TOPLEFT", row.giver, "BOTTOMLEFT", 0, -3)
    row.need:SetPoint("RIGHT", -170, 0)
    row.need:SetJustifyH("LEFT")
    row.need:SetWordWrap(false)
    row.need:SetTextColor(0.8, 0.8, 0.8)
    row.rewards = {}
    for slot = 1, 6 do
        local reward = CreateFrame("Button", nil, row)
        reward:SetSize(24, 24)
        reward:SetPoint("RIGHT", -10 - (slot - 1) * 27, 0)
        reward.icon = reward:CreateTexture(nil, "ARTWORK")
        reward.icon:SetAllPoints()
        reward:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:Show()
        end)
        reward:SetScript("OnLeave", GameTooltip_Hide)
        reward:SetScript("OnClick", function(self)
            local _, link = ItemInfo(self.itemID)
            if link then HandleModifiedItemClick(link) end
        end)
        row.rewards[slot] = reward
    end
    questRows[index] = row
    row:Show()
    return row
end

local function QuestTitle(quest)
    local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(quest.id)
    return type(title) == "string" and title ~= "" and title or quest.title
end

--- Quête déjà rendue par ce personnage. turnedIn couvre l'instant où le client n'a pas encore posé le drapeau.
local turnedIn = {}
local function QuestDone(quest)
    return turnedIn[quest.id]
        or C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(quest.id)
end
NS.QuestTitle, NS.QuestDone = QuestTitle, QuestDone

--- Objets à rapporter et quêtes à finir avant, une coche sur celles déjà rendues.
local function QuestNeeds(quest)
    local needs, before = {}, {}
    for _, itemID in ipairs(quest.need or {}) do
        local name, link = ItemInfo(itemID)
        needs[#needs + 1] = link or name or "..."
    end
    for _, previous in ipairs(quest.pre or {}) do
        before[#before + 1] = (QuestDone(previous) and DONE_MARK or "") .. QuestTitle(previous)
    end
    local text = #needs > 0 and L.REQUIRES:format(table.concat(needs, ", ")) or ""
    if #before > 0 then text = text .. (text ~= "" and "   " or "") .. L.PREREQ:format(table.concat(before, ", ")) end
    return text
end

--- Quêtes du donjon, sans celles de la faction adverse (faction inconnue : toutes) ni celles que le serveur ne connaît pas.
local function QuestList()
    local faction = _G.UnitFactionGroup and UnitFactionGroup("player")
    local other = faction == "Alliance" and "h" or faction == "Horde" and "a"
    local quests = {}
    for _, quest in ipairs(current.dungeon.quests or {}) do
        if not (other and quest.side == other) and not db.missingQuests[quest.id] then quests[#quests + 1] = quest end
    end
    NS.CheckQuests(current.dungeon.quests or {})
    return quests
end

local function RefreshQuests()
    local quests = QuestList()
    for i, quest in ipairs(quests) do
        local row = QuestRow(i)
        row.quest = quest
        row.stripe:SetShown(i % 2 == 0)
        local done = QuestDone(quest)
        local active = not done and C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(quest.id)
        row.title:SetText((done and DONE_MARK or "") .. QuestTitle(quest))
        local color = done and QUEST_DONE_COLOR
            or quest.level and _G.GetQuestDifficultyColor and GetQuestDifficultyColor(quest.level) or QUEST_COLOR
        row.title:SetTextColor(color.r, color.g, color.b)
        local side = quest.side == "a" and "  |cff4a9eff" .. (_G.FACTION_ALLIANCE or "Alliance") .. "|r"
            or quest.side == "h" and "  |cffff4040" .. (_G.FACTION_HORDE or "Horde") .. "|r" or ""
        -- Niveau minimum absent des sources : niveau seul ; niveau absent : rien.
        local level = quest.level and (quest.min and L.QUEST_LEVEL:format(quest.level, quest.min)
            or (_G.LEVEL or "Level") .. " " .. quest.level) or ""
        -- XP : celle du journal de quêtes du client si la quête y est, sinon la donnée des concurrents (Data.lua).
        local xp = quest.xp
        if active and _G.GetQuestLogRewardXP then
            local ok, logXP = pcall(GetQuestLogRewardXP, quest.id)
            if ok and type(logXP) == "number" and not isSecret(logXP) then
                -- 0 au niveau maximal : aucune XP, rien d'affiché ; ailleurs, 0 = journal pas encore chargé, Data.lua gardé.
                local maxLevel = _G.GetMaxPlayerLevel and GetMaxPlayerLevel() or 60
                if logXP > 0 then xp = logXP elseif UnitLevel("player") == maxLevel then xp = nil end
            end
        end
        if xp then level = (level ~= "" and level .. "  " or "") .. L.QUEST_XP:format(xp) end
        row.level:SetText(level .. side
            .. (active and "  |cff40c0ff" .. L.QUEST_ACTIVE .. "|r" or ""))
        -- Zone dans la langue du client (carte de zone ou instance), sinon texte du site.
        local mapInfo = quest.zoneMap and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(quest.zoneMap)
        local zone = mapInfo and mapInfo.name
            or quest.zoneInstance and _G.GetRealZoneText and GetRealZoneText(quest.zoneInstance)
        if type(zone) ~= "string" or zone == "" then zone = quest.zone end
        local starter = quest.startItem and L.QUEST_ITEM:format(ItemInfo(quest.startItem) or "...")
        row.giver:SetText(quest.giver and quest.giver .. (zone and ", " .. zone or "") or starter or "")
        row.need:SetText(QuestNeeds(quest))
        for slot, reward in ipairs(row.rewards) do
            local itemID = quest.rewards[slot]
            reward.itemID = itemID
            if itemID then reward.icon:SetTexture(select(4, ItemInfo(itemID)) or 134400) end
            reward:SetShown(itemID ~= nil)
        end
    end
    HideFrom(questRows, #quests + 1)
    UpdateScroll(questScroll, #quests * QUEST_HEIGHT)
    return #quests
end

local function PlacePin(pin, x, y)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", mapFrame, "TOPLEFT", x * MAP_WIDTH, -y * MAP_HEIGHT)
end

local function CursorOnMap()
    local scale = mapFrame:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    local x = (cursorX / scale - mapFrame:GetLeft()) / MAP_WIDTH
    local y = (mapFrame:GetTop() - cursorY / scale) / MAP_HEIGHT
    return math.max(0, math.min(1, x)), math.max(0, math.min(1, y))
end

local function FollowCursor(pin) PlacePin(pin, CursorOnMap()) end

local function BossRow(boss)
    for i, candidate in ipairs(current.dungeon.bosses) do
        if candidate == boss then return bossButtons[i] end
    end
    return nil
end

local function Pin(index)
    local pin = pins[index]
    if pin then return pin end
    pin = CreateFrame("Button", nil, mapFrame)
    pin:SetFrameLevel(mapFrame:GetFrameLevel() + 5)
    pin.glow = pin:CreateTexture(nil, "BACKGROUND")
    pin.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    pin.glow:SetBlendMode("ADD")
    pin.glow:SetVertexColor(1, 0.8, 0.3)
    pin.glow:SetPoint("TOPLEFT", -12, 12)
    pin.glow:SetPoint("BOTTOMRIGHT", 12, -12)
    pin.glow:Hide()
    pin.skull = pin:CreateTexture(nil, "ARTWORK")
    pin.skull:SetAllPoints()
    pin.number = pin:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    pin.number:SetPoint("CENTER", pin, "BOTTOMRIGHT", -3, 4)
    pin:RegisterForDrag("LeftButton")
    pin:SetScript("OnClick", function(self) SelectBoss(self.boss) end)
    pin:SetScript("OnEnter", function(self)
        SetPinHighlight(self.boss, true)
        local row = BossRow(self.boss)
        if row then row:LockHighlight() end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(BossName(self.boss))
        if self.boss.npc then GameTooltip:AddLine(L.DRAG_HINT, 0.6, 0.6, 0.6) end
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function(self)
        SetPinHighlight(self.boss, false)
        local row = BossRow(self.boss)
        if row then row:UnlockHighlight() end
        GameTooltip:Hide()
    end)
    pin:SetScript("OnDragStart", function(self)
        if not (self.boss.npc and IsShiftKeyDown()) then return end
        self.dragging = true
        self:SetScript("OnUpdate", FollowCursor)
    end)
    pin:SetScript("OnHide", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
    end)
    pin:SetScript("OnDragStop", function(self)
        if not self.dragging then return end
        self.dragging = false
        self:SetScript("OnUpdate", nil)
        local x, y = CursorOnMap()
        db.pins[self.boss.npc] = { current.dungeon.floors[current.floor], math.floor(x * 1000 + 0.5) / 1000,
            math.floor(y * 1000 + 0.5) / 1000 }
        Refresh()
    end)
    pins[index] = pin
    return pin
end

local function RefreshMap()
    local dungeon = current.dungeon
    local floors = dungeon.floors
    local floorID = floors[current.floor]
    local art = NS.Floors[floorID] or {}
    -- Carte retail : 4 x 3 tuiles. Minicarte : cols tuiles par ligne, agrandies, vue décalée de left, top tuiles.
    local cols, left, top = art.cols or 4, art.left or 0, art.top or 0
    local size = TILE * MAP_WIDTH / ART_WIDTH * (art.scale or 1)
    for i, tile in ipairs(tiles) do
        tile:SetTexture(art[i])
        tile:SetSize(size, size)
        tile:SetPoint("TOPLEFT", ((i - 1) % cols - left) * size, -(math.floor((i - 1) / cols) - top) * size)
    end
    noMapText:SetShown(floorID == nil)
    floorText:SetText(L.FLOOR:format(current.floor, #floors))
    floorText:SetShown(#floors > 1)
    previousButton:SetShown(#floors > 1)
    nextButton:SetShown(#floors > 1)
    previousButton:SetEnabled(current.floor > 1)
    nextButton:SetEnabled(current.floor < #floors)

    wipe(pinOfBoss)
    local used = 0
    for i, boss in ipairs(dungeon.bosses) do
        local floor, x, y = BossPosition(boss)
        if floor and floor == floorID then
            used = used + 1
            local pin = Pin(used)
            if pin.boss ~= boss then
                pin.dragging = false
                pin:SetScript("OnUpdate", nil)
            end
            pin.boss = boss
            pinOfBoss[boss] = pin
            local killed = IsKilled(boss)
            pin.number:SetText((killed and DONE_MARK or "") .. i)
            SetBossPortrait(pin.skull, boss)
            pin.skull:SetDesaturated(killed)
            pin:SetFrameLevel(mapFrame:GetFrameLevel() + (boss == current.boss and 10 or 5))
            PlacePin(pin, x, y)
            pin:Show()
            SetPinHighlight(boss, false)
        end
    end
    HideFrom(pins, used + 1)
    -- Passages vers un autre étage du donjon : flèche cliquable qui ouvre l'étage cible.
    NS.floorLinkButtons = NS.floorLinkButtons or {}
    local links, shown = NS.FloorLinks and NS.FloorLinks[floorID] or {}, 0
    for i = 1, #links, 3 do
        local target
        for index, floor in ipairs(floors) do
            if floor == links[i + 2] then target = index end
        end
        if target then
            shown = shown + 1
            local link = NS.floorLinkButtons[shown]
            if not link then
                link = CreateFrame("Button", nil, mapFrame)
                link:SetSize(22, 22)
                link:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
                link:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
                link:SetScript("OnClick", function(self)
                    current.floor = self.target
                    Refresh()
                end)
                link:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(L.FLOOR:format(self.target, #current.dungeon.floors))
                    GameTooltip:Show()
                end)
                link:SetScript("OnLeave", function() GameTooltip:Hide() end)
                NS.floorLinkButtons[shown] = link
            end
            link.target = target
            link:SetFrameLevel(mapFrame:GetFrameLevel() + 4)
            PlacePin(link, links[i], links[i + 1])
            link:Show()
        end
    end
    HideFrom(NS.floorLinkButtons, shown + 1)
    NS.ShowMapFloor(floorID)
end

--- Fil d'Ariane : Accueil > donjon > boss, chaque bouton à la largeur de son texte.
local function RefreshNavigation()
    local dungeon = not current.search and current.dungeon or nil
    homeButton:SetEnabled(dungeon ~= nil or current.wishlist == true or current.search ~= nil)
    homeButton:Show()
    wishButton:SetEnabled(not current.wishlist or current.search ~= nil)
    wishButton:Show()
    dungeonCrumb:SetShown(dungeon ~= nil)
    bossCrumb:SetShown(dungeon ~= nil and current.boss ~= nil)
    if dungeon then
        dungeonCrumb:SetText(DungeonName(dungeon))
        dungeonCrumb:SetWidth((dungeonCrumb:GetTextWidth() or 0) + 30)
    end
    if dungeon and current.boss then bossCrumb:SetText("> " .. BossName(current.boss)) end
end

function Refresh()
    if NS.UpdateRunHud then NS.UpdateRunHud() end
    if not (frame and frame:IsShown()) then return end
    local searching = current.search ~= nil
    local inDungeon = current.dungeon ~= nil and not searching
    local home = not inDungeon and not current.wishlist and not searching
    homeView:SetShown(home)
    wishView:SetShown(current.wishlist == true and not searching)
    searchUI.view:SetShown(searching)
    instanceView:SetShown(inDungeon)
    RefreshNavigation()
    for _, tab in ipairs(sideTabs) do
        tab:SetShown(inDungeon)
        tab.selected:SetShown(tab.key == current.tab)
    end
    if searching then
        RefreshSearch()
        return
    end
    if current.wishlist then
        RefreshWishlist()
        return
    end
    if home then
        RefreshDungeons()
        return
    end
    for key, page in pairs(pages) do page:SetShown(key == current.tab) end
    pages.abilities.share:SetShown(current.boss ~= nil and current.boss.tactic ~= nil)
    local bossName = current.boss and BossName(current.boss)
    local TITLES = { map = L.MAP, loot = bossName or L.ALL_LOOT, abilities = bossName or L.ABILITIES, quests = L.QUESTS }
    pageTitle:SetText(TITLES[current.tab])
    RefreshBossList()
    local PAGES = { map = RefreshMap, loot = RefreshLoot, abilities = RefreshAbilities, quests = RefreshQuests }
    local count = PAGES[current.tab]()
    if current.tab == "map" then
        emptyText:Hide()
        return
    end
    local EMPTY = { abilities = L.NO_ABILITIES, quests = L.NO_QUESTS }
    if current.tab == "loot" then EMPTY.loot = #LootList(true) > 0 and L.NO_MATCH or L.NO_LOOT end
    emptyText:SetText(EMPTY[current.tab])
    emptyText:SetShown(count == 0)
end
NS.Refresh = Refresh

--------------------------------------------------------------------------------
-- Fenêtre
--------------------------------------------------------------------------------

local function SavePosition()
    local x, y = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    db.position = { math.floor(x * scale - parentX + 0.5), math.floor(y * scale - parentY + 0.5) }
end

local function ChangeFloor(direction)
    local target = current.floor + direction
    if target < 1 or target > #current.dungeon.floors then return end
    current.floor = target
    Refresh()
end

local function ArrowButton(parent, direction)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(26, 26)
    local page = direction < 0 and "Prev" or "Next"
    button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. page .. "Page-Up")
    button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. page .. "Page-Down")
    button:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. page .. "Page-Disabled")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    button:SetScript("OnClick", function() ChangeFloor(direction) end)
    return button
end

local function NavigationButton(text, onClick)
    local button = TemplatedFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetHeight(22)
    button:SetText(text)
    button:SetWidth((button:GetTextWidth() or 0) + 30)
    button:SetScript("OnClick", onClick)
    return button
end

--- Onglet latéral façon retail, collé au bord droit de la fenêtre.
local function SideTab(index, key, icon, label)
    local tab = CreateFrame("Button", nil, frame)
    tab:SetSize(40, 40)
    tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", -2, -70 - (index - 1) * 46)
    tab.key = key
    Fill(tab, 0, 0, 0, 0.9)
    AddBorder(tab, GOLD[1], GOLD[2], GOLD[3], 1)
    local image = tab:CreateTexture(nil, "ARTWORK")
    image:SetPoint("TOPLEFT", 5, -5)
    image:SetPoint("BOTTOMRIGHT", -5, 5)
    image:SetTexture(icon)
    image:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    tab.selected = tab:CreateTexture(nil, "OVERLAY")
    tab.selected:SetAllPoints()
    tab.selected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    tab.selected:SetBlendMode("ADD")
    Highlight(tab, 0.2)
    tab:SetScript("OnClick", function() SelectTab(key) end)
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(label)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", GameTooltip_Hide)
    sideTabs[index] = tab
end

--- Barre de filtres du butin : recherche par nom, menus des emplacements et des types du donjon.
local function CreateLootFilters(page)
    local function Changed()
        ScrollTo(lootScroll, 0)
        Refresh()
    end
    local search = TemplatedFrame("EditBox", nil, page, "SearchBoxTemplate")
    search:SetSize(160, 20)
    search:SetPoint("TOPLEFT", 16, -41)
    search:SetAutoFocus(false)
    search:HookScript("OnTextChanged", function(self)
        filter.search = Fold(self:GetText() or "")
        Changed()
    end)
    -- Choix "" = tous. Le menu relit le butin du donjon à chaque ouverture.
    local function Menu(key, allLabel, rank, x)
        local ok, menu = pcall(CreateFrame, "DropdownButton", nil, page, "WowStyle1DropdownTemplate")
        if not (ok and menu and menu.SetupMenu) then return end
        menu:SetWidth(150)
        menu:SetPoint("LEFT", search, "RIGHT", x, 0)
        local function IsChosen(value) return (filter[key] or "") == value end
        local function Choose(value)
            filter[key] = value ~= "" and value or nil
            Changed()
        end
        menu:SetupMenu(function(_, root)
            root:CreateRadio(allLabel, IsChosen, Choose, "")
            if key == "kind" and ClassGear() then root:CreateRadio(L.MY_CLASS, IsChosen, Choose, CLASS_KIND) end
            for _, value in ipairs(FilterChoices(rank)) do root:CreateRadio(value, IsChosen, Choose, value) end
        end)
        filter.menus[#filter.menus + 1] = menu
    end
    Menu("slot", L.ALL_SLOTS, 1, 12)
    Menu("kind", L.ALL_TYPES, 2, 170)
end

local function CreateHome(inset)
    homeView = CreateFrame("Frame", nil, inset)
    homeView:SetAllPoints()
    local background = homeView:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    local atlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(TIER_ATLAS)
    if atlas then background:SetAtlas(TIER_ATLAS) else background:SetColorTexture(0.1, 0.08, 0.06, 1) end
    gridScroll, gridContent = CreateScrollList(homeView, INSET_WIDTH, INSET_HEIGHT)
end

local function CreateWishlist(inset)
    wishView = CreateFrame("Frame", nil, inset)
    wishView:SetAllPoints()
    Fill(wishView, 0.05, 0.045, 0.04, 1)
    wishScroll, wishContent = CreateScrollList(wishView, INSET_WIDTH, INSET_HEIGHT)
    wishEmpty = wishView:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    wishEmpty:SetPoint("TOP", 0, -40)
    wishEmpty:SetText(L.MSG_WISHLIST_EMPTY)
end

local function CreateSearch(inset)
    searchUI.view = CreateFrame("Frame", nil, inset)
    searchUI.view:SetAllPoints()
    Fill(searchUI.view, 0.05, 0.045, 0.04, 1)
    searchUI.scroll, searchUI.content = CreateScrollList(searchUI.view, INSET_WIDTH, INSET_HEIGHT)
    searchUI.empty = searchUI.view:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    searchUI.empty:SetPoint("TOP", 0, -40)
    searchUI.empty:SetText(L.NO_RESULTS)
end

--- Point de carte sur l'entrée du donjon, suivi par la flèche du client. Seconde entrée si le joueur est sur sa carte.
local function SetEntranceWaypoint(dungeon)
    local entrance, second = dungeon.entrance, dungeon.secondEntrance
    -- Seconde entrée seulement si sa carte accepte un point de route ; sinon repli sur l'entrée principale.
    if second and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") == second.map
        and not (C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(second.map)) then entrance = second end
    if SetWaypoint(entrance.map, entrance.x, entrance.y) then Print(L.WAYPOINT_SET:format(DungeonName(dungeon))) end
end

local function CreateInstance(inset)
    instanceView = CreateFrame("Frame", nil, inset)
    instanceView:SetAllPoints()

    -- Page de gauche : image du donjon, titre, liste des boss.
    local left = CreateFrame("Frame", nil, instanceView)
    left:SetPoint("TOPLEFT")
    left:SetSize(LEFT_WIDTH, INSET_HEIGHT)
    Fill(left, PAGE[1], PAGE[2], PAGE[3], 1)
    loreArt = left:CreateTexture(nil, "BORDER")
    loreArt:SetPoint("TOPLEFT")
    loreArt:SetSize(LEFT_WIDTH, math.floor(LEFT_WIDTH * 289 / 390 + 0.5))
    loreArt:SetTexCoord(0, 0.76171875, 0, 0.564453125)
    local fade = left:CreateTexture(nil, "ARTWORK")
    fade:SetPoint("BOTTOMLEFT", loreArt, "BOTTOMLEFT")
    fade:SetPoint("BOTTOMRIGHT", loreArt, "BOTTOMRIGHT")
    fade:SetHeight(120)
    Gradient(fade, PAGE, 1, 0)
    local shade = left:CreateTexture(nil, "ARTWORK")
    shade:SetPoint("TOPLEFT")
    shade:SetPoint("TOPRIGHT")
    shade:SetHeight(90)
    Gradient(shade, { 0, 0, 0 }, 0, 0.75)
    AddBorder(left, GOLD[1], GOLD[2], GOLD[3], 0.5)

    dungeonTitle = left:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    dungeonTitle:SetPoint("TOPLEFT", 14, -14)
    dungeonTitle:SetPoint("TOPRIGHT", -14, -14)
    dungeonTitle:SetJustifyH("LEFT")
    dungeonTitle:SetMaxLines(2)
    dungeonTitle:SetShadowOffset(1, -1)
    dungeonLevels = left:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dungeonLevels:SetPoint("TOPLEFT", dungeonTitle, "BOTTOMLEFT", 0, -4)
    dungeonLevels:SetShadowOffset(1, -1)

    waypointButton = TemplatedFrame("Button", nil, left, "UIPanelButtonTemplate")
    waypointButton:SetHeight(20)
    waypointButton:SetText(L.WAYPOINT)
    waypointButton:SetWidth((waypointButton:GetTextWidth() or 0) + 24)
    waypointButton:SetPoint("TOPRIGHT", -10, -94)
    waypointButton:SetScript("OnClick", function() SetEntranceWaypoint(current.dungeon) end)

    local bossArea = CreateFrame("Frame", nil, left)
    bossArea:SetPoint("TOPLEFT", 0, -120)
    bossArea:SetSize(LEFT_WIDTH, INSET_HEIGHT - 124)
    bossScroll, bossContent = CreateScrollList(bossArea, LEFT_WIDTH, INSET_HEIGHT - 124)

    -- Page de droite : carte ou butin, selon l'onglet latéral.
    local right = CreateFrame("Frame", nil, instanceView)
    right:SetPoint("TOPRIGHT")
    right:SetSize(RIGHT_WIDTH, INSET_HEIGHT)
    Fill(right, 0.05, 0.045, 0.04, 1)
    AddBorder(right, GOLD[1], GOLD[2], GOLD[3], 0.5)
    pageTitle = right:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    pageTitle:SetPoint("TOPLEFT", 12, -12)
    pageTitle:SetPoint("TOPRIGHT", -150, -12)
    pageTitle:SetJustifyH("LEFT")
    pageTitle:SetWordWrap(false)
    local rule = right:CreateTexture(nil, "BORDER")
    rule:SetPoint("TOPLEFT", 10, -36)
    rule:SetPoint("TOPRIGHT", -10, -36)
    rule:SetHeight(1)
    rule:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.5)

    local mapPage = CreateFrame("Frame", nil, right)
    mapPage:SetAllPoints()
    nextButton = ArrowButton(mapPage, 1)
    nextButton:SetPoint("TOPRIGHT", -8, -6)
    floorText = mapPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    floorText:SetPoint("RIGHT", nextButton, "LEFT", -4, 0)
    previousButton = ArrowButton(mapPage, -1)
    previousButton:SetPoint("RIGHT", floorText, "LEFT", -4, 0)

    local mapBorder = CreateFrame("Frame", nil, mapPage)
    mapBorder:SetPoint("TOPLEFT", 9, -45)
    mapBorder:SetSize(MAP_WIDTH + 2, MAP_HEIGHT + 2)
    Fill(mapBorder, 0, 0, 0, 1)
    AddBorder(mapBorder, GOLD[1], GOLD[2], GOLD[3], 0.8)
    -- La vue coupe ; mapFrame, zoomé et déplacé par MapCanvas.lua, porte tuiles, repères et traits.
    local viewport = CreateFrame("Frame", nil, mapBorder)
    viewport:SetSize(MAP_WIDTH, MAP_HEIGHT)
    viewport:SetPoint("TOPLEFT", 1, -1)
    viewport:SetClipsChildren(true)
    mapFrame = CreateFrame("Frame", nil, viewport)
    mapFrame:SetSize(MAP_WIDTH, MAP_HEIGHT)
    mapFrame:SetPoint("TOPLEFT")
    for i = 1, 12 do tiles[i] = mapFrame:CreateTexture(nil, "BACKGROUND") end   -- placées par RefreshMap
    noMapText = mapFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    noMapText:SetPoint("CENTER")
    noMapText:SetText(L.NO_MAP)
    noMapText:Hide()
    local hint = mapPage:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", mapBorder, "BOTTOMLEFT", 0, -8)
    hint:SetText(L.MAP_HINT .. "   " .. L.DRAG_HINT)
    local clearButton = TemplatedFrame("Button", nil, mapPage, "UIPanelButtonTemplate")
    clearButton:SetSize(90, 22)
    clearButton:SetPoint("TOPRIGHT", mapBorder, "BOTTOMRIGHT", 0, -4)
    clearButton:SetText(L.CLEAR_DRAWING)
    local drawButton = TemplatedFrame("Button", nil, mapPage, "UIPanelButtonTemplate")
    drawButton:SetSize(90, 22)
    drawButton:SetPoint("RIGHT", clearButton, "LEFT", -4, 0)
    drawButton:SetText(L.DRAW)
    hint:SetPoint("TOPRIGHT", drawButton, "TOPLEFT", -8, -4)
    hint:SetJustifyH("LEFT")
    NS.AttachMapCanvas(viewport, mapFrame, drawButton, clearButton)

    pages.map = mapPage
    local function ListPage(key, barHeight)
        local page = CreateFrame("Frame", nil, right)
        page:SetAllPoints()
        local area = CreateFrame("Frame", nil, page)
        area:SetPoint("TOPLEFT", 4, -42 - barHeight)
        area:SetSize(RIGHT_WIDTH - 8, INSET_HEIGHT - 46 - barHeight)
        pages[key] = page
        return CreateScrollList(area, RIGHT_WIDTH - 8, INSET_HEIGHT - 46 - barHeight)
    end
    lootScroll, lootContent = ListPage("loot", FILTER_HEIGHT)
    CreateLootFilters(pages.loot)
    abilityScroll, abilityContent = ListPage("abilities", 0)
    local share = TemplatedFrame("Button", nil, pages.abilities, "UIPanelButtonTemplate")
    share:SetSize(140, 22)
    share:SetPoint("TOPRIGHT", -8, -8)
    share:SetText(L.SHARE)
    share:SetScript("OnClick", function() ShareTactic(current.boss) end)
    pages.abilities.share = share
    questScroll, questContent = ListPage("quests", 0)
    emptyText = right:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOP", 0, -70)
    emptyText:Hide()
end

local function CreateJournal()
    frame = TemplatedFrame("Frame", "AeonDungeonJournalFrame", UIParent, "PortraitFrameTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    -- Position enregistrée en unités d'UIParent, décalage du point en unités du cadre : divisé par l'échelle.
    local position, scale = db.position, db.scale or 1
    frame:SetScale(scale)
    frame:SetPoint("CENTER", UIParent, "CENTER", (position and position[1] or 0) / scale, (position and position[2] or 0) / scale)
    -- Poignée : l'échelle de la fenêtre suit le curseur, coin haut gauche fixe.
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    local function StopSizing()
        if not grip:GetScript("OnUpdate") then return end
        grip:SetScript("OnUpdate", nil)
        db.scale = frame:GetScale()
        SavePosition()
    end
    frame:HookScript("OnHide", StopSizing)   -- fermée pendant le geste : échelle enregistrée quand même
    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local frameScale, parentScale = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
        local left, top = frame:GetLeft() * frameScale, frame:GetTop() * frameScale   -- pixels écran
        local grab = left + FRAME_WIDTH * frameScale - GetCursorPosition()   -- écart curseur / bord droit
        grip:SetScript("OnUpdate", function()
            if not IsMouseButtonDown("LeftButton") then return StopSizing() end
            local newScale = math.max(0.6, math.min(1.6, (GetCursorPosition() + grab - left) / (FRAME_WIDTH * parentScale)))
            frame:SetScale(newScale)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / (newScale * parentScale), top / (newScale * parentScale))
        end)
    end)
    tinsert(UISpecialFrames, frame:GetName())
    if frame.SetTitle then frame:SetTitle(L.TITLE) end
    if frame.SetPortraitToAsset then frame:SetPortraitToAsset(PORTRAIT) end

    homeButton = NavigationButton(L.HOME, function()
        current.dungeon, current.boss, current.wishlist = nil, nil, nil
        if current.search then searchUI.box:SetText("") else Refresh() end
    end)
    homeButton:SetPoint("TOPLEFT", 64, -30)
    dungeonCrumb = NavigationButton("", function() if current.boss then SelectBoss(current.boss) end end)
    dungeonCrumb:SetPoint("LEFT", homeButton, "RIGHT", 2, 0)
    bossCrumb = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bossCrumb:SetPoint("LEFT", dungeonCrumb, "RIGHT", 8, 0)
    wishButton = NavigationButton(WISH_MARK .. L.WISHLIST, function()
        current.dungeon, current.boss, current.wishlist = nil, nil, true
        if current.search then searchUI.box:SetText("") else Refresh() end
    end)
    wishButton:SetPoint("TOPRIGHT", -12, -30)
    -- Recherche dans le butin de tous les donjons, à partir de 2 caractères.
    searchUI.box = TemplatedFrame("EditBox", nil, frame, "SearchBoxTemplate")
    searchUI.box:SetSize(180, 20)
    searchUI.box:SetPoint("RIGHT", wishButton, "LEFT", -10, 0)
    searchUI.box:SetAutoFocus(false)
    if type(searchUI.box.Instructions) == "table" then searchUI.box.Instructions:SetText(L.SEARCH_ALL) end

    local inset = TemplatedFrame("Frame", nil, frame, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", 6, -60)
    inset:SetSize(INSET_WIDTH, INSET_HEIGHT)
    CreateHome(inset)
    CreateWishlist(inset)
    CreateSearch(inset)
    CreateInstance(inset)
    SideTab(1, "map", ICON, L.MAP)
    SideTab(2, "loot", "Interface\\Icons\\INV_Misc_Bag_10", L.LOOT)
    SideTab(3, "abilities", "Interface\\Icons\\INV_Misc_Book_09", L.ABILITIES)
    SideTab(4, "quests", "Interface\\Icons\\INV_Misc_Note_01", L.QUESTS)
    searchUI.box:HookScript("OnTextChanged", function(self)
        local text = Fold(self:GetText() or "")
        local letters = select(2, text:gsub("[^\128-\191]", ""))   -- caractères UTF-8, pas octets
        current.search = letters >= 2 and text or nil
        ScrollTo(searchUI.scroll, 0)
        Refresh()
    end)

    frame:SetScript("OnShow", Refresh)
    frame:Hide()
end

--- Donjon où se trouve le joueur. Ailes d'une même instance (Monastère, Hache-Tripes) : celle dont une carte est
--- celle du joueur ; cartes partagées (Pic Rochenoire) : celle du run en cours ; sinon la première.
local function CurrentDungeon()
    if not _G.GetInstanceInfo then return nil end
    local instanceID = select(8, GetInstanceInfo())
    if isSecret(instanceID) then return nil end
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if isSecret(mapID) then mapID = nil end
    local best, bestScore = nil, -1
    for _, dungeon in ipairs(NS.Dungeons) do
        if dungeon.instance == instanceID and not dungeon.upcoming then
            local score = db and dungeon.key == db.killsDungeon and 1 or 0
            for _, floorID in ipairs(mapID and dungeon.floors or {}) do
                if floorID == mapID then score = score + 2 end
            end
            if score > bestScore then best, bestScore = dungeon, score end
        end
    end
    return best
end

NS.CurrentDungeon = CurrentDungeon

local function Toggle()
    if not frame then CreateJournal() end
    if frame:IsShown() then frame:Hide() return end
    local here = CurrentDungeon()
    if here and not (current.dungeon and current.dungeon.instance == here.instance) then SelectDungeon(here) end
    frame:Show()
end

NS.Toggle, NS.ICON = Toggle, ICON

--- Journal ouvert sur ce boss (Maj-clic dans le suivi de run).
function NS.OpenBoss(boss)
    if not frame then CreateJournal() end
    if current.dungeon ~= boss.dungeon then SelectDungeon(boss.dungeon) end
    if current.boss ~= boss then SelectBoss(boss) end
    frame:Show()
    Refresh()
end

--------------------------------------------------------------------------------
-- Bouton de la minicarte : clic pour ouvrir, glisser pour le faire tourner autour
--------------------------------------------------------------------------------

local function PlaceMinimapButton(button)
    local angle = math.rad(db.minimapAngle or 200)
    local radius = Minimap:GetWidth() / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function MinimapAngleFromCursor()
    local centerX, centerY = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    return math.floor(math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX)) + 0.5) % 360
end

local function CreateMinimapButton()
    local button = CreateFrame("Button", "AeonDungeonJournalMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)
    icon:SetTexture(ICON)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetScript("OnClick", Toggle)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            db.minimapAngle = MinimapAngleFromCursor()
            PlaceMinimapButton(self)
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L.TITLE)
        GameTooltip:AddLine(L.MINIMAP_HINT, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    PlaceMinimapButton(button)
    button:SetShown(not db.hideMinimap)
    NS.minimapButton = button
end

--------------------------------------------------------------------------------
-- Démarrage et commandes
--------------------------------------------------------------------------------

local events = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "QUEST_TURNED_IN", "QUEST_ACCEPTED",
                         "QUEST_REMOVED", "PLAYER_LEVEL_UP" }) do
    events:RegisterEvent(event)
end

local DELAYED_REFRESH = { QUEST_TURNED_IN = true, QUEST_ACCEPTED = true, QUEST_REMOVED = true, PLAYER_LEVEL_UP = true }
events:SetScript("OnEvent", function(_, event, first, second)
    if event == "QUEST_TURNED_IN" and type(first) == "number" and not isSecret(first) then turnedIn[first] = true end
    if event == "ADDON_LOADED" and first == ADDON_NAME then
        -- WoW Forever ne relit pas la SavedVariables de compte : Mirror.lua fournit les replis.
        db = NS.Mirror:Load(_G[DB_NAME]) or {}
        _G[DB_NAME] = db
        NS.db = db
        db.pins = db.pins or {}
        db.recorded = db.recorded or {}
        db.wishlists = db.wishlists or {}
        db.kills = db.kills or {}
        db.found = db.found or {}
        db.runs = db.runs or {}
        db.bossKills = db.bossKills or {}
        db.drops = db.drops or {}
        db.missingQuests = db.missingQuests or {}
        db.bossLevels = db.bossLevels or {}
        db.entrances = db.entrances or {}
        NS.Mirror.IGNORE.recorded = true   -- trop gros pour les CVars ; la table hôte le garde
        NS.Mirror.IGNORE.drops = true
        NS.Mirror:Watch(db, { pins = {}, recorded = {}, wishlists = {}, kills = {}, found = {}, runs = {}, bossKills = {}, drops = {},
            missingQuests = {}, bossLevels = {}, entrances = {} })
        CreateMinimapButton()
        NS.LoadFoundBosses()
    elseif not db then
        return
    elseif event == "PLAYER_LOGIN" then
        local name = UnitName("player")
        if isSecret(name) then return end   -- nom illisible : liste en lecture seule vide
        character = name .. "-" .. GetNormalizedRealmName()
        -- Liste d'avant 1.5, commune au compte : reprise par le premier personnage connecté.
        if db.wishlist then
            local list = Wishes()
            for itemID in pairs(db.wishlist) do list[itemID] = true end
            db.wishlist = nil
        end
    elseif (DELAYED_REFRESH[event]
        or (event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED") and current.wishlist
        or event == "GET_ITEM_INFO_RECEIVED" and second and not isSecret(second) and frame and frame:IsShown()
            and (current.dungeon or current.wishlist or current.search))
        and not refreshPending then
        refreshPending = true
        C_Timer.After(0.2, function()
            refreshPending = false
            Refresh()
        end)
    end
end)

SLASH_AEONDUNGEONJOURNAL1 = "/codex"
SLASH_AEONDUNGEONJOURNAL2 = "/aeondungeonjournal"
SlashCmdList.AEONDUNGEONJOURNAL = function(message)
    message = (message or ""):lower():match("^%s*(.-)%s*$")
    if message == "resetpins" then
        wipe(db.pins)
        Print(L.MSG_PINS_RESET)
        Refresh()
    elseif message == "wipe" then
        wipe(db.recorded)
        Print(L.MSG_WIPED)
        Refresh()
    elseif message == "resetkills" then
        ClearKills()
        Print(L.MSG_KILLS_RESET)
        Refresh()
    elseif message == "clearwishlist" then
        wipe(Wishes())
        NS.ShareWishes()
        Print(L.MSG_WISHLIST_CLEARED)
        Refresh()
    elseif message == "tooltip" then
        db.hideTooltip = not db.hideTooltip or nil
        Print(db.hideTooltip and L.MSG_TOOLTIP_OFF or L.MSG_TOOLTIP_ON)
    elseif message == "wishlist" then
        local items = WishList()
        for _, item in ipairs(items) do
            local name, link = ItemInfo(item.id)
            local boss = item.boss
            Print((link or name or ("item:" .. item.id)) .. (boss and " - " .. DungeonName(boss.dungeon) .. ", " .. BossName(boss) or ""))
        end
        if #items == 0 then Print(L.MSG_WISHLIST_EMPTY) end
    elseif message == "runs" then
        -- Run en cours (ou dernier, pas encore archivé) d'abord, puis l'historique du plus récent au plus ancien ;
        -- durée du premier au dernier boss. Ailes d'une même instance : nom par la clé du donjon, instance en repli.
        local runs, count = {}, 0
        for _ in pairs(db.kills) do count = count + 1 end
        if count > 0 and db.killsAt then
            runs[1] = { instance = db.killsInstance, dungeon = db.killsDungeon, start = db.killsStart or db.killsAt, finish = db.killsAt, bosses = count }
        end
        for i = #db.runs, 1, -1 do runs[#runs + 1] = db.runs[i] end
        for i = 1, math.min(#runs, 10) do
            local run, name = runs[i], tostring(runs[i].instance)
            for _, dungeon in ipairs(NS.Dungeons) do
                if dungeon.key == run.dungeon or not run.dungeon and dungeon.instance == run.instance then
                    name = DungeonName(dungeon)
                    break
                end
            end
            Print(L.MSG_RUN:format(date("%Y-%m-%d %H:%M", run.start), name, run.bosses, math.floor((run.finish - run.start) / 60 + 0.5)))
        end
        if #runs == 0 then Print(L.MSG_NO_RUNS) end
    elseif message == "options" then
        NS.OpenOptions()
    elseif NS.RunCommand(message) then
        return
    elseif message == "help" then
        Print(L.HELP)
        Print(L.HELP_TOOLTIP)
        Print(L.HELP_WISHLIST)
        Print(L.HELP_RUNS)
        Print(L.HELP_HUD)
        Print(L.HELP_PREP)
        Print(L.HELP_VALUE)
        Print(L.HELP_RESET)
        Print(L.HELP_OPTIONS)
    else
        Toggle()
    end
end
