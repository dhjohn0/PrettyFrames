local _, PF = ...

local RAID_DEBUFF_GROUP = "prettyframes-raid-debuff"
local RAID_OWNED_MAINTENANCE_GROUP = "prettyframes-raid-owned-maintenance"

local AuraIndicatorBehavior = {
    autoAttach = { unitFrame = "AttachUnitFrame", groupFrame = true },
    contextMenuOrder = 90,
    contextMenuGroup = { key = "aurasIndicators", title = "Auras & Indicators" },
}
PF.AuraIndicatorBehavior = PF.FrameBehaviors:Register("auraIndicators", AuraIndicatorBehavior)

function AuraIndicatorBehavior:ValidateAttachment(_, options)
    assert(options.kind, "aura and indicator behavior kind is required")
    if options.kind == "party" then
        assert(type(options.applyLayout) == "function",
            "party aura and indicator behavior requires applyLayout")
    end
end

function AuraIndicatorBehavior:ConfigureAttachment(attachment)
    attachment.deferredApplyKey = attachment.deferredApplyKey or {}
end

function AuraIndicatorBehavior:ApplyUnitFrame(frame, setting)
    if frame.SetBuffsAbove then frame:SetBuffsAbove(setting.buffsAbove) end
    if frame.SetAuraLimits then
        setting.maxBuffs = setting.maxBuffs or frame.defaultMaxBuffs or 0
        setting.maxDebuffs = setting.maxDebuffs or frame.defaultMaxDebuffs or 0
        frame:SetAuraLimits(setting.maxBuffs, setting.maxDebuffs)
    end
    if frame.SetAurasLeft then frame:SetAurasLeft(setting.aurasLeft) end
end

function AuraIndicatorBehavior:AttachUnitFrame(frame, settingKey)
    if not frame or not settingKey then return end
    local hasMenu = frame.SetBuffsAbove or frame.SetAurasLeft or frame.SetAuraLimits
    if not hasMenu then return end

    local attachment = PF.FrameBehaviors:Attach("auraIndicators", frame, {
        kind = "unit",
        contextMenuScope = settingKey:match("^party%d+$") and "individual" or "move",
        getSetting = function() return PF:GetFrameSetting(settingKey) end,
        isPartyFrame = settingKey:match("^party%d+$") ~= nil,
    })
    self:Refresh(attachment)
    return attachment
end

function AuraIndicatorBehavior:ApplyPartyFilters()
    local anchor = PF.frames and PF.frames.party
    local options = PF.db and PF.db.partyLayout
    if not anchor or not anchor.partyFrames or not options then return end
    for _, frame in ipairs(anchor.partyFrames) do
        local debuffs = frame.nativeDebuffs and frame.nativeDebuffs.container
        if debuffs and debuffs.SetAuraGroupMaxFrameCount then
            local showPrimary = options.showDebuffs ~= false
            local showDispellable = options.showDispellableDebuffs ~= false
            debuffs:SetAuraGroupMaxFrameCount(RAID_DEBUFF_GROUP,
                (showPrimary or showDispellable) and 1 or 0)
            if debuffs.SetAuraGroupFilterString then
                debuffs:SetAuraGroupFilterString(RAID_DEBUFF_GROUP,
                    showDispellable and not showPrimary and "HARMFUL|RAID" or "HARMFUL")
            end
            if debuffs.SetAuraGroupCandidateFilters then
                debuffs:SetAuraGroupCandidateFilters(RAID_DEBUFF_GROUP,
                    showPrimary and not showDispellable and { isBossOrRoleAura = true } or nil)
            end
        end
        local maintenance = frame.nativeMaintenance and frame.nativeMaintenance.container
        if maintenance and maintenance.SetAuraGroupCandidateFilters then
            maintenance:SetAuraGroupCandidateFilters(RAID_OWNED_MAINTENANCE_GROUP, {
                isFromPlayerOrPlayerPet = true,
                maxDuration = 60,
            })
        end
        PF:UpdateAuras(frame)
        PF:RefreshNativeAuras(frame)
    end
end

