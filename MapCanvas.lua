-- MapCanvas.lua
-- Carte d'étage : zoom à la molette autour du curseur, déplacement par glisser, et traits dessinés à la main,
-- partagés avec les membres du groupe qui ont l'addon.
-- Messages : "S" .. étage .. ":" puis 6 chiffres par point (x puis y, de 000 à 999) ajoute un trait ;
-- "C" .. étage efface les traits de cet étage chez tout le groupe.
local _, NS = ...

local PREFIX = "DCodexDraw"
local MAX_ZOOM, ZOOM_STEP = 4, 1.25
local POINTS_PER_MESSAGE = 40               -- "S" + étage + ":" + 40 * 6 chiffres < 255 octets
local MAX_POINTS, MAX_STROKES = 200, 100    -- par trait, par étage
local MIN_STEP = 0.008                      -- écart minimal entre deux points, en fraction de la carte
local RETRY_DELAY, MAX_QUEUE = 2, 30       -- secondes ; traits en attente d'envoi
local R = Enum and Enum.SendAddonMessageResult or {}
local RETRY = { [R.AddonMessageThrottle or 3] = true, [R.ChannelThrottle or 8] = true, [R.AddOnMessageLockdown or 11] = true }

local viewport, canvas, width, height
local zoom, offsetX, offsetY = 1, 0, 0      -- coin haut gauche de la carte : à gauche de la vue, au-dessus de la vue
local shownFloor, drawing, action
local strokes = {}                          -- [étage] = { { x1, y1, x2, y2, ... }, ... }, coordonnées 0..1
local lines, usedLines = {}, 0
local queue, sending = {}, false            -- file de traits : { messages, envoyés jusqu'à l'indice sent }

local function Clamp(value) return math.max(0, math.min(1, value)) end

--------------------------------------------------------------------------------
-- Zoom et déplacement
--------------------------------------------------------------------------------

local function Apply()
    offsetX = math.max(width * (1 - zoom), math.min(0, offsetX))
    offsetY = math.max(0, math.min(height * (zoom - 1), offsetY))
    canvas:SetScale(zoom)
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", viewport, "TOPLEFT", offsetX / zoom, offsetY / zoom)   -- décalage en unités de la carte
end

--- Curseur dans la vue : x vers la droite, y vers le bas, en unités de la vue.
local function CursorInView()
    local scale = viewport:GetEffectiveScale()
    local x, y = GetCursorPosition()
    return x / scale - viewport:GetLeft(), viewport:GetTop() - y / scale
end

local function CursorOnCanvas()
    local x, y = CursorInView()
    return Clamp((x - offsetX) / zoom / width), Clamp((y + offsetY) / zoom / height)
end

--- Le point de la carte sous le curseur y reste.
local function Zoom(delta)
    local x, y = CursorInView()
    local u, v = (x - offsetX) / zoom, (y + offsetY) / zoom
    zoom = math.max(1, math.min(MAX_ZOOM, zoom * ZOOM_STEP ^ delta))
    offsetX, offsetY = x - u * zoom, v * zoom - y
    Apply()
end

--------------------------------------------------------------------------------
-- Traits
--------------------------------------------------------------------------------

local function Line(x1, y1, x2, y2)
    usedLines = usedLines + 1
    local line = lines[usedLines]
    if not line then
        line = canvas:CreateLine(nil, "ARTWORK")
        line:SetTexture("Interface\\Buttons\\WHITE8X8")
        line:SetVertexColor(1, 0.25, 0.1)
        line:SetThickness(2)
        lines[usedLines] = line
    end
    line:SetStartPoint("TOPLEFT", canvas, x1 * width, -y1 * height)
    line:SetEndPoint("TOPLEFT", canvas, x2 * width, -y2 * height)
    line:Show()
end

local function Redraw()
    usedLines = 0
    for _, points in ipairs(strokes[shownFloor] or {}) do
        for i = 3, #points - 1, 2 do Line(points[i - 2], points[i - 1], points[i], points[i + 1]) end
    end
    if action and not action.pan then   -- trait en cours, pas encore enregistré
        for i = 3, #action - 1, 2 do Line(action[i - 2], action[i - 1], action[i], action[i + 1]) end
    end
    for i = usedLines + 1, #lines do lines[i]:Hide() end
end

