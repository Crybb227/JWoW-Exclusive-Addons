JasonWoWAdditions = JasonWoWAdditions or {}
local JWA = JasonWoWAdditions
JWA.UI = JWA.UI or {}
local UI = JWA.UI

local MIN_SCALE = 0.7
local MAX_SCALE = 1.3
local SCALE_STEP = 0.05

local function CreateCheckbox(parent, label, tooltip, name)
    local checkbox = CreateFrame("CheckButton", name or "JasonWoWAdditionsOptionsShowOnStartup",
        parent, "InterfaceOptionsCheckButtonTemplate")
    getglobal(checkbox:GetName() .. "Text"):SetText(label)
    checkbox.tooltipText = label
    checkbox.tooltipRequirement = tooltip
    return checkbox
end

function UI:CreateOptionsPanel()
    local panel = CreateFrame("Frame", "JasonWoWAdditionsOptionsPanel", UIParent)
    panel.name = "JasonWoWAdditions"
    panel:Hide()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText("JasonWoWAdditions")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetWidth(500)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Campaign progression and Nemesis tracking. Use /prog to open the window.")
    UI.SetColor(subtitle, UI.COLOR_GREY)

    local showOnStartup = CreateCheckbox(panel, "Show on Startup",
        "Automatically open the JasonWoWAdditions window when you log in or reload the UI.")
    showOnStartup:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -20)
    showOnStartup:SetScript("OnClick", function(button)
        JWA.db.showOnStartup = button:GetChecked() and true or false
    end)
    self.optionsShowOnStartup = showOnStartup

    local scaleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", showOnStartup, "BOTTOMLEFT", 2, -24)
    scaleLabel:SetText("Window Scale")

    local scaleSlider = CreateFrame("Slider", "JasonWoWAdditionsOptionsScaleSlider", panel, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 4, -20)
    scaleSlider:SetWidth(260)
    scaleSlider:SetMinMaxValues(MIN_SCALE, MAX_SCALE)
    scaleSlider:SetValueStep(SCALE_STEP)
    if scaleSlider.SetObeyStepOnDrag then
        scaleSlider:SetObeyStepOnDrag(true)
    end
    getglobal(scaleSlider:GetName() .. "Low"):SetText(tostring(MIN_SCALE))
    getglobal(scaleSlider:GetName() .. "High"):SetText(tostring(MAX_SCALE))
    getglobal(scaleSlider:GetName() .. "Text"):SetText("Window Scale")

    local scaleValueText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    scaleValueText:SetPoint("LEFT", scaleSlider, "RIGHT", 12, 0)
    self.optionsScaleValueText = scaleValueText

    scaleSlider:SetScript("OnValueChanged", function(_, value)
        value = math.floor((value / SCALE_STEP) + 0.5) * SCALE_STEP
        JWA.db.uiScale = value
        scaleValueText:SetText(string.format("%.2fx", value))
        if self.frame then
            self.frame:SetScale(value)
        end
    end)
    self.optionsScaleSlider = scaleSlider

    local tabNote = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    tabNote:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", -4, -28)
    tabNote:SetWidth(500)
    tabNote:SetJustifyH("LEFT")
    tabNote:SetText("The window always reopens on the last tab you had open (Overview, Campaign, Bots, Nemesis, " ..
        "Tracking, or Stats). Use /prog tiny or the Tiny button to collapse it to a small status bar.")
    UI.SetColor(tabNote, UI.COLOR_GREY)

    local tinyActivity = CreateCheckbox(panel, "Show takeover activity in tiny mode",
        "Include the current activity and target in the compact status bar.", "JasonWoWAdditionsOptionsTinyActivity")
    tinyActivity:SetPoint("TOPLEFT", tabNote, "BOTTOMLEFT", -2, -16)
    tinyActivity:SetScript("OnClick", function(button)
        JWA.db.tinyShowActivity = button:GetChecked() and true or false
        if JWA.db.tinyMode then UI:RefreshTinyBar() end
    end)

    panel.refresh = function()
        tinyActivity:SetChecked(JWA.db.tinyShowActivity and true or false)
        showOnStartup:SetChecked(JWA.db.showOnStartup and true or false)
        local scale = JWA.db.uiScale or 1.0
        scaleSlider:SetValue(scale)
        scaleValueText:SetText(string.format("%.2fx", scale))
    end

    panel:SetScript("OnShow", panel.refresh)

    self.optionsPanel = panel

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    return panel
end

local optionsEventFrame = CreateFrame("Frame")
optionsEventFrame:RegisterEvent("ADDON_LOADED")
optionsEventFrame:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == "JasonWoWAdditions" then
        UI:CreateOptionsPanel()
    end
end)
