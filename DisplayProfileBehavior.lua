local _, PF = ...

local profileSets = {
    party = {
        order = {
            { id = "balanced", label = "Balanced" },
            { id = "healer", label = "Healer" },
            { id = "minimal", label = "Minimal" },
        },
        profiles = {
            balanced = {
                healthTextMode = "currentmax",
                accountForIncomingHeals = false,
                showDebuffs = true,
                showDispellableDebuffs = false,
                showPredictions = true,
                showMaintenance = false,
                showRoleIcons = true,
                showLeadership = true,
                showTargetHighlight = true,
                showThreat = true,
            },
            healer = {
                healthTextMode = "deficit",
                accountForIncomingHeals = true,
                showDebuffs = true,
                showDispellableDebuffs = true,
                showPredictions = true,
                showMaintenance = true,
                showRoleIcons = true,
                showLeadership = false,
                showTargetHighlight = true,
                showThreat = true,
            },
            minimal = {
                healthTextMode = "none",
                accountForIncomingHeals = false,
                showDebuffs = true,
                showDispellableDebuffs = false,
                showPredictions = false,
                showMaintenance = false,
                showRoleIcons = true,
                showLeadership = false,
                showTargetHighlight = true,
                showThreat = false,
            },
        },
    },
    raid = {
        order = {
            { id = "balanced", label = "Balanced" },
            { id = "healer", label = "Healer" },
            { id = "tank", label = "Tank" },
            { id = "minimal", label = "Minimal" },
        },
        profiles = {
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
        },
    },
}

local DisplayProfileBehavior = {
    autoAttach = { groupFrame = true },
    contextMenuScope = "move",
    contextMenuOrder = 40,
    contextMenuGroup = { key = "displayProfile", title = "Display Profile" },
    -- A display profile is a preset selector, not independently rendered state.
    -- It refreshes only when a profile is selected or a caller explicitly asks.
    RefreshAll = function() end,
}
PF.DisplayProfileBehavior = PF.FrameBehaviors:Register(
    "displayProfile", DisplayProfileBehavior
)

function DisplayProfileBehavior:ValidateAttachment(_, options)
    assert(profileSets[options.profileSet],
        "unknown display profile set: " .. tostring(options.profileSet))
    assert(type(options.getOptions) == "function",
        "display profile behavior requires getOptions")
end

function DisplayProfileBehavior:ApplyProfileOptions(profileSet, options, profileName)
    local set = profileSets[profileSet]
    local profile = set and set.profiles[profileName]
    if not profile or not options then return false end
    for key, value in pairs(profile) do options[key] = value end
    options.displayProfile = profileName
    return true
end

function DisplayProfileBehavior:Apply(attachment)
    if attachment and attachment.options.refresh then attachment.options.refresh() end
end

function DisplayProfileBehavior:SelectProfile(subject, profileName)
    local attachment = self:GetAttachment(subject)
    if not attachment then return false end
    local options = attachment.options.getOptions()
    if not self:ApplyProfileOptions(attachment.options.profileSet, options, profileName) then
        return false
    end
    self:Refresh(attachment)
    return true
end

function DisplayProfileBehavior:MarkCustom(subject)
    local attachment = self:GetAttachment(subject)
    if not attachment then return false end
    local options = attachment.options.getOptions()
    if not options then return false end
    options.displayProfile = "custom"
    return true
end

function DisplayProfileBehavior:AddContextMenu(rootDescription, attachment)
    local options = attachment.options.getOptions()
    local set = profileSets[attachment.options.profileSet]
    if not options or not set then return end

    local function IsSelected(value)
        return options.displayProfile == value
    end
    local function SetSelected(value)
        self:SelectProfile(attachment.subject, value)
    end
    for _, profile in ipairs(set.order) do
        rootDescription:CreateRadio(
            profile.label, IsSelected, SetSelected, profile.id
        )
    end
    if options.displayProfile == "custom" then
        rootDescription:CreateRadio("Custom", IsSelected, function() end, "custom")
    end
end

function PF:ApplyPartyDisplayProfileOptions(options, profileName)
    return DisplayProfileBehavior:ApplyProfileOptions("party", options, profileName)
end

function PF:ApplyRaidDisplayProfileOptions(options, profileName)
    return DisplayProfileBehavior:ApplyProfileOptions("raid", options, profileName)
end

local function ApplyAttachedProfile(profileSet, subject, options, profileName)
    if subject and DisplayProfileBehavior:GetAttachment(subject) then
        return DisplayProfileBehavior:SelectProfile(subject, profileName)
    end
    local applied = DisplayProfileBehavior:ApplyProfileOptions(
        profileSet, options, profileName
    )
    if applied and subject and PF.AuraIndicatorBehavior then
        PF.AuraIndicatorBehavior:RefreshSubject(subject)
    end
    return applied
end

function PF:ApplyPartyDisplayProfile(profileName)
    return ApplyAttachedProfile(
        "party", self.frames and self.frames.party,
        self.db and self.db.partyLayout, profileName
    )
end

function PF:ApplyRaidDisplayProfile(profileName)
    return ApplyAttachedProfile(
        "raid", self.frames and self.frames.raid,
        self.db and self.db.raidLayout, profileName
    )
end
