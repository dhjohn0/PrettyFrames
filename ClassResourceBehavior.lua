local _, PF = ...

local ClassResourceBehavior = {
    autoAttach = { unitFrame = "AttachUnitFrame" },
    contextMenuScope = "move",
    contextMenuOrder = 80,
    contextMenuGroup = { key = "frameBehavior", title = "Frame Behavior" },
}
PF.ClassResourceBehavior = PF.FrameBehaviors:Register(
    "classResource", ClassResourceBehavior
)

function ClassResourceBehavior:ValidateAttachment(_, options)
    assert(type(options.getVisibility) == "function",
        "class resource behavior requires getVisibility")
    assert(type(options.setVisibility) == "function",
        "class resource behavior requires setVisibility")
    assert(type(options.apply) == "function",
        "class resource behavior requires apply")
end

function ClassResourceBehavior:ConfigureAttachment(attachment)
    attachment.deferredApplyKey = attachment.deferredApplyKey or {}
    attachment.deferredChangeKey = attachment.deferredChangeKey or {}
end

function ClassResourceBehavior:Apply(attachment)
    if not attachment then return end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredApplyKey,
        function() return attachment.options.apply() end
    )
end

function ClassResourceBehavior:SetVisibility(attachment, visibility)
    if visibility ~= "hidden" then visibility = "automatic" end
    if not attachment
        or attachment.options.getVisibility() == visibility then return false end
    if InCombatLockdown() then
        PF:Print("class resource visibility changes will apply after combat.")
    end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredChangeKey,
        function()
            if attachment.options.getVisibility() == visibility then return true end
            attachment.options.setVisibility(visibility)
            return attachment.options.apply()
        end
    )
end

function ClassResourceBehavior:AddContextMenu(rootDescription, attachment)
    rootDescription:CreateTitle("Class Resource")
    local function IsSelected(value)
        return attachment.options.getVisibility() == value
    end
    local function SetSelected(value)
        self:SetVisibility(attachment, value)
    end
    rootDescription:CreateRadio("Automatic", IsSelected, SetSelected, "automatic")
    rootDescription:CreateRadio("Hidden", IsSelected, SetSelected, "hidden")
end

function ClassResourceBehavior:AttachUnitFrame(frame, settingKey)
    if not frame or settingKey ~= "player"
        or type(PF.UpdateClassResourceDisplay) ~= "function" then return end
    return PF.FrameBehaviors:Attach("classResource", frame, {
        getVisibility = function()
            return PF:GetFrameSetting("player").classResourceVisibility
        end,
        setVisibility = function(value)
            PF:GetFrameSetting("player").classResourceVisibility = value
        end,
        apply = function() return PF:UpdateClassResourceDisplay(true) end,
    })
end

function ClassResourceBehavior:OnEditModeChanged()
    self:RefreshAll()
end
