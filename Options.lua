local _, PF = ...

local panel = CreateFrame("Frame", "PrettyFramesOptionsPanel")
panel:Hide()
panel.name = "PrettyFrames"
PF.optionsPanel = panel

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
title:SetPoint("TOPLEFT", 20, -20)
title:SetText("PrettyFrames")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetWidth(620)
subtitle:SetJustifyH("LEFT")
subtitle:SetText("Ornate unit, party, and raid frames for World of Warcraft: Forever.")

local appearanceHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
appearanceHeader:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -28)
appearanceHeader:SetText("Appearance and layout")

local function CreateCheckButton(label, description, y, onClick)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", appearanceHeader, "BOTTOMLEFT", 0, y)
    check.Text:SetText(label)
    check:SetScript("OnClick", onClick)

    if description then
        local detail = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        detail:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 30, 2)
        detail:SetWidth(560)
        detail:SetJustifyH("LEFT")
        detail:SetText(description)
        check.description = detail
    end
    return check
end

local lockCheck = CreateCheckButton(
    "Lock frame positions",
    "Turn this off to reveal drag handles and right-click display menus.",
    -12,
    function(button)
        if panel.refreshing then return end
        if not PF:SetLocked(button:GetChecked()) then
            button:SetChecked(PF.db.locked)
        end
    end
)

local previewCheck = CreateCheckButton(
    "Show preview frames",
    "Displays sample party and raid frames while arranging the layout.",
    -72,
    function(button)
        if panel.refreshing then return end
        if InCombatLockdown() then
            button:SetChecked(PF.testMode or false)
            PF:Print("preview mode cannot change during combat.")
            return
        end
        PF:SetTestMode(button:GetChecked())
    end
)

local mirrorCheck = CreateCheckButton(
    "Mirror Player and Target frames",
    "Keeps both frames the same distance from the screen center and at the same height. Moving either frame moves the other.",
    -132,
    function(button)
        if panel.refreshing or not PF.db then return end
        if not PF:SetMirrorPlayerTarget(button:GetChecked()) then
            button:SetChecked(PF.db.mirrorPlayerTarget)
        end
    end
)

local portraits3DCheck = CreateCheckButton(
    "Enable 3D portraits",
    "Turn this off to use World of Warcraft's generated 2D portraits on every frame.",
    -192,
    function(button)
        if panel.refreshing or not PF.db then return end
        PF:Set3DPortraitsEnabled(button:GetChecked())
    end
)

StaticPopupDialogs.PRETTYFRAMES_CHANGE_THEME = {
    text = "Switch PrettyFrames to the %s theme?\n\nThe interface will reload to rebuild every frame with the new theme.",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(_, data)
        if data and PF:PrepareThemeChange(data.theme) then
            ReloadUI()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local themeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
themeLabel:SetPoint("TOPLEFT", appearanceHeader, "BOTTOMLEFT", 4, -252)
themeLabel:SetText("Theme")

local themeDropdown = CreateFrame("Frame", "PrettyFramesThemeDropdown", panel, "UIDropDownMenuTemplate")
themeDropdown:SetPoint("LEFT", themeLabel, "RIGHT", 8, -1)
UIDropDownMenu_SetWidth(themeDropdown, 180)
UIDropDownMenu_Initialize(themeDropdown, function()
    for _, themeId in ipairs(PF.themeOrder) do
        local selectedThemeId = themeId
        local theme = PF.themes[selectedThemeId]
        local info = UIDropDownMenu_CreateInfo()
        info.text = theme.name
        info.checked = PF.db and PF.db.theme == selectedThemeId
        info.func = function()
            if PF.db and PF.db.theme ~= selectedThemeId then
                StaticPopup_Show("PRETTYFRAMES_CHANGE_THEME", theme.name, nil, { theme = selectedThemeId })
            end
        end
        UIDropDownMenu_AddButton(info)
    end
end)

local scaleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
scaleLabel:SetPoint("TOPLEFT", appearanceHeader, "BOTTOMLEFT", 4, -312)
scaleLabel:SetText("Global frame scale")

local scaleValue = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
scaleValue:SetPoint("LEFT", scaleLabel, "RIGHT", 10, 0)
PF:ApplyBoldNumberFont(scaleValue)

local scaleSlider = CreateFrame("Slider", "PrettyFramesOptionsScaleSlider", panel, "OptionsSliderTemplate")
scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 5, -16)
scaleSlider:SetWidth(330)
scaleSlider:SetMinMaxValues(PF.MIN_SCALE, PF.MAX_SCALE)
scaleSlider:SetValueStep(0.05)
scaleSlider:SetObeyStepOnDrag(true)
_G[scaleSlider:GetName() .. "Low"]:SetFormattedText("%d%%", PF.MIN_SCALE * 100)
_G[scaleSlider:GetName() .. "High"]:SetFormattedText("%d%%", PF.MAX_SCALE * 100)
_G[scaleSlider:GetName() .. "Text"]:SetText("")
PF:ApplyBoldNumberFont(_G[scaleSlider:GetName() .. "Low"])
PF:ApplyBoldNumberFont(_G[scaleSlider:GetName() .. "High"])
scaleSlider:SetScript("OnValueChanged", function(_, value)
    value = math.floor(value * 20 + 0.5) / 20
    scaleValue:SetFormattedText("%d%%", value * 100)
    if panel.refreshing or not PF.db then return end
    PF.db.scale = value
    PF:RefreshScale()
end)

