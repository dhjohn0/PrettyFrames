local _, PF = ...

local usageSets = {
    party = {
        { key = "useInSmallRaid", label = "Use in Small Raids" },
        { key = "hideInRaid", label = "Hide in Raid Groups" },
    },
    raid = {
        { key = "useInParty", label = "Use in Parties" },
    },
}

local GroupUsageBehavior = {
    autoAttach = { groupFrame = true },
    contextMenuScope = "move",
    contextMenuOrder = 60,
    contextMenuGroup = { key = "groupUsage", title = "Group Usage" },
}
PF.GroupUsageBehavior = PF.FrameBehaviors:Register("groupUsage", GroupUsageBehavior)

function GroupUsageBehavior:ValidateAttachment(_, options)
    assert(usageSets[options.kind],
        "unknown group usage kind: " .. tostring(options.kind))
    assert(type(options.getOptions) == "function",
        "group usage behavior requires getOptions")
    assert(type(options.apply) == "function",
        "group usage behavior requires apply")
end

function GroupUsageBehavior:ConfigureAttachment(attachment)
    attachment.deferredApplyKey = attachment.deferredApplyKey or {}
    attachment.deferredSettingKeys = attachment.deferredSettingKeys or {}
    for _, entry in ipairs(usageSets[attachment.options.kind]) do
        attachment.deferredSettingKeys[entry.key]
            = attachment.deferredSettingKeys[entry.key] or {}
    end
end

function GroupUsageBehavior:Apply(attachment)
    if not attachment then return end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredApplyKey,
        function() return attachment.options.apply() end
    )
end

function GroupUsageBehavior:SetEnabled(attachment, key, enabled)
    local options = attachment and attachment.options.getOptions()
    if not options or options[key] == enabled then return false end

    if InCombatLockdown() then
        PF:Print("group usage changes will apply after combat.")
    end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredSettingKeys[key],
        function()
            local currentOptions = attachment.options.getOptions()
            if not currentOptions then return false end
            currentOptions[key] = enabled
            return attachment.options.apply()
        end,
        attachment
    )
end

function GroupUsageBehavior:AddContextMenu(rootDescription, attachment)
    local options = attachment.options.getOptions()
    if not options then return end
    for _, entry in ipairs(usageSets[attachment.options.kind]) do
        local key = entry.key
        rootDescription:CreateCheckbox(entry.label, function()
            return options[key] == true
        end, function()
            self:SetEnabled(attachment, key, options[key] ~= true)
        end)
    end
end
