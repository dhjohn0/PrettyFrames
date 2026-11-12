local _, PF = ...

local partyDisplayProfiles = {
    balanced = {
        showDebuffs = true,
        showDispellableDebuffs = false,
        showPredictions = true,
        showMaintenance = false,
        showThreat = true,
    },
    healer = {
        showDebuffs = true,
        showDispellableDebuffs = true,
        showPredictions = true,
        showMaintenance = true,
        showThreat = true,
    },
    minimal = {
        showDebuffs = true,
        showDispellableDebuffs = false,
        showPredictions = false,
        showMaintenance = false,
        showThreat = false,
    },
}

function PF:ApplyPartyDisplayProfileOptions(options, profileName)
    local profile = partyDisplayProfiles[profileName]
    if not profile or not options then return false end
    for key, value in pairs(profile) do
        options[key] = value
    end
    options.displayProfile = profileName
    return true
end

function PF:ApplyPartyDisplayProfile(profileName)
    local options = self.db and self.db.partyLayout
    if not self:ApplyPartyDisplayProfileOptions(options, profileName) then return end
    if self.ApplyPartyIndicatorFilters then self:ApplyPartyIndicatorFilters() end
    self:RefreshPartyFrames(false)
end

local raidDisplayProfiles = {
    balanced = {
        healthTextMode = "deficit",
        accountForIncomingHeals = false,
        showDebuffs = true,
        showDispellableDebuffs = true,
        showMaintenance = true,
        showPredictions = true,
        showHealAbsorbs = true,
        showRoleIcons = true,
        showLeadership = true,
        showTargetHighlight = true,
        showThreat = true,
        maintenanceDuration = 120,
    },
    healer = {
        healthTextMode = "deficit",
        accountForIncomingHeals = true,
        showDebuffs = true,
        showDispellableDebuffs = true,
        showMaintenance = true,
        showPredictions = true,
        showHealAbsorbs = true,
        showRoleIcons = true,
        showLeadership = false,
        showTargetHighlight = true,
        showThreat = true,
        maintenanceDuration = 60,
    },
    tank = {
        healthTextMode = "percent",
        accountForIncomingHeals = false,
        showDebuffs = true,
        showDispellableDebuffs = true,
        showMaintenance = false,
        showPredictions = false,
        showHealAbsorbs = true,
        showRoleIcons = true,
        showLeadership = false,
        showTargetHighlight = true,
        showThreat = true,
        maintenanceDuration = 60,
    },
    minimal = {
        healthTextMode = "none",
        accountForIncomingHeals = false,
        showDebuffs = true,
        showDispellableDebuffs = false,
        showMaintenance = false,
        showPredictions = true,
        showHealAbsorbs = false,
        showRoleIcons = true,
        showLeadership = false,
        showTargetHighlight = true,
        showThreat = true,
        maintenanceDuration = 60,
    },
}

function PF:ApplyRaidDisplayProfileOptions(options, profileName)
    local profile = raidDisplayProfiles[profileName]
    if not profile or not options then return false end
    for key, value in pairs(profile) do
        options[key] = value
    end
    options.displayProfile = profileName
    return true
end

function PF:ApplyRaidDisplayProfile(profileName)
    local options = self.db and self.db.raidLayout
    if not self:ApplyRaidDisplayProfileOptions(options, profileName) then return end
    if self.ApplyRaidDebuffFilters then self:ApplyRaidDebuffFilters() end
    if self.ApplyRaidMaintenanceFilters then self:ApplyRaidMaintenanceFilters() end
    self:RefreshRaidFrames()
end

local function MarkRaidDisplayProfileCustom(options)
    options.displayProfile = "custom"
end

