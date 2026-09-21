NemesisTracker = NemesisTracker or {}
local NT = NemesisTracker

NT.Options = NT.Options or {}
local Options = NT.Options
local controlCounter = 0

local function nextControlName(prefix)
    controlCounter = controlCounter + 1
    return "NemesisTracker" .. prefix .. controlCounter
end

local function applyDefaults()
    if not NT.db then
        return
    end

    if NT.db.safeAuraMatchingMigrated == nil then
        NT.db.unitTooltipNameFallback = false
        NT.db.nameplateNameFallback = false
        NT.db.safeAuraMatchingMigrated = true
    end
    if NT.db.nameplateAffixes == nil then NT.db.nameplateAffixes = true end
    if NT.db.nameplateTooltips == nil then NT.db.nameplateTooltips = true end
    if NT.db.unitTooltips == nil then NT.db.unitTooltips = true end
    if NT.db.liveAuraMatching == nil then NT.db.liveAuraMatching = true end
    if NT.db.unitTooltipNameFallback == nil then NT.db.unitTooltipNameFallback = false end
    if NT.db.nameplateUniqueNameFallback == nil then NT.db.nameplateUniqueNameFallback = false end
    if NT.db.nameplateNameFallback == nil then NT.db.nameplateNameFallback = false end
    if NT.db.preferCurrentZoneMap == nil then NT.db.preferCurrentZoneMap = true end
    if NT.db.nameplateIconSize == nil then NT.db.nameplateIconSize = 18 end
    if NT.db.debug == nil then NT.db.debug = false end
    if NT.db.unitQueryThrottleSeconds == nil then NT.db.unitQueryThrottleSeconds = 1 end
    if NT.db.unitSnapshotTtlSeconds == nil then NT.db.unitSnapshotTtlSeconds = 15 end
end

local function addTitle(parent, text, x, y)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    title:SetText(text)
    return title
end

local function addText(parent, text, anchor, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y)
    label:SetWidth(520)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function addCheckbox(parent, key, label, tooltip, anchor, x, y, onChanged)
    local name = nextControlName("OptionCheck")
    local check = CreateFrame("CheckButton", name, parent, "OptionsCheckButtonTemplate")
    local text = check.Text or _G[name .. "Text"]
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y)
    if text then
        text:SetText(label)
    end
    check.tooltipText = label
    check.tooltipRequirement = tooltip
    check:SetScript("OnClick", function(self)
        applyDefaults()
        NT.db[key] = self:GetChecked() and true or false
        if onChanged then
            onChanged()
        end
    end)
    parent.controls[key] = check
    return check
end

local function addSlider(parent, key, label, minValue, maxValue, step, anchor, x, y, onChanged)
    local name = nextControlName("OptionSlider")
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    local text = slider.Text or _G[name .. "Text"]
    local low = slider.Low or _G[name .. "Low"]
    local high = slider.High or _G[name .. "High"]
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetWidth(220)
    if text then text:SetText(label) end
    if low then low:SetText(tostring(minValue)) end
    if high then high:SetText(tostring(maxValue)) end
    slider:SetScript("OnValueChanged", function(self, value)
        applyDefaults()
        value = math.floor((tonumber(value) or minValue) + 0.5)
        NT.db[key] = value
        local valueText = self.Text or _G[(self:GetName() or "") .. "Text"]
        if valueText then
            valueText:SetText(string.format("%s: %d", label, value))
        end
        if onChanged then
            onChanged()
        end
    end)
    parent.controls[key] = slider
    return slider
end

function Options:Refresh()
    applyDefaults()
    if not self.panel or not NT.db then
        return
    end

    for key, control in pairs(self.panel.controls or {}) do
        if control.GetObjectType and control:GetObjectType() == "CheckButton" then
            control:SetChecked(NT.db[key] and true or false)
        elseif control.GetObjectType and control:GetObjectType() == "Slider" then
            control:SetValue(tonumber(NT.db[key]) or 18)
        end
    end
end

function Options:NotifyDisplayChanged()
    if NT.NameplateAffixes and type(NT.NameplateAffixes.RefreshConfig) == "function" then
        NT.NameplateAffixes:RefreshConfig()
    end