StaticPopupDialogs.PRETTYFRAMES_RESET_SETTINGS = {
    text = "Reset all PrettyFrames profiles, character assignments, settings, and frame positions?",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function()
        PrettyFramesDB = nil
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetButton:SetSize(150, 26)
resetButton:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", -5, -42)
resetButton:SetText("Reset All Settings")
resetButton:SetScript("OnClick", function()
    StaticPopup_Show("PRETTYFRAMES_RESET_SETTINGS")
end)

local commandHelp = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
commandHelp:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -24)
commandHelp:SetWidth(620)
commandHelp:SetJustifyH("LEFT")
commandHelp:SetText("You can also open this panel with /pf or /pf options. Existing slash commands remain available.")

function panel:Refresh()
    if not PF.db then return end
    self.refreshing = true
    lockCheck:SetChecked(PF.db.locked)
    previewCheck:SetChecked(PF.testMode or false)
    mirrorCheck:SetChecked(PF.db.mirrorPlayerTarget)
    portraits3DCheck:SetChecked(PF.db.enable3DPortraits)
    local theme = PF:GetTheme(PF.db.theme)
    UIDropDownMenu_SetText(themeDropdown, theme and theme.name or PF.db.theme)
    scaleSlider:SetValue(PF.db.scale)
    self.refreshing = false
end

panel:SetScript("OnShow", function(self)
    self:Refresh()
end)

panel.OnCommit = function() end
panel.OnDefault = function() StaticPopup_Show("PRETTYFRAMES_RESET_SETTINGS") end
panel.OnRefresh = function() panel:Refresh() end

local featuresPanel = CreateFrame("Frame", "PrettyFramesFeaturesPanel")
featuresPanel:Hide()
featuresPanel.name = "Features"
featuresPanel.parent = "PrettyFrames"
PF.featuresPanel = featuresPanel

local featuresTitle = featuresPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
featuresTitle:SetPoint("TOPLEFT", 20, -20)
featuresTitle:SetText("PrettyFrames: Features")

local featuresSubtitle = featuresPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
featuresSubtitle:SetPoint("TOPLEFT", featuresTitle, "BOTTOMLEFT", 0, -8)
featuresSubtitle:SetWidth(620)
featuresSubtitle:SetJustifyH("LEFT")
featuresSubtitle:SetText("Choose which Blizzard interface systems PrettyFrames replaces.")

local featuresHeader = featuresPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
featuresHeader:SetPoint("TOPLEFT", featuresSubtitle, "BOTTOMLEFT", 0, -28)
featuresHeader:SetText("Frame replacements")

local featureChecks = {}
local featureRows = {
    {
        key = "replaceUnitFrames",
        label = "Replace Blizzard Unit Frames",
        description = "Use PrettyFrames for Player, Pet, Target, Target of Target, and Focus frames.",
    },
    {
        key = "replacePartyFrames",
        label = "Replace Blizzard Party Frames",
        description = "Use the connected PrettyFrames party layout in place of Blizzard party frames.",
    },
    {
        key = "replaceBossFrames",
        label = "Replace Blizzard Boss Frames",
        description = "Use the compact PrettyFrames boss group in place of Blizzard boss frames.",
    },
    {
        key = "replaceRaidFrames",
        label = "Replace Blizzard Raid Frames",
        description = "Use PrettyFrames raid groups in place of Blizzard compact raid frames.",
    },
    {
        key = "replaceNameplates",
        label = "Replace Blizzard Nameplates",
        description = "Use the compact PrettyFrames artwork for world nameplates.",
    },
}