local function AddStroke(floor, points)
    local list = strokes[floor] or {}
    strokes[floor] = list
    list[#list + 1] = points
    if #list > MAX_STROKES then table.remove(list, 1) end
    if floor == shownFloor then Redraw() end
end

local function Clear(floor)
    strokes[floor] = nil
    if floor == shownFloor then Redraw() end
end

--------------------------------------------------------------------------------
-- Partage
--------------------------------------------------------------------------------

local function Flush()
    sending = false
    local channel = NS.GroupChannel()
    if not channel then
        wipe(queue)   -- hors groupe : dessin local seulement
        return
    end
    while queue[1] do
        local entry = queue[1]
        while entry.sent < #entry do
            local result = C_ChatInfo.SendAddonMessage(PREFIX, entry[entry.sent + 1], channel)
            if RETRY[result] then
                sending = true
                C_Timer.After(RETRY_DELAY, Flush)   -- reprise au message refusé
                return
            elseif result ~= 0 then
                wipe(queue)   -- refus : la suite le serait aussi
                if result ~= (R.NotInGroup or 5) then NS.Print(PREFIX .. ": SendAddonMessage " .. tostring(result)) end
                return
            end
            entry.sent = entry.sent + 1
        end
        table.remove(queue, 1)
    end
end

--- Messages d'un même trait envoyés ensemble ; file pleine (envoi bloqué longtemps) : le plus ancien jeté.
local function Broadcast(messages)
    messages.sent = 0
    queue[#queue + 1] = messages
    if #queue > MAX_QUEUE then   -- le plus ancien trait, jamais celui en cours d'envoi ni un effacement
        for i = sending and 2 or 1, #queue do
            if queue[i][1]:sub(1, 1) == "S" then
                table.remove(queue, i)
                break
            end
        end
    end
    if not sending then Flush() end
end

--- Un message par tranche de points ; chaque tranche reprend le dernier point de la précédente.
local function SendStroke(floor, points)
    local first, messages = 1, {}
    repeat
        local last = math.min(#points, first + POINTS_PER_MESSAGE * 2 - 1)
        local parts = {}
        for i = first, last, 2 do
            parts[#parts + 1] = ("%03d%03d"):format(math.floor(points[i] * 999 + 0.5), math.floor(points[i + 1] * 999 + 0.5))
        end
        messages[#messages + 1] = "S" .. floor .. ":" .. table.concat(parts)
        first = last - 1
    until last >= #points
    Broadcast(messages)
end

local function Receive(message, channel, sender)
    if not NS.GroupSender(message, channel, sender) then return end
    local floor, digits = message:match("^S(%d+):(%d+)$")
    if floor and NS.Floors[tonumber(floor)] and #digits % 6 == 0 and #digits >= 12 then
        local points = {}
        for x, y in digits:gmatch("(%d%d%d)(%d%d%d)") do
            points[#points + 1], points[#points + 2] = tonumber(x) / 999, tonumber(y) / 999
        end
        AddStroke(tonumber(floor), points)
        return
    end
    floor = message:match("^C(%d+)$")
    if floor then Clear(tonumber(floor)) end
end

--------------------------------------------------------------------------------
-- Souris
--------------------------------------------------------------------------------

local function Stop()
    viewport:SetScript("OnUpdate", nil)
    local points = action
    action = nil
    if points and not points.pan and #points >= 4 then
        AddStroke(shownFloor, points)
        SendStroke(shownFloor, points)
    end
end

--- Bouton relâché, même hors de la carte : fin du geste.
local function Update()
    if not IsMouseButtonDown("LeftButton") then return Stop() end
    local x, y = CursorInView()
    if action.pan then
        offsetX, offsetY = action.offsetX + x - action.x, action.offsetY - (y - action.y)
        Apply()
        return
    end
    x, y = CursorOnCanvas()
    local n = #action
    if n >= MAX_POINTS * 2 then
        -- Trait plein : envoyé, la suite repart du dernier point.
        local lastX, lastY = action[n - 1], action[n]
        Stop()
        action = { lastX, lastY }
        viewport:SetScript("OnUpdate", Update)
        return
    end
    if math.abs(x - action[n - 1]) + math.abs(y - action[n]) < MIN_STEP then return end
    Line(action[n - 1], action[n], x, y)
    action[n + 1], action[n + 2] = x, y
end

local function Start(_, button)
    if button ~= "LeftButton" then return end
    if drawing and shownFloor then
        action = { CursorOnCanvas() }
    else
        local x, y = CursorInView()
        action = { pan = true, x = x, y = y, offsetX = offsetX, offsetY = offsetY }
    end
    viewport:SetScript("OnUpdate", Update)
end

--------------------------------------------------------------------------------
-- Branchement par Journal.lua
--------------------------------------------------------------------------------

--- viewport coupe ses enfants ; canvas, de la taille de viewport, porte les tuiles, les repères et les traits.
function NS.AttachMapCanvas(view, map, drawButton, clearButton)
    viewport, canvas = view, map
    width, height = canvas:GetWidth(), canvas:GetHeight()
    viewport:EnableMouse(true)
    viewport:EnableMouseWheel(true)
    viewport:SetScript("OnMouseWheel", function(_, delta) Zoom(delta) end)
    viewport:SetScript("OnMouseDown", Start)
    viewport:SetScript("OnHide", function() if action then Stop() end end)
    drawButton:SetScript("OnClick", function(self)
        drawing = not drawing
        if drawing then self:LockHighlight() else self:UnlockHighlight() end
    end)
    clearButton:SetScript("OnClick", function()
        if not shownFloor then return end
        Clear(shownFloor)
        Broadcast({ "C" .. shownFloor })
    end)
end

--- Appelé à chaque affichage de la carte. Nouvel étage : zoom remis à 1, geste en cours abandonné.
function NS.ShowMapFloor(floor)
    if floor ~= shownFloor then
        shownFloor, zoom, offsetX, offsetY, action = floor, 1, 0, 0, nil
        viewport:SetScript("OnUpdate", nil)
        Apply()
    end
    Redraw()
end

local registered = C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
if registered ~= 0 and registered ~= 1 then NS.Print(PREFIX .. ": RegisterAddonMessagePrefix " .. tostring(registered)) end
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
    if prefix == PREFIX then Receive(message, channel, sender) end
end)