function AuraIndicatorBehavior:ApplyRaidDebuffFilters()
    local anchor = PF.frames and PF.frames.raid
    local options = PF.db and PF.db.raidLayout
    if not anchor or not anchor.raidFrames or not options then return end
    for _, frame in ipairs(anchor.raidFrames) do
        local container = frame.nativeDebuffs and frame.nativeDebuffs.container
        if container and container.SetAuraGroupMaxFrameCount then
            local showPrimary = options.showDebuffs ~= false
            local showDispellable = options.showDispellableDebuffs ~= false
            container:SetAuraGroupMaxFrameCount(RAID_DEBUFF_GROUP,
                (showPrimary or showDispellable) and 1 or 0)
            if container.SetAuraGroupFilterString then
                container:SetAuraGroupFilterString(RAID_DEBUFF_GROUP,
                    showDispellable and not showPrimary and "HARMFUL|RAID" or "HARMFUL")
            end
            if container.SetAuraGroupCandidateFilters then
                container:SetAuraGroupCandidateFilters(RAID_DEBUFF_GROUP,
                    showPrimary and not showDispellable and { isBossOrRoleAura = true } or nil)
            end
            if container.prettyFramesEnabled then container:UpdateAllAuras() end
        end
    end
end

function AuraIndicatorBehavior:ApplyRaidMaintenanceFilters()
    local anchor = PF.frames and PF.frames.raid
    local duration = PF.db and PF.db.raidLayout
        and PF.db.raidLayout.maintenanceDuration or 120
    if not anchor or not anchor.raidFrames then return end
    for _, frame in ipairs(anchor.raidFrames) do
        local container = frame.nativeMaintenance and frame.nativeMaintenance.container
        if container and container.SetAuraGroupCandidateFilters then
            container:SetAuraGroupCandidateFilters(RAID_OWNED_MAINTENANCE_GROUP, {
                isFromPlayerOrPlayerPet = true,
                maxDuration = duration,
            })
            if container.prettyFramesEnabled then container:UpdateAllAuras() end
        end
    end
end

function AuraIndicatorBehavior:Apply(attachment)
    if not attachment then return end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredApplyKey,
        function()
            local kind = attachment.options.kind
            if kind == "unit" then
                self:ApplyUnitFrame(attachment.subject, attachment.options.getSetting())
            elseif kind == "boss" then
                PF:ApplyBossAuraOptions()
            elseif kind == "party" then
                self:ApplyPartyFilters()
                attachment.options.applyLayout()
                PF:RefreshPartyFrames(false)
            elseif kind == "raid" then
                self:ApplyRaidDebuffFilters()
                self:ApplyRaidMaintenanceFilters()
                PF:RefreshRaidFrames()
            end
            return true
        end,
        attachment
    )
end

function PF:ApplyPartyIndicatorFilters()
    return AuraIndicatorBehavior:ApplyPartyFilters()
end

function PF:ApplyRaidDebuffFilters()
    return AuraIndicatorBehavior:ApplyRaidDebuffFilters()
end

function PF:ApplyRaidMaintenanceFilters()
    return AuraIndicatorBehavior:ApplyRaidMaintenanceFilters()
end

function PF:ApplyPartyAuraLayout()
    local subject = PF.frames and PF.frames.party
    return subject and AuraIndicatorBehavior:RefreshSubject(subject)
end

local function AddUnitMenu(rootDescription, attachment)
    local frame = attachment.subject
    local setting = attachment.options.getSetting()
    local menu = rootDescription
    if frame.SetBuffsAbove then
        menu:CreateCheckbox("Place Buffs Above", function() return setting.buffsAbove end, function()
            setting.buffsAbove = not setting.buffsAbove
            AuraIndicatorBehavior:Refresh(attachment)
        end)
    end
    if frame.SetAurasLeft then
        menu:CreateCheckbox("Place Auras on Left", function()
            return setting.aurasLeft == true
        end, function()
            setting.aurasLeft = not setting.aurasLeft
            AuraIndicatorBehavior:Refresh(attachment)
        end)
    end
    if frame.SetAuraLimits then
        menu:CreateTitle("Maximum Buffs")
        PF:AddMenuSlider(menu, setting.maxBuffs, 0, PF.MAX_AURAS, function(value)
            setting.maxBuffs = value
            AuraIndicatorBehavior:Refresh(attachment)
        end)
        if not attachment.options.isPartyFrame then
            menu:CreateTitle("Maximum Debuffs")
            PF:AddMenuSlider(menu, setting.maxDebuffs, 0, PF.MAX_AURAS, function(value)
                setting.maxDebuffs = value
                AuraIndicatorBehavior:Refresh(attachment)
            end)
        end
    end
