local _, PF = ...

local FlipBehavior = {
    autoAttach = { unitFrame = "AttachUnitFrame" },
    contextMenuOrder = 70,
    contextMenuGroup = { key = "layout", title = "Layout" },
    refreshOnAttach = true,
}
PF.FlipBehavior = PF.FrameBehaviors:Register("flip", FlipBehavior)

function FlipBehavior:ValidateAttachment(_, options)
    assert(type(options.getFlipped) == "function",
        "flip behavior requires getFlipped")
    assert(type(options.setFlipped) == "function",
        "flip behavior requires setFlipped")
    assert(type(options.apply) == "function",
        "flip behavior requires apply")
end

function FlipBehavior:ConfigureAttachment(attachment)
    attachment.deferredApplyKey = attachment.deferredApplyKey or {}
    attachment.deferredChangeKey = attachment.deferredChangeKey or {}
end

function FlipBehavior:Apply(attachment)
    if not attachment then return end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredApplyKey,
        function()
            return attachment.options.apply(attachment.options.getFlipped())
        end
    )
end

function FlipBehavior:SetFlipped(attachment, flipped)
    if not attachment or attachment.options.getFlipped() == flipped then return false end
    if InCombatLockdown() then PF:Print("frame flipping will apply after combat.") end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredChangeKey,
        function()
            if attachment.options.getFlipped() == flipped then return true end
            attachment.options.setFlipped(flipped)
            local result = attachment.options.apply(flipped)
            if attachment.options.afterChange then attachment.options.afterChange(flipped) end
            return result
        end
    )
end

function FlipBehavior:AddContextMenu(rootDescription, attachment)
    rootDescription:CreateCheckbox("Flip Horizontally", function()
        return attachment.options.getFlipped() == true
    end, function()
        self:SetFlipped(attachment, attachment.options.getFlipped() ~= true)
    end)
end

function FlipBehavior:AttachUnitFrame(frame, settingKey)
    if not frame or not frame.SetFlipped or not settingKey then return end
    local isMember = settingKey:match("^party%d+$") or frame.isBossFrame
    return PF.FrameBehaviors:Attach("flip", frame, {
        contextMenuScope = isMember and "individual" or "move",
        getFlipped = function()
            return PF:GetFrameSetting(settingKey).flipped == true
        end,
        setFlipped = function(value)
            PF:GetFrameSetting(settingKey).flipped = value == true
        end,
        apply = function(value) return frame:SetFlipped(value == true) end,
        afterChange = function()
            if settingKey == "target" and PF.UpdateClassResourceDisplay then
                PF:UpdateClassResourceDisplay(true)
            end
            if frame.isBossFrame and PF.ApplyBossGroupLayout then
                PF:ApplyBossGroupLayout()
            end
        end,
    })
end

function PF:ApplyFrameFlip(frame)
    if not self.FlipBehavior then return end
    return self.FlipBehavior:RefreshSubject(frame)
end

function PF:SetFrameFlipped(frame, flipped)
    if not self.FlipBehavior then return false end
    return self.FlipBehavior:SetFlipped(
        self.FlipBehavior:GetAttachment(frame), flipped == true
    )
end