end

function Options:CreatePanel()
    if self.panel or not CreateFrame or not InterfaceOptions_AddCategory then
        return
    end

    local panel = CreateFrame("Frame", "NemesisTrackerOptionsPanel", UIParent)
    panel.name = "NemesisTracker"
    panel.controls = {}
    panel:SetScript("OnShow", function()
        Options:Refresh()
    end)

    local title = addTitle(panel, "NemesisTracker", 16, -16)
    local intro = addText(panel, "Configure in-world Nemesis affix display and tooltip behavior.", title, 0, -8)

    local unitTooltips = addCheckbox(
        panel,
        "unitTooltips",
        "Show Nemesis lines on normal unit tooltips",
        "Adds rank and affix effect lines to GameTooltip when hovering a matching unit.",
        intro,
        0,
        -18
    )

    local liveAuraMatching = addCheckbox(
        panel,
        "liveAuraMatching",
        "Use live affix buffs for unit matching",
        "Uses Nemesis marker auras on target, mouseover, and focus units to identify live Nemesis mobs without name fallback.",
        unitTooltips,
        0,
        -8,
        function() Options:NotifyDisplayChanged() end
    )

    local fallback = addCheckbox(
        panel,
        "unitTooltipNameFallback",
        "Use risky name fallback for unit tooltips",
        "If live affix-buff matching fails, use the freshest current-zone cached Nemesis with the same visible name. "
            .. "This can mark normal same-name mobs.",
        liveAuraMatching,
        0,
        -8
    )

    local plates = addCheckbox(
        panel,
        "nameplateAffixes",
        "Show rank/affix badges above Blizzard nameplates",
        "Shows compact in-world icons above visible vanilla nameplates for live affix-buff or configured fallback matches.",
        fallback,
        0,
        -18,
        function() Options:NotifyDisplayChanged() end
    )

    local plateUniqueFallback = addCheckbox(
        panel,
        "nameplateUniqueNameFallback",
        "Use single visible name fallback for badges",
        "Allows nameplate badges by visible name only when just one nameplate with that name is currently visible.",
        plates,
        0,
        -8,
        function() Options:NotifyDisplayChanged() end
    )

    local plateFallback = addCheckbox(
        panel,
        "nameplateNameFallback",
        "Use risky name fallback for nameplate badges",
        "Shows badges by visible name alone when live affix-buff matching is unavailable. "
            .. "This can mark normal same-name mobs.",
        plateUniqueFallback,
        0,
        -8,
        function() Options:NotifyDisplayChanged() end
    )

    local plateTips = addCheckbox(
        panel,
        "nameplateTooltips",
        "Show tooltips on nameplate badges",
        "Lets the nameplate badge strip show the Nemesis affix tooltip when hovered.",
        plateFallback,
        0,
        -8,
        function() Options:NotifyDisplayChanged() end
    )

    addSlider(
        panel,
        "nameplateIconSize",
        "Nameplate badge size",
        14,
        26,
        1,
        plateTips,
        4,
        -28,
        function() Options:NotifyDisplayChanged() end
    )

    addCheckbox(
        panel,
        "preferCurrentZoneMap",
        "Prefer current zone on tracker map",
        "When the tracker has not chosen a map zone yet, start on the player's current zone if tracked Nemesis data exists there.",
        plateTips,
        0,
        -60
    )

    self.panel = panel
    InterfaceOptions_AddCategory(panel)
    self:Refresh()
end

function Options:Initialize()
    applyDefaults()
    self:CreatePanel()
end

function Options:InstallDatabaseWrapper()
    if self.databaseWrapped or type(NT.InitializeDatabase) ~= "function" then
        return
    end

    self.databaseWrapped = true
    local originalInitializeDatabase = NT.InitializeDatabase
    NT.InitializeDatabase = function(self, ...)
        local result = originalInitializeDatabase(self, ...)
        Options:Initialize()
        return result
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "NemesisTracker" then
        Options:Initialize()
    end
end)

Options:InstallDatabaseWrapper()
Options:Initialize()
