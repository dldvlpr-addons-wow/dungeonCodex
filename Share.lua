-- Share.lua
-- Listes de souhaits partagées dans le groupe par message d'addon : chacun envoie la sienne quand le groupe
-- change ou quand il coche un objet, et l'infobulle d'un objet nomme les membres qui le souhaitent.
-- Format : "=" suivi des itemID séparés par des virgules (remplace la liste), puis "+" pour la suite.
-- "!" au lieu de "=" : premier envoi après l'entrée dans le groupe ou un /reload, les autres répondent par leur liste.
local _, NS = ...

local isSecret = _G.issecretvalue or function() return false end
local PREFIX = "DCodexWish"
local MAX_MESSAGE = 250            -- limite du client : 255 octets
local SEND_DELAY, RETRY_DELAY = 2, 10
local R = Enum and Enum.SendAddonMessageResult or {}
local RETRY = { [R.AddonMessageThrottle or 3] = true, [R.ChannelThrottle or 8] = true, [R.AddOnMessageLockdown or 11] = true }

local groupWishes = {}             -- [nom du membre] = { [itemID] = true }
local sendPending, askReply, wasInGroup, loggedIn = false, false, false, false
local GROUP_CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true }

local function Channel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not IsInGroup(LE_PARTY_CATEGORY_HOME) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function Send()
    sendPending = false
    local channel = Channel()
    if not channel then return end
    local ids = {}
    for itemID in pairs(NS.Wishes()) do ids[#ids + 1] = tostring(itemID) end
    local messages, current = {}, askReply and "!" or "="
    for _, id in ipairs(ids) do
        if #current + #id + 1 > MAX_MESSAGE then
            messages[#messages + 1] = current
            current = "+"
        end
        current = current .. (current:find("%d$") and "," or "") .. id
    end
    messages[#messages + 1] = current
    for _, message in ipairs(messages) do
        local result = C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
        if RETRY[result] then
            -- Limite de débit ou blocage : liste complète renvoyée plus tard, le "=" efface la partie reçue.
            sendPending = true
            C_Timer.After(RETRY_DELAY, Send)
            return
        elseif result ~= 0 then
            return   -- hors groupe entre-temps, ou refus : la suite serait refusée aussi
        end
    end
    askReply = false
end

--- Envoi regroupé : plusieurs déclencheurs proches ne partent qu'une fois.
local function ShareWishes()
    if sendPending then return end
    sendPending = true
    C_Timer.After(SEND_DELAY, Send)
end
NS.ShareWishes = ShareWishes

--- Membres du groupe (hors soi) qui souhaitent cet objet, triés.
function NS.WishedBy(itemID)
    local names = {}
    for name, wishes in pairs(groupWishes) do
        if wishes[itemID] then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end

local function InGroup(name)
    local inRaid = UnitInRaid(name)
    return UnitInParty(name) or isSecret(inRaid) or inRaid ~= nil   -- secret : gardé dans le doute
end

--- Nom de l'expéditeur d'un message d'addon reçu d'un autre membre du groupe, sinon nil.
local function GroupSender(message, channel, sender)
    if type(message) ~= "string" or type(sender) ~= "string" or isSecret(message) or isSecret(sender)
        or not GROUP_CHANNELS[channel] then return nil end
    local name = Ambiguate(sender, "none")
    local me = UnitName("player")
    if isSecret(me) or name == me or not InGroup(name) then return nil end
    return name
end
NS.GroupSender, NS.GroupChannel = GroupSender, Channel

local function Receive(message, channel, sender)
    local name = GroupSender(message, channel, sender)
    if not name then return end
    local mode, list = message:sub(1, 1), message:sub(2)
    if mode == "=" or mode == "!" then
        groupWishes[name] = {}
        if mode == "!" then ShareWishes() end
    elseif mode ~= "+" or not groupWishes[name] then
        return
    end
    for id in list:gmatch("%d+") do groupWishes[name][tonumber(id)] = true end
end

--- Membres partis oubliés ; hors groupe, tout est oublié. À l'entrée dans le groupe (ou au /reload), liste
--- envoyée avec demande de réponse.
local function RosterChanged()
    if not loggedIn then return end   -- avant PLAYER_LOGIN : liste du personnage pas encore connue
    if not IsInGroup() then
        wipe(groupWishes)
        wasInGroup = false
        return
    end
    for name in pairs(groupWishes) do
        if not InGroup(name) then groupWishes[name] = nil end
    end
    if not wasInGroup then
        wasInGroup, askReply = true, true
        ShareWishes()
    end
end

local registered = C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
if registered ~= 0 and registered ~= 1 then NS.Print("DCodexWish: RegisterAddonMessagePrefix " .. tostring(registered)) end
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" then
        if prefix == PREFIX then Receive(message, channel, sender) end
    else
        loggedIn = loggedIn or event == "PLAYER_LOGIN"
        RosterChanged()
    end
end)