local featuresReloadNotice = featuresPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
featuresReloadNotice:SetText("|cffffb347A UI reload is required to apply feature changes.|r")
featuresReloadNotice:Hide()

for index, row in ipairs(featureRows) do
    local featureKey = row.key
    local check = CreateFrame("CheckButton", nil, featuresPanel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", featuresHeader, "BOTTOMLEFT", 0, -12 - (index - 1) * 62)
    check.Text:SetText(row.label)
    check:SetScript("OnClick", function(button)
        if featuresPanel.refreshing or not PF.db then return end
        PF.db[featureKey] = button:GetChecked()
        featuresPanel.reloadRequired = true
        featuresReloadNotice:Show()
    end)

    local detail = featuresPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    detail:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 30, 2)
    detail:SetWidth(560)
    detail:SetJustifyH("LEFT")
    detail:SetText(row.description)
    check.description = detail
    featureChecks[featureKey] = check
end

featuresReloadNotice:SetPoint("TOPLEFT", featuresHeader, "BOTTOMLEFT", 0, -328)

local featuresReloadButton = CreateFrame("Button", nil, featuresPanel, "UIPanelButtonTemplate")
featuresReloadButton:SetSize(130, 26)
featuresReloadButton:SetPoint("TOPLEFT", featuresReloadNotice, "BOTTOMLEFT", 0, -14)
featuresReloadButton:SetText("Reload UI")
featuresReloadButton:SetScript("OnClick", function() ReloadUI() end)

function featuresPanel:Refresh()
    if not PF.db then return end
    self.refreshing = true
    for key, check in pairs(featureChecks) do
        check:SetChecked(PF.db[key] ~= false)
    end
    featuresReloadNotice:SetShown(self.reloadRequired == true)
    self.refreshing = false
end

featuresPanel:SetScript("OnShow", function(self)
    self:Refresh()
end)
featuresPanel.OnCommit = function() end
featuresPanel.OnDefault = function() StaticPopup_Show("PRETTYFRAMES_RESET_SETTINGS") end
featuresPanel.OnRefresh = function() featuresPanel:Refresh() end

local healthPanel = CreateFrame("Frame", "PrettyFramesHealthPanel")
healthPanel:Hide()
healthPanel.name = "Health"
healthPanel.parent = "PrettyFrames"
PF.healthPanel = healthPanel

local healthTitle = healthPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
healthTitle:SetPoint("TOPLEFT", 20, -20)
healthTitle:SetText("PrettyFrames: Health")

local healthSubtitle = healthPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
healthSubtitle:SetPoint("TOPLEFT", healthTitle, "BOTTOMLEFT", 0, -8)
healthSubtitle:SetWidth(620)
healthSubtitle:SetJustifyH("LEFT")
healthSubtitle:SetText(
    "Configure nameplate health here. Unlock frames and right-click them to configure Player, Pet, Target, Focus, Party, Raid, and Boss health bars."
)

local nameplateHealthHeader = healthPanel:CreateFontString(
    nil, "ARTWORK", "GameFontNormalLarge"
)
nameplateHealthHeader:SetPoint("TOPLEFT", healthSubtitle, "BOTTOMLEFT", 0, -28)
nameplateHealthHeader:SetText("Nameplates")

local function ChoiceLabel(choices, value)
    for _, choice in ipairs(choices) do
        if choice.id == value then return choice.label end
    end
    return tostring(value)
end

