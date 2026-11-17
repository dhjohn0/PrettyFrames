local _, PF = ...

local modes = { "solo", "party", "raid" }
local modeLabels = { solo = "Solo", party = "Party", raid = "Raid" }

local function Copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do result[Copy(key, seen)] = Copy(child, seen) end
    return result
end

local function ValidPosition(position)
    return type(position) == "table"
        and type(position[1]) == "string"
        and type(position[2]) == "string"
        and type(position[3]) == "string"
        and type(position[4]) == "number"
        and type(position[5]) == "number"
end

local function ThemeDefaultPositions()
    local theme = PF:GetTheme()
    local defaults = theme and theme.layout and theme.layout.screen
        and theme.layout.screen.positions or {}
    local positions = {}
    for key, position in pairs(defaults) do
        if ValidPosition(position) then positions[key] = Copy(position) end
    end
    return positions
end

local function NormalizePositions(saved, fallback)
    local positions = {}
    for key, position in pairs(type(fallback) == "table" and fallback or {}) do
        if type(key) == "string" and ValidPosition(position) then
            positions[key] = Copy(position)
        end
    end
    for key, position in pairs(type(saved) == "table" and saved or {}) do
        if type(key) == "string" and ValidPosition(position) then
            positions[key] = Copy(position)
        end
    end
    return positions
end

local function NormalizeGroupOffsets(saved)
    local offsets = {}
    for index = 1, 5 do
        local offset = type(saved) == "table" and saved[index]
        offsets[index] = type(offset) == "table"
            and type(offset[1]) == "number" and type(offset[2]) == "number"
            and { offset[1], offset[2] } or { 0, 0 }
    end
    return offsets
end

function PF:GetRuntimeGroupLayoutMode()
    if IsInRaid and IsInRaid() then return "raid" end
    if IsInGroup and IsInGroup() then return "party" end
    return "solo"
end

function PF:GetSelectedGroupLayoutMode()
    return self.editingGroupLayoutMode or self.activeGroupLayoutMode
        or self:GetRuntimeGroupLayoutMode()
end

function PF:InitializeGroupLayouts()
    if not self.db then return end
    local saved = type(self.db.groupLayouts) == "table" and self.db.groupLayouts or {}
    local shared = NormalizePositions(saved.sharedPositions, self.db.positions)
    local sharedOffsets = NormalizeGroupOffsets(
        saved.sharedGroupOffsets or self.db.raidLayout.groupOffsets
    )
    local layouts = {
        sharedPositions = shared,
        sharedGroupOffsets = sharedOffsets,
    }
    for _, mode in ipairs(modes) do
        local layout = type(saved[mode]) == "table" and saved[mode] or {}
        layouts[mode] = {
            positions = NormalizePositions(layout.positions, shared),
            groupOffsets = NormalizeGroupOffsets(layout.groupOffsets or sharedOffsets),
        }
    end
    self.db.groupLayouts = layouts

    local themeOptions = self.db.themeSettings and self.db.themeSettings[self.db.theme]
    if themeOptions then
        themeOptions.groupLayouts = layouts
        themeOptions.groupLayoutsEnabled = self.db.groupLayoutsEnabled == true
    end

    if self.db.groupLayoutsEnabled then
        local mode = self:GetRuntimeGroupLayoutMode()
        self.activeGroupLayoutMode = mode
        self.db.positions = layouts[mode].positions
        self.db.raidLayout.groupOffsets = layouts[mode].groupOffsets
    else
        self.activeGroupLayoutMode = nil
        self.db.positions = layouts.sharedPositions
        self.db.raidLayout.groupOffsets = layouts.sharedGroupOffsets
    end
end

function PF:SaveActiveGroupLayout()
    if not self.db or not self.db.groupLayoutsEnabled then return end
    local mode = self.activeGroupLayoutMode
    local layout = mode and self.db.groupLayouts and self.db.groupLayouts[mode]
    if not layout then return end
    layout.positions = self.db.positions
    layout.groupOffsets = self.db.raidLayout.groupOffsets