end

local function AddBossMenu(rootDescription, attachment)
    local options = attachment.options.getOptions()
    local menu = rootDescription
    local function IsMode(value) return options.auraMode == value end
    local function SetMode(value)
        options.auraMode = value
        AuraIndicatorBehavior:Refresh(attachment)
    end
    menu:CreateTitle("Displayed Auras")
    menu:CreateRadio("Mechanics", IsMode, SetMode, "mechanics")
    menu:CreateRadio("Personal Debuffs", IsMode, SetMode, "personal")
    menu:CreateRadio("Hidden", IsMode, SetMode, "hidden")
    menu:CreateDivider()
    menu:CreateTitle("Aura Placement")
    local function IsSide(value)
        return (options.aurasLeft ~= false) == (value == "left")
    end
    local function SetSide(value)
        options.aurasLeft = value == "left"
        AuraIndicatorBehavior:Refresh(attachment)
    end
    menu:CreateRadio("Left", IsSide, SetSide, "left")
    menu:CreateRadio("Right", IsSide, SetSide, "right")
end

local function AddPartyMenu(rootDescription, attachment)
    local options = attachment.options.getOptions()
    local menu = rootDescription
    local function Toggle(key)
        options[key] = options[key] == false
        PF.DisplayProfileBehavior:MarkCustom(attachment.subject)
        AuraIndicatorBehavior:Refresh(attachment)
    end
    menu:CreateCheckbox("Primary Debuff", function()
        return options.showDebuffs ~= false
    end, function() Toggle("showDebuffs") end)
    menu:CreateCheckbox("Prioritize Dispellable Debuffs", function()
        return options.showDispellableDebuffs ~= false
    end, function() Toggle("showDispellableDebuffs") end)
    menu:CreateCheckbox("Maintenance Effects", function()
        return options.showMaintenance ~= false
    end, function() Toggle("showMaintenance") end)
    menu:CreateDivider()
    menu:CreateTitle("Aura Placement")
    menu:CreateRadio("Left", function() return options.aurasLeft == true end, function()
        options.aurasLeft = true
        AuraIndicatorBehavior:Refresh(attachment)
    end)
    menu:CreateRadio("Right", function() return options.aurasLeft ~= true end, function()
        options.aurasLeft = false
        AuraIndicatorBehavior:Refresh(attachment)
    end)
end

local function AddRaidMenu(rootDescription, attachment)
    local options = attachment.options.getOptions()
    local menu = rootDescription
    local function Toggle(key)
        options[key] = options[key] == false
        PF.DisplayProfileBehavior:MarkCustom(attachment.subject)
        AuraIndicatorBehavior:Refresh(attachment)
    end
    menu:CreateCheckbox("Primary Debuff", function()
        return options.showDebuffs ~= false
    end, function() Toggle("showDebuffs") end)
    menu:CreateCheckbox("Dispellable Debuffs", function()
        return options.showDispellableDebuffs ~= false
    end, function() Toggle("showDispellableDebuffs") end)
    menu:CreateCheckbox("Maintenance Effects", function()
        return options.showMaintenance ~= false
    end, function() Toggle("showMaintenance") end)
    menu:CreateDivider()
    menu:CreateTitle("Maintenance Duration")
    local function IsDuration(value) return options.maintenanceDuration == value end
    local function SetDuration(value)
        options.maintenanceDuration = value
        PF.DisplayProfileBehavior:MarkCustom(attachment.subject)
        AuraIndicatorBehavior:Refresh(attachment)
    end
    menu:CreateRadio("30 seconds", IsDuration, SetDuration, 30)
    menu:CreateRadio("60 seconds", IsDuration, SetDuration, 60)
    menu:CreateRadio("120 seconds", IsDuration, SetDuration, 120)
end

function AuraIndicatorBehavior:AddContextMenu(rootDescription, attachment)
    local builders = {
        unit = AddUnitMenu,
        boss = AddBossMenu,
        party = AddPartyMenu,
        raid = AddRaidMenu,
    }
    local builder = builders[attachment.options.kind]
    if builder then builder(rootDescription, attachment) end
end