local function CreateHealthDropdown(name, label, y, choices, getValue, setValue)
    local text = healthPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("TOPLEFT", nameplateHealthHeader, "BOTTOMLEFT", 4, y)
    text:SetText(label)

    local dropdown = CreateFrame(
        "Frame", name, healthPanel, "UIDropDownMenuTemplate"
    )
    dropdown:SetPoint("TOPLEFT", text, "BOTTOMLEFT", -16, -6)
    UIDropDownMenu_SetWidth(dropdown, 220)
    UIDropDownMenu_Initialize(dropdown, function()
        for _, choice in ipairs(choices) do
            local selected = choice
            local info = UIDropDownMenu_CreateInfo()
            info.text = selected.label
            info.checked = getValue() == selected.id
            info.func = function()
                setValue(selected.id)
                UIDropDownMenu_SetText(dropdown, selected.label)
                if PF.RefreshNameplateHealth then PF:RefreshNameplateHealth() end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    dropdown.RefreshValue = function()
        UIDropDownMenu_SetText(dropdown, ChoiceLabel(choices, getValue()))
    end
    return dropdown
end

local function NameplateHealthSetting()
    if PF.db then return PF:GetFrameSetting("nameplate") end
    -- UIDropDownMenu may invoke its initializer while Lua files are loading,
    -- before ADDON_LOADED has created the active profile. Supplying display
    -- defaults here keeps the rest of Options.lua (including slash commands)
    -- available during that brief initialization window.
    return {
        healthTextMode = "currentmax",
        healthColorMode = "unit",
        healthBackgroundAlpha = 1,
    }
end

local nameplateTextDropdown = CreateHealthDropdown(
    "PrettyFramesNameplateHealthTextDropdown", "Health text", -16,
    PF.HealthTextBehavior.textModes,
    function() return NameplateHealthSetting().healthTextMode end,
    function(value) NameplateHealthSetting().healthTextMode = value end
)

local nameplateColorDropdown = CreateHealthDropdown(
    "PrettyFramesNameplateHealthColorDropdown", "Bar color", -100,
    PF.HealthTextBehavior.colorModes,
    function() return NameplateHealthSetting().healthColorMode end,
    function(value) NameplateHealthSetting().healthColorMode = value end
)

local nameplateBackgroundDropdown = CreateHealthDropdown(
    "PrettyFramesNameplateHealthBackgroundDropdown", "Background opacity", -184,
    PF.HealthTextBehavior.backgroundAlphas,
    function() return NameplateHealthSetting().healthBackgroundAlpha end,
    function(value) NameplateHealthSetting().healthBackgroundAlpha = value end
)

function healthPanel:Refresh()
    if not PF.db then return end
    nameplateTextDropdown.RefreshValue()
    nameplateColorDropdown.RefreshValue()
    nameplateBackgroundDropdown.RefreshValue()
end

healthPanel:SetScript("OnShow", function(self) self:Refresh() end)
healthPanel.OnCommit = function() end
healthPanel.OnDefault = function() StaticPopup_Show("PRETTYFRAMES_RESET_SETTINGS") end
healthPanel.OnRefresh = function() healthPanel:Refresh() end

-- Register the established pages before constructing optional subpages. This
-- keeps PrettyFrames available in Options even if a client-specific widget on
-- a later page is unavailable.
if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, "PrettyFrames")
    Settings.RegisterAddOnCategory(category)
    PF.optionsCategory = category
    PF.featuresCategory = Settings.RegisterCanvasLayoutSubcategory(category, featuresPanel, "Features")
    PF.healthCategory = Settings.RegisterCanvasLayoutSubcategory(category, healthPanel, "Health")
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
    InterfaceOptions_AddCategory(featuresPanel)
    InterfaceOptions_AddCategory(healthPanel)
end

local profilesPanel = CreateFrame("Frame", "PrettyFramesProfilesPanel")
profilesPanel:Hide()
profilesPanel.name = "Profiles"
profilesPanel.parent = "PrettyFrames"
PF.profilesPanel = profilesPanel

local profilesTitle = profilesPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
profilesTitle:SetPoint("TOPLEFT", 20, -20)
profilesTitle:SetText("PrettyFrames: Profiles")

local profilesSubtitle = profilesPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
profilesSubtitle:SetPoint("TOPLEFT", profilesTitle, "BOTTOMLEFT", 0, -8)
profilesSubtitle:SetWidth(620)
profilesSubtitle:SetJustifyH("LEFT")
profilesSubtitle:SetText("Save complete PrettyFrames configurations and choose one for each character.")

local currentProfileLabel = profilesPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
currentProfileLabel:SetPoint("TOPLEFT", profilesSubtitle, "BOTTOMLEFT", 0, -28)
currentProfileLabel:SetText("Current profile")

local currentProfileDropdown = CreateFrame(
    "Frame", "PrettyFramesCurrentProfileDropdown", profilesPanel, "UIDropDownMenuTemplate"
)
currentProfileDropdown:SetPoint("TOPLEFT", currentProfileLabel, "BOTTOMLEFT", -16, -8)
UIDropDownMenu_SetWidth(currentProfileDropdown, 220)
UIDropDownMenu_Initialize(currentProfileDropdown, function()
    for _, name in ipairs(PF:GetProfileNames()) do
        local profileName = name
        local info = UIDropDownMenu_CreateInfo()
        info.text = profileName
        info.checked = profileName == PF:GetCurrentProfileName()
        info.func = function()
            if profileName ~= PF:GetCurrentProfileName() and PF:SetProfile(profileName) then
                ReloadUI()
            end
        end
        UIDropDownMenu_AddButton(info)
    end
end)