end

function PF:ApplyGroupLayoutPositions()
    if not self.frames or InCombatLockdown() then return false end
    for key, position in pairs(self.db.positions or {}) do
        local frame = self.frames[key]
        if frame and frame.isAnchor and ValidPosition(position) then
            self:PlaceFrame(frame, key)
        end
    end
    if self.frames.targettarget and self.ApplyTargetTargetPosition then
        self:ApplyTargetTargetPosition(self.frames.targettarget)
    end
    if self.ApplyBossGroupLayout then self:ApplyBossGroupLayout() end
    if self.ApplyRaidGroupLayout then self:ApplyRaidGroupLayout() end
    return true
end

function PF:ApplyGroupLayoutMode(mode, silent)
    if not self.db or not self.db.groupLayoutsEnabled or not modeLabels[mode] then
        return false
    end
    local layout = self.db.groupLayouts[mode]
    if self.activeGroupLayoutMode == mode and self.db.positions == layout.positions then
        self.pendingGroupLayoutMode = nil
        self:UpdateGroupLayoutSelector()
        return true
    end
    if InCombatLockdown() then
        local changed = self.pendingGroupLayoutMode ~= mode
        self.pendingGroupLayoutMode = mode
        if changed and not silent then
            self:Print(modeLabels[mode] .. " layout will apply after combat.")
        end
        return false
    end

    self:SaveActiveGroupLayout()
    self.activeGroupLayoutMode = mode
    self.pendingGroupLayoutMode = nil
    self.db.positions = layout.positions
    self.db.raidLayout.groupOffsets = layout.groupOffsets
    self:ApplyGroupLayoutPositions()
    self:RefreshScale()
    self:UpdateGroupLayoutSelector()
    return true
end

function PF:UpdateGroupLayoutForGroupState()
    if not self.db or not self.db.groupLayoutsEnabled then return end
    if self.editingGroupLayoutMode then return end
    return self:ApplyGroupLayoutMode(self:GetRuntimeGroupLayoutMode(), false)
end

function PF:SetGroupLayoutsEnabled(enabled)
    if not self.db or self.db.groupLayoutsEnabled == (enabled == true) then return true end
    if InCombatLockdown() then
        self:Print("group layouts cannot change during combat.")
        return false
    end
    enabled = enabled == true
    if enabled then
        if not self.db.groupLayouts then self:InitializeGroupLayouts() end
        self.db.groupLayoutsEnabled = true
        self:SetThemeOption("groupLayoutsEnabled", true)
        local mode = self:GetRuntimeGroupLayoutMode()
        self.editingGroupLayoutMode = self.db.locked == false and mode or nil
        return self:ApplyGroupLayoutMode(mode, true)
    end

    self:SaveActiveGroupLayout()
    self.db.groupLayouts.sharedPositions = Copy(self.db.positions)
    self.db.groupLayouts.sharedGroupOffsets = Copy(self.db.raidLayout.groupOffsets)
    self.db.groupLayoutsEnabled = false
    self:SetThemeOption("groupLayoutsEnabled", false)
    self.activeGroupLayoutMode = nil
    self.editingGroupLayoutMode = nil
    self.db.positions = self.db.groupLayouts.sharedPositions
    self.db.raidLayout.groupOffsets = self.db.groupLayouts.sharedGroupOffsets
    self:ApplyGroupLayoutPositions()
    self:UpdateGroupLayoutSelector()
    return true
end

function PF:BeginGroupLayoutEditing()
    if not self.db or not self.db.groupLayoutsEnabled then
        self.editingGroupLayoutMode = nil
        return self:UpdateGroupLayoutSelector()
    end
    local mode = self:GetRuntimeGroupLayoutMode()
    self.editingGroupLayoutMode = mode
    self:ApplyGroupLayoutMode(mode, true)
    self:UpdateGroupLayoutSelector()
end

