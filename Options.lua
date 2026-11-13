-- Panneau de réglages (Échap > Options > AddOns) et entrée dans le compartiment d'addons de la minicarte.
local _, NS = ...
local L = NS.L

if _G.AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
    AddonCompartmentFrame:RegisterAddon({ text = L.TITLE, icon = NS.ICON, func = function() NS.Toggle() end })
end

local panel = CreateFrame("Frame")
local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(L.TITLE)

-- Chaque case montre l'inverse d'un drapeau de la base : cochée = affiché ou joué.
local OPTIONS = {
    { key = "hideTooltip", label = L.OPT_TOOLTIP },
    { key = "muteAlert", label = L.OPT_SOUND },
    { key = "hideMinimap", label = L.OPT_MINIMAP,
      apply = function(hidden) if NS.minimapButton then NS.minimapButton:SetShown(not hidden) end end },
    { key = "hideUpcoming", label = L.OPT_UPCOMING, apply = function() NS.Refresh() end },
}
local boxes = {}
for i, option in ipairs(OPTIONS) do
    local box = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    box:SetPoint("TOPLEFT", 16, -16 - i * 32)
    box.Text:SetText(option.label)
    box:SetScript("OnClick", function(self)
        NS.db[option.key] = not self:GetChecked() or nil
        if option.apply then option.apply(NS.db[option.key]) end
    end)
    boxes[i] = box
end
panel:SetScript("OnShow", function()
    for i, box in ipairs(boxes) do box:SetChecked(not NS.db[OPTIONS[i].key]) end
end)

local category = Settings.RegisterCanvasLayoutCategory(panel, L.TITLE)
Settings.RegisterAddOnCategory(category)
NS.OpenOptions = function() Settings.OpenToCategory(category:GetID()) end