local characterProfileText = profilesPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
characterProfileText:SetPoint("TOPLEFT", currentProfileDropdown, "BOTTOMLEFT", 20, 3)
characterProfileText:SetWidth(560)
characterProfileText:SetJustifyH("LEFT")

local newProfileButton = CreateFrame("Button", nil, profilesPanel, "UIPanelButtonTemplate")
newProfileButton:SetSize(120, 26)
newProfileButton:SetPoint("TOPLEFT", characterProfileText, "BOTTOMLEFT", 0, -18)
newProfileButton:SetText("New Profile")

local renameProfileButton = CreateFrame("Button", nil, profilesPanel, "UIPanelButtonTemplate")
renameProfileButton:SetSize(120, 26)
renameProfileButton:SetPoint("LEFT", newProfileButton, "RIGHT", 10, 0)
renameProfileButton:SetText("Rename")

local copyHeader = profilesPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
copyHeader:SetPoint("TOPLEFT", newProfileButton, "BOTTOMLEFT", 0, -30)
copyHeader:SetText("Copy from another profile")

local copyProfileDropdown = CreateFrame(
    "Frame", "PrettyFramesCopyProfileDropdown", profilesPanel, "UIDropDownMenuTemplate"
)
copyProfileDropdown:SetPoint("TOPLEFT", copyHeader, "BOTTOMLEFT", -16, -8)
UIDropDownMenu_SetWidth(copyProfileDropdown, 220)
UIDropDownMenu_Initialize(copyProfileDropdown, function()
    for _, name in ipairs(PF:GetProfileNames()) do
        if name ~= PF:GetCurrentProfileName() then
            local profileName = name
            local info = UIDropDownMenu_CreateInfo()
            info.text = profileName
            info.checked = profileName == profilesPanel.copySource
            info.func = function()
                profilesPanel.copySource = profileName
                UIDropDownMenu_SetText(copyProfileDropdown, profileName)
            end
            UIDropDownMenu_AddButton(info)
        end
    end
end)

local copyProfileButton = CreateFrame("Button", nil, profilesPanel, "UIPanelButtonTemplate")
copyProfileButton:SetSize(120, 26)
copyProfileButton:SetPoint("LEFT", copyProfileDropdown, "RIGHT", -4, 2)
copyProfileButton:SetText("Copy Settings")

local maintenanceHeader = profilesPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
maintenanceHeader:SetPoint("TOPLEFT", copyProfileDropdown, "BOTTOMLEFT", 20, -28)
maintenanceHeader:SetText("Profile maintenance")

local resetProfileButton = CreateFrame("Button", nil, profilesPanel, "UIPanelButtonTemplate")
resetProfileButton:SetSize(160, 26)
resetProfileButton:SetPoint("TOPLEFT", maintenanceHeader, "BOTTOMLEFT", 0, -14)
resetProfileButton:SetText("Reset Current Profile")

local deleteProfileDropdown = CreateFrame(
    "Frame", "PrettyFramesDeleteProfileDropdown", profilesPanel, "UIDropDownMenuTemplate"
)
deleteProfileDropdown:SetPoint("TOPLEFT", resetProfileButton, "BOTTOMLEFT", -16, -24)
UIDropDownMenu_SetWidth(deleteProfileDropdown, 220)
UIDropDownMenu_Initialize(deleteProfileDropdown, function()
    for _, name in ipairs(PF:GetProfileNames()) do
        if name ~= "Default" and name ~= PF:GetCurrentProfileName() then
            local profileName = name
            local info = UIDropDownMenu_CreateInfo()
            info.text = profileName
            info.checked = profileName == profilesPanel.deleteTarget
            info.func = function()
                profilesPanel.deleteTarget = profileName
                UIDropDownMenu_SetText(deleteProfileDropdown, profileName)
            end
            UIDropDownMenu_AddButton(info)
        end
    end
end)

local deleteProfileButton = CreateFrame("Button", nil, profilesPanel, "UIPanelButtonTemplate")
deleteProfileButton:SetSize(120, 26)
deleteProfileButton:SetPoint("LEFT", deleteProfileDropdown, "RIGHT", -4, 2)
deleteProfileButton:SetText("Delete Profile")