function PF:OpenRaidContextMenu(owner)
    if InCombatLockdown() then return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        self:Print("the raid menu is unavailable on this client build.")
        return
    end

    local options = self.db.raidLayout
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle("Raid Frames")
        rootDescription:CreateButton("Actions...", function()
            PF:OpenActionsWindow("raid")
        end)
        rootDescription:CreateDivider()
        PF:AddScaleMenuOption(rootDescription, options.scale or 1, function(value)
            options.scale = value
            PF:RefreshScale()
        end)
        local profileMenu = rootDescription:CreateButton("Display Profile")
        local function IsProfileSelected(value)
            return options.displayProfile == value
        end
        local function SetProfileSelected(value)
            PF:ApplyRaidDisplayProfile(value)
        end
        profileMenu:CreateRadio("Balanced", IsProfileSelected, SetProfileSelected, "balanced")
        profileMenu:CreateRadio("Healer", IsProfileSelected, SetProfileSelected, "healer")
        profileMenu:CreateRadio("Tank", IsProfileSelected, SetProfileSelected, "tank")
        profileMenu:CreateRadio("Minimal", IsProfileSelected, SetProfileSelected, "minimal")
        if options.displayProfile == "custom" then
            profileMenu:CreateRadio("Custom", IsProfileSelected, function() end, "custom")
        end

        PF:AddVisibilityMenuOption(rootDescription, function()
            return options.visibility or "auto"
        end, function(value)
            if InCombatLockdown() then
                PF:Print("raid frame visibility cannot change during combat.")
                return
            end
            options.visibility = value
            PF:ApplyRaidGroupVisibility()
        end)
        local layoutMenu = rootDescription:CreateButton("Layout")
        local healthTextMenu = rootDescription:CreateButton("Health Text")
        local indicatorMenu = rootDescription:CreateButton("Auras & Indicators")
        local groupMenu = rootDescription:CreateButton("Group Usage")

        groupMenu:CreateCheckbox("Use in Parties", function()
            return options.useInParty == true
        end, function()
            if InCombatLockdown() then
                PF:Print("raid unit bindings cannot change during combat.")
                return
            end
            options.useInParty = not options.useInParty
            PF:ApplyRaidUnitBindings()
            PF:ApplyGroupStateDrivers()
        end)

        layoutMenu:CreateCheckbox("Show Group Headers", function()
            return options.showHeaders ~= false
        end, function()
            options.showHeaders = options.showHeaders == false
            PF:ApplyRaidHeaderDisplay()
        end)
        layoutMenu:CreateCheckbox("Independent Positioning", function()
            return options.independentPositioning == true
        end, function()
            if InCombatLockdown() then
                PF:Print("raid group positioning cannot change during combat.")
                return
            end
            if options.independentPositioning then
                PF:SaveRaidGroupOffsets()
            end
            options.independentPositioning = not options.independentPositioning
            PF:ApplyRaidGroupLayout()
        end)

        layoutMenu:CreateDivider()
        layoutMenu:CreateTitle("Sort Order")
        local function IsSelected(value)
            return options.sort == value
        end
        local function SetSelected(value)
            if InCombatLockdown() then
                PF:Print("raid sorting cannot change during combat.")
                return
            end
            options.sort = value
            PF:ApplyRaidUnitBindings()
        end
        layoutMenu:CreateRadio("Raid Order", IsSelected, SetSelected, "index")
        layoutMenu:CreateRadio("Role", IsSelected, SetSelected, "role")
        layoutMenu:CreateRadio("Name", IsSelected, SetSelected, "name")

        local function IsHealthTextSelected(value)
            return options.healthTextMode == value
        end
        local function SetHealthTextSelected(value)
            options.healthTextMode = value
            MarkRaidDisplayProfileCustom(options)
            PF:RefreshRaidFrames()
        end
        healthTextMenu:CreateRadio("Missing Health", IsHealthTextSelected, SetHealthTextSelected, "deficit")
        healthTextMenu:CreateRadio("Percentage", IsHealthTextSelected, SetHealthTextSelected, "percent")
        healthTextMenu:CreateRadio("Current / Maximum", IsHealthTextSelected, SetHealthTextSelected, "currentmax")
        healthTextMenu:CreateRadio("Hidden", IsHealthTextSelected, SetHealthTextSelected, "none")
        healthTextMenu:CreateDivider()
        healthTextMenu:CreateCheckbox("Account for Incoming Heals", function()
            return options.accountForIncomingHeals == true
        end, function()
            options.accountForIncomingHeals = options.accountForIncomingHeals ~= true
            MarkRaidDisplayProfileCustom(options)
            PF:RefreshRaidFrames()
        end)

        indicatorMenu:CreateCheckbox("Primary Debuff", function()
            return options.showDebuffs ~= false
        end, function()
            options.showDebuffs = options.showDebuffs == false
            MarkRaidDisplayProfileCustom(options)
            PF:ApplyRaidDebuffFilters()
            PF:RefreshRaidFrames()
        end)
        indicatorMenu:CreateCheckbox("Dispellable Debuffs", function()
            return options.showDispellableDebuffs ~= false
        end, function()
            options.showDispellableDebuffs = options.showDispellableDebuffs == false
            MarkRaidDisplayProfileCustom(options)
            PF:ApplyRaidDebuffFilters()
            PF:RefreshRaidFrames()
        end)
        indicatorMenu:CreateCheckbox("Maintenance Effects", function()
            return options.showMaintenance ~= false
        end, function()
            options.showMaintenance = options.showMaintenance == false
            MarkRaidDisplayProfileCustom(options)
            PF:RefreshRaidFrames()
        end)
        indicatorMenu:CreateCheckbox("Incoming Heals & Absorbs", function()
            return options.showPredictions ~= false
        end, function()
            options.showPredictions = options.showPredictions == false
            MarkRaidDisplayProfileCustom(options)
            PF:RefreshRaidFrames()
        end)
        indicatorMenu:CreateCheckbox("Heal Absorbs", function()
            return options.showHealAbsorbs ~= false
        end, function()
            options.showHealAbsorbs = options.showHealAbsorbs == false
            MarkRaidDisplayProfileCustom(options)
            PF:RefreshRaidFrames()
        end)
        indicatorMenu:CreateCheckbox("Role Icons", function()
            return options.showRoleIcons ~= false
        end, function()
            options.showRoleIcons = options.showRoleIcons == false
            MarkRaidDisplayProfileCustom(options)
            PF:RefreshRaidFrames()
        end)
        indicatorMenu:CreateCheckbox("Leadership Icons", function()
            return options.showLeadership ~= false
        end, function()
            options.showLeadership = options.showLeadership == false
            MarkRaidDisplayProfileCustom(options)
            PF:RefreshRaidFrames()
        end)
        indicatorMenu:CreateCheckbox("Target Highlight", function()
            return options.showTargetHighlight ~= false
        end, function()
            options.showTargetHighlight = options.showTargetHighlight == false
            MarkRaidDisplayProfileCustom(options)
            PF:RefreshRaidFrames()
        end)
        indicatorMenu:CreateCheckbox("Threat Warning", function()
            return options.showThreat ~= false
        end, function()
            options.showThreat = options.showThreat == false
            MarkRaidDisplayProfileCustom(options)
            PF:RefreshRaidFrames()
        end)

        indicatorMenu:CreateDivider()
        indicatorMenu:CreateTitle("Maintenance Duration")
        local maintenanceDurationMenu = indicatorMenu
        local function IsMaintenanceDurationSelected(value)
            return options.maintenanceDuration == value
        end
        local function SetMaintenanceDurationSelected(value)
            options.maintenanceDuration = value
            MarkRaidDisplayProfileCustom(options)
            PF:ApplyRaidMaintenanceFilters()
        end
        maintenanceDurationMenu:CreateRadio("30 seconds", IsMaintenanceDurationSelected, SetMaintenanceDurationSelected, 30)
        maintenanceDurationMenu:CreateRadio("60 seconds", IsMaintenanceDurationSelected, SetMaintenanceDurationSelected, 60)
        maintenanceDurationMenu:CreateRadio("120 seconds", IsMaintenanceDurationSelected, SetMaintenanceDurationSelected, 120)
    end)
end