function PF:EndGroupLayoutEditing()
    if not self.db or not self.db.groupLayoutsEnabled then return end
    self:SaveActiveGroupLayout()
    self.editingGroupLayoutMode = nil
    self:ApplyGroupLayoutMode(self:GetRuntimeGroupLayoutMode(), true)
    self:UpdateGroupLayoutSelector()
end

function PF:SelectGroupLayoutForEditing(mode)
    if self.db.locked or not modeLabels[mode] then return false end
    self.editingGroupLayoutMode = mode
    return self:ApplyGroupLayoutMode(mode, true)
end

function PF:ResetGroupLayoutMode(mode)
    if not self.db or not self.db.groupLayoutsEnabled or not modeLabels[mode]
        or self.db.locked or InCombatLockdown() then return false end
    local layout = self.db.groupLayouts[mode]
    layout.positions = ThemeDefaultPositions()
    layout.groupOffsets = NormalizeGroupOffsets(nil)
    if self.activeGroupLayoutMode == mode then
        self.db.positions = layout.positions
        self.db.raidLayout.groupOffsets = layout.groupOffsets
        self:ApplyGroupLayoutPositions()
    end
    return true
end

StaticPopupDialogs.PRETTYFRAMES_RESET_GROUP_LAYOUT = {
    text = "Reset the %s layout to the current theme's default positions?",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(_, data)
        if data and data.mode then PF:ResetGroupLayoutMode(data.mode) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local selector = CreateFrame(
    "Frame", "PrettyFramesGroupLayoutSelector", UIParent, "BackdropTemplate"
)
selector:SetSize(330, 50)
selector:SetPoint("TOP", UIParent, "TOP", 0, -52)
selector:SetFrameStrata("DIALOG")
selector:SetFrameLevel(50)
selector:EnableMouse(true)
PF:CreateBackdrop(selector, 2)
selector:SetBackdropColor(0.08, 0.045, 0.02, 0.97)
selector:Hide()

selector.label = selector:CreateFontString(nil, "OVERLAY", "GameFontNormal")
selector.label:SetPoint("LEFT", 14, 0)
selector.label:SetTextColor(unpack(PF.colors.bronzeBright))

selector.reset = CreateFrame("Button", nil, selector, "UIPanelButtonTemplate")
selector.reset:SetSize(98, 26)
selector.reset:SetPoint("RIGHT", -10, 0)
selector.reset:SetText("Reset Mode")
selector.reset:SetScript("OnClick", function()
    local mode = PF:GetSelectedGroupLayoutMode()
    StaticPopup_Show(
        "PRETTYFRAMES_RESET_GROUP_LAYOUT", modeLabels[mode], nil, { mode = mode }
    )
end)

selector:SetScript("OnEnter", function(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Group Layouts")
    GameTooltip:AddLine("Right-click to choose the layout you want to edit.", 1, 1, 1, true)
    GameTooltip:Show()
end)
selector:SetScript("OnLeave", function() GameTooltip:Hide() end)
selector:SetScript("OnMouseUp", function(frame, button)
    if button ~= "RightButton" or not MenuUtil or not MenuUtil.CreateContextMenu then return end
    MenuUtil.CreateContextMenu(frame, function(_, root)
        root:CreateTitle("Edit Group Layout")
        for _, mode in ipairs(modes) do
            local selectedMode = mode
            root:CreateRadio(modeLabels[mode], function()
                return PF:GetSelectedGroupLayoutMode() == selectedMode
            end, function()
                PF:SelectGroupLayoutForEditing(selectedMode)
            end)
        end
    end)
end)

PF.groupLayoutSelector = selector

function PF:UpdateGroupLayoutSelector()
    if not self.groupLayoutSelector or not self.db then return end
    local shown = self.db.groupLayoutsEnabled == true and self.db.locked == false
        and not InCombatLockdown()
    self.groupLayoutSelector:SetShown(shown)
    if shown then
        local mode = self:GetSelectedGroupLayoutMode()
        self.groupLayoutSelector.label:SetText(
            "CURRENT MODE: " .. string.upper(modeLabels[mode] or mode)
        )
    end
end
