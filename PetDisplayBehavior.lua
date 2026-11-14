local _, PF = ...

local PetDisplayBehavior = {
    autoAttach = { unitFrame = "AttachUnitFrame" },
    contextMenuScope = "move",
    contextMenuOrder = 80,
    contextMenuGroup = { key = "frameBehavior", title = "Frame Behavior" },
    refreshOnAttach = true,
}
PF.PetDisplayBehavior = PF.FrameBehaviors:Register("petDisplay", PetDisplayBehavior)

function PetDisplayBehavior:ValidateAttachment(_, options)
    local hasHappiness = type(options.applyHappiness) == "function"
    local hasPower = type(options.applyBarMode) == "function"
    assert(hasHappiness or hasPower,
        "pet display behavior requires a display capability")
    if hasHappiness then
        assert(type(options.getHappinessHidden) == "function",
            "pet display behavior requires getHappinessHidden")
        assert(type(options.setHappinessHidden) == "function",
            "pet display behavior requires setHappinessHidden")
    end
    if hasPower then
        assert(type(options.getBarMode) == "function",
            "pet display behavior requires getBarMode")
        assert(type(options.setBarMode) == "function",
            "pet display behavior requires setBarMode")
    end
end

function PetDisplayBehavior:ConfigureAttachment(attachment)
    attachment.deferredApplyKey = attachment.deferredApplyKey or {}
    attachment.deferredHappinessKey = attachment.deferredHappinessKey or {}
    attachment.deferredBarModeKey = attachment.deferredBarModeKey or {}
end

function PetDisplayBehavior:Apply(attachment)
    if not attachment then return end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredApplyKey,
        function()
            local options = attachment.options
            if options.applyHappiness then
                options.applyHappiness(not options.getHappinessHidden())
            end
            if options.applyBarMode then
                options.applyBarMode(options.getBarMode())
            end
            return true
        end
    )
end

function PetDisplayBehavior:SetHappinessHidden(attachment, hidden)
    local options = attachment and attachment.options
    if not options or not options.applyHappiness
        or options.getHappinessHidden() == hidden then return false end
    if InCombatLockdown() then
        PF:Print("pet happiness changes will apply after combat.")
    end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredHappinessKey,
        function()
            if options.getHappinessHidden() == hidden then return true end
            options.setHappinessHidden(hidden)
            options.applyHappiness(not hidden)
            return true
        end
    )
end

function PetDisplayBehavior:SetBarMode(attachment, mode)
    local options = attachment and attachment.options
    if not options or not options.applyBarMode
        or options.getBarMode() == mode then return false end
    if InCombatLockdown() then
        PF:Print("pet bar changes will apply after combat.")
    end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredBarModeKey,
        function()
            if options.getBarMode() == mode then return true end
            options.setBarMode(mode)
            options.applyBarMode(mode)
            return true
        end
    )
end

function PetDisplayBehavior:AddContextMenu(rootDescription, attachment)
    local options = attachment.options
    if options.applyHappiness then
        rootDescription:CreateCheckbox("Hide Pet Happiness", function()
            return options.getHappinessHidden() == true
        end, function()
            self:SetHappinessHidden(
                attachment, options.getHappinessHidden() ~= true
            )
        end)
    end
    if options.applyBarMode then
        rootDescription:CreateTitle("Pet Bars")
        rootDescription:CreateRadio("Health + Power", function(value)
            return options.getBarMode() == value
        end, function(value)
            self:SetBarMode(attachment, value)
        end, "healthPower")
        rootDescription:CreateRadio("Health Only", function(value)
            return options.getBarMode() == value
        end, function(value)
            self:SetBarMode(attachment, value)
        end, "healthOnly")
    end
end

function PetDisplayBehavior:AttachUnitFrame(frame, settingKey)
    if not frame or not settingKey then return end
    local hasHappiness = type(frame.SetPetHappinessShown) == "function"
    local hasPower = type(frame.SetPetPowerShown) == "function"
    if not hasHappiness and not hasPower then return end

    local options = {}
    if hasHappiness then
        options.getHappinessHidden = function()
            return PF:GetFrameSetting(settingKey).hidePetHappiness == true
        end
        options.setHappinessHidden = function(value)
            PF:GetFrameSetting(settingKey).hidePetHappiness = value == true
        end
        options.applyHappiness = function(shown)
            frame:SetPetHappinessShown(shown == true)
        end
    end
    if hasPower then
        options.getBarMode = function()
            return PF:GetFrameSetting(settingKey).petBarMode
        end
        options.setBarMode = function(value)
            PF:GetFrameSetting(settingKey).petBarMode = value == "healthOnly"
                and "healthOnly" or "healthPower"
        end
        options.applyBarMode = function(value)
            frame:SetPetPowerShown(value ~= "healthOnly")
        end
    end
    return PF.FrameBehaviors:Attach("petDisplay", frame, options)
end