local reloadNotice = profilesPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
reloadNotice:SetPoint("TOPLEFT", deleteProfileDropdown, "BOTTOMLEFT", 20, -20)
reloadNotice:SetWidth(560)
reloadNotice:SetJustifyH("LEFT")
reloadNotice:SetText("Switching, copying, renaming, or resetting reloads the UI so every frame and protected setting uses the selected profile.")

local function EditBoxEnterPressed(editBox)
    editBox:GetParent().button1:Click()
end

local function GetProfileDialogEditBox(dialog)
    return dialog
        and ((dialog.GetEditBox and dialog:GetEditBox()) or dialog.EditBox or dialog.editBox)
end

local function PromptProfileName(dialogKey, initialText)
    local dialog = StaticPopup_Show(dialogKey)
    local editBox = GetProfileDialogEditBox(dialog)
    if editBox then
        editBox:SetText(initialText or "")
        editBox:HighlightText()
        editBox:SetFocus()
    end
end

StaticPopupDialogs.PRETTYFRAMES_PROFILE_NEW = {
    text = "Enter a name for the new profile:",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    OnAccept = function(dialog)
        local editBox = GetProfileDialogEditBox(dialog)
        local name = editBox and editBox:GetText() or ""
        if PF:CreateProfile(name) then
            ReloadUI()
        else
            PF:Print("profile names must be unique, non-empty, and no longer than 64 characters.")
        end
    end,
    EditBoxOnEnterPressed = EditBoxEnterPressed,
    EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
    timeout = 0,
    maxLetters = 64,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs.PRETTYFRAMES_PROFILE_RENAME = {
    text = "Rename the current profile:",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    OnAccept = function(dialog)
        local editBox = GetProfileDialogEditBox(dialog)
        local name = editBox and editBox:GetText() or ""
        if PF:RenameProfile(name) then
            ReloadUI()
        else
            PF:Print("the Default profile cannot be renamed; other names must be unique and non-empty.")
        end
    end,
    EditBoxOnEnterPressed = EditBoxEnterPressed,
    EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
    timeout = 0,
    maxLetters = 64,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs.PRETTYFRAMES_PROFILE_COPY = {
    text = "Replace every setting in %s with a copy of %s?",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(_, data)
        if data and PF:CopyProfile(data.source) then ReloadUI() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs.PRETTYFRAMES_PROFILE_RESET = {
    text = "Reset every setting in the current profile, %s, to defaults?",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function()
        PF:ResetProfile()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs.PRETTYFRAMES_PROFILE_DELETE = {
    text = "Permanently delete the %s profile? Characters assigned to it will use Default.",
    button1 = DELETE,
    button2 = CANCEL,
    OnAccept = function(_, data)
        if data and PF:DeleteProfile(data.name) then profilesPanel:Refresh() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

newProfileButton:SetScript("OnClick", function()
    PromptProfileName("PRETTYFRAMES_PROFILE_NEW", "")
end)
renameProfileButton:SetScript("OnClick", function()
    PromptProfileName("PRETTYFRAMES_PROFILE_RENAME", PF:GetCurrentProfileName())
end)
copyProfileButton:SetScript("OnClick", function()
    local source = profilesPanel.copySource
    if source then
        StaticPopup_Show(
            "PRETTYFRAMES_PROFILE_COPY", PF:GetCurrentProfileName(), source, { source = source }
        )
    end
end)
resetProfileButton:SetScript("OnClick", function()
    StaticPopup_Show("PRETTYFRAMES_PROFILE_RESET", PF:GetCurrentProfileName())
end)
deleteProfileButton:SetScript("OnClick", function()
    local name = profilesPanel.deleteTarget
    if name then StaticPopup_Show("PRETTYFRAMES_PROFILE_DELETE", name, nil, { name = name }) end
end)

function profilesPanel:Refresh()
    if not PF.database then return end
    local currentName = PF:GetCurrentProfileName()
    UIDropDownMenu_SetText(currentProfileDropdown, currentName)
    characterProfileText:SetText("Assigned to " .. PF:GetCharacterProfileKey())
    renameProfileButton:SetEnabled(currentName ~= "Default")

    if not self.copySource or not PF.database.profiles[self.copySource]
        or self.copySource == currentName then
        self.copySource = nil
        for _, name in ipairs(PF:GetProfileNames()) do
            if name ~= currentName then self.copySource = name break end
        end
    end
    UIDropDownMenu_SetText(copyProfileDropdown, self.copySource or "No other profiles")
    copyProfileButton:SetEnabled(self.copySource ~= nil)

    if not self.deleteTarget or not PF.database.profiles[self.deleteTarget]
        or self.deleteTarget == "Default" or self.deleteTarget == currentName then
        self.deleteTarget = nil
        for _, name in ipairs(PF:GetProfileNames()) do
            if name ~= "Default" and name ~= currentName then self.deleteTarget = name break end
        end
    end
    UIDropDownMenu_SetText(deleteProfileDropdown, self.deleteTarget or "No deletable profiles")
    deleteProfileButton:SetEnabled(self.deleteTarget ~= nil)
end

profilesPanel:SetScript("OnShow", function(self) self:Refresh() end)
profilesPanel.OnCommit = function() end
profilesPanel.OnDefault = function()
    StaticPopup_Show("PRETTYFRAMES_PROFILE_RESET", PF:GetCurrentProfileName())
end
profilesPanel.OnRefresh = function() profilesPanel:Refresh() end

if Settings and PF.optionsCategory then
    PF.profilesCategory = Settings.RegisterCanvasLayoutSubcategory(
        PF.optionsCategory, profilesPanel, "Profiles"
    )
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(profilesPanel)
end

function PF:OpenOptions()
    if Settings and self.optionsCategory then
        Settings.OpenToCategory(self.optionsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    else
        self:Print("open Game Menu > Options > AddOns > PrettyFrames.")
    end
end

SLASH_PRETTYFRAMES1 = "/prettyframes"
SLASH_PRETTYFRAMES2 = "/pf"

local function ShowHelp()
    PF:Print("commands:")
    PF:Print("/pf options — open the PrettyFrames options panel")
    PF:Print("/pf lock or /pf edit — toggle locked/editable frame groups")
    PF:Print("/pf testedit or /pf edittest — toggle edit and test modes together")
    PF:Print(("/pf scale %.1f-%.1f — resize all PrettyFrames"):format(PF.MIN_SCALE, PF.MAX_SCALE))
    PF:Print("/pf test — toggle preview frames")
    PF:Print("/pf test resource [name|next|auto] — preview class resources")
    PF:Print("/pf test action <frame> <modifier> <button> — simulate a binding lookup")
    PF:Print("/pf blizzard on|off — show or replace all Blizzard frames (reloads UI)")
    PF:Print("/pf reset — restore default positions and scale")
end

local function ToggleEditTestModes()
    if InCombatLockdown() then
        PF:Print("edit/test mode cannot change during combat.")
        return
    end

    -- Only the fully-off state toggles on. A mismatched state deliberately
    -- converges to fully off so one command always restores synchronization.
    local enable = PF.db.locked == true and PF.testMode ~= true
    if enable then
        PF:SetLocked(false, true)
        PF:SetTestMode(true, true)
    else
        PF:SetTestMode(false, true)
        PF:SetLocked(true, true)
    end
    PF:Print(enable and "edit and test modes enabled."
        or "edit and test modes disabled.")
end

local function PrintRangeProbe()
    if InCombatLockdown() then
        PF:Print("run /pf range outside combat.")
        return
    end
    if not UnitExists("target") then
        PF:Print("target a unit, then run /pf range.")
        return
    end

    local function Value(value)
        if issecretvalue and issecretvalue(value) then return "secret" end
        if value == nil then return "nil" end
        return tostring(value)
    end
    local function SafeCall(callback)
        local ok, first, second = pcall(callback)
        if not ok then return "error", "nil" end
        return Value(first), Value(second)
    end

    local isPlayer = SafeCall(function() return UnitIsUnit("target", "player") end)
    local isPet = SafeCall(function() return UnitIsUnit("target", "pet") end)
    local canAttack = SafeCall(function() return UnitCanAttack("player", "target") end)
    local inRange, checkedRange = SafeCall(function() return UnitInRange("target") end)
    local distanceSquared, checkedDistance = SafeCall(function()
        return UnitDistanceSquared("target")
    end)
    local interactRange = SafeCall(function()
        return UnitIsInInteractRange and UnitIsInInteractRange("target")
    end)
    local minimumRange, maximumRange = SafeCall(function()
        return PF:GetUnitRangeBand("target")
    end)
    local meleeInteract, rangedInteract = "unavailable", "unavailable"
    if CheckInteractDistance then
        meleeInteract = SafeCall(function() return CheckInteractDistance("target", 3) end)
        rangedInteract = SafeCall(function() return CheckInteractDistance("target", 4) end)
    end
    local setting = PF:GetFrameSetting("target")
    local resolved = SafeCall(function()
        return PF:GetUnitRangeState("target", setting.rangeDistance)
    end)

    PF:Print(("range mode=%s result=%s player=%s pet=%s attack=%s")
        :format(setting.rangeDistance, resolved, isPlayer, isPet, canAttack))
    PF:Print(("native in=%s checked=%s distance2=%s distanceChecked=%s interact=%s")
        :format(inRange, checkedRange, distanceSquared, checkedDistance, interactRange))
    PF:Print(("library band=%s-%s interact melee=%s ranged=%s")
        :format(minimumRange, maximumRange, meleeInteract, rangedInteract))
end

SlashCmdList.PRETTYFRAMES = function(message)
    local command, argument = message:lower():match("^(%S*)%s*(.-)$")
    if command == "" or command == "options" or command == "config" then
        PF:OpenOptions()
    elseif command == "help" then
        ShowHelp()
    elseif command == "lock" or command == "edit" then
        PF:SetLocked(not PF.db.locked)
    elseif command == "testedit" or command == "edittest" then
        ToggleEditTestModes()
    elseif command == "range" or command == "rangeprobe" then
        PrintRangeProbe()
    elseif command == "scale" then
        local scale = tonumber(argument)
        if not PF:IsValidScale(scale) then
            PF:Print(("scale must be between %.1f and %.1f."):format(PF.MIN_SCALE, PF.MAX_SCALE))
            return
        end
        PF.db.scale = scale
        PF:RefreshScale()
        PF:Print("scale set to " .. scale .. ".")
    elseif command == "test" then
        local testWord, testArgument = argument:match("^(%S+)%s*(.-)$")
        local actionWord, category, modifier, button = argument:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)$")
        if testWord == "resource" then
            PF:SetClassResourceTest(testArgument ~= "" and testArgument or "next")
        elseif actionWord == "action" then
            local modifiers = {
                none = "NONE", shift = "SHIFT", ctrl = "CTRL", alt = "ALT",
                ["shift+ctrl"] = "SHIFT_CTRL", ["ctrl+shift"] = "SHIFT_CTRL",
                ["shift+alt"] = "SHIFT_ALT", ["alt+shift"] = "SHIFT_ALT",
                ["ctrl+alt"] = "CTRL_ALT", ["alt+ctrl"] = "CTRL_ALT",
                ["shift+ctrl+alt"] = "SHIFT_CTRL_ALT", ["shift+alt+ctrl"] = "SHIFT_CTRL_ALT",
                ["ctrl+shift+alt"] = "SHIFT_CTRL_ALT", ["ctrl+alt+shift"] = "SHIFT_CTRL_ALT",
                ["alt+shift+ctrl"] = "SHIFT_CTRL_ALT", ["alt+ctrl+shift"] = "SHIFT_CTRL_ALT",
            }
            local buttons = { left = "LeftButton", right = "RightButton", middle = "MiddleButton" }
            for index = 4, 31 do
                buttons[tostring(index)] = "Button" .. index
                buttons["button" .. index] = "Button" .. index
                buttons["mouse" .. index] = "Button" .. index
            end
            if not PF.ACTION_CATEGORIES[category] or not modifiers[modifier] or not buttons[button] then
                PF:Print("use /pf test action player|pet|target|targettarget|focus|boss|party|raid none|shift|ctrl|alt|shift+ctrl|shift+alt|ctrl+alt|shift+ctrl+alt left|right|middle|4-31")
                return
            end
            PF:PrintActionTest(category, modifiers[modifier], buttons[button])
        else
            PF:SetTestMode(not PF.testMode)
        end
    elseif command == "blizzard" then
        if argument ~= "on" and argument ~= "off" then
            PF:Print("use /pf blizzard on or /pf blizzard off.")
            return
        end
        local replace = argument == "off"
        PF.db.replaceUnitFrames = replace
        PF.db.replaceBossFrames = replace
        PF.db.replacePartyFrames = replace
        PF.db.replaceRaidFrames = replace
        PF:Print("Blizzard frames will be " .. (replace and "replaced" or "shown") .. " after reload.")
        ReloadUI()
    elseif command == "reset" then
        StaticPopup_Show("PRETTYFRAMES_RESET_SETTINGS")
    else
        ShowHelp()
    end
end
