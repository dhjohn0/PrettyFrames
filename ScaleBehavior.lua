local _, PF = ...

local ScaleBehavior = {
    autoAttach = { unitFrame = "AttachUnitFrame", groupFrame = true },
    contextMenuOrder = 20,
    deferredGlobalKey = {},
}
PF.ScaleBehavior = PF.FrameBehaviors:Register("scale", ScaleBehavior)

function ScaleBehavior:ValidateAttachment(_, options)
    assert(type(options.getScale) == "function", "scale behavior requires getScale")
    assert(type(options.setScale) == "function", "scale behavior requires setScale")
end

function ScaleBehavior:AttachUnitFrame(frame, settingKey)
    if not frame or not settingKey then return end
    local isMember = settingKey:match("^party%d+$") or frame.isBossFrame
    return PF.FrameBehaviors:Attach("scale", frame, {
        contextMenuScope = isMember and "individual" or "move",
        getScale = function() return PF:GetFrameSetting(settingKey).scale or 1 end,
        setScale = function(value) PF:GetFrameSetting(settingKey).scale = value end,
        apply = function()
            PF:ApplyFrameScale(frame)
            if settingKey:match("^party%d+$") and PF.ApplyPartyGroupLayout then
                PF:ApplyPartyGroupLayout()
            elseif frame.isBossFrame and PF.ApplyBossGroupLayout then
                PF:ApplyBossGroupLayout()
            end
        end,
    })
end

function ScaleBehavior:ConfigureAttachment(attachment)
    attachment.deferredApplyKey = attachment.deferredApplyKey or {}
end

function ScaleBehavior:Apply(attachment)
    if not attachment or not attachment.options.apply then return end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredApplyKey,
        function() return attachment.options.apply() end,
        attachment
    )
end

function ScaleBehavior:ApplyFrame(frame)
    if not frame then return end
    local attachment = self:GetAttachment(frame)
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        frame,
        function() return PF:PerformFrameScale(frame) end,
        attachment
    )
end

function ScaleBehavior:RefreshGlobal()
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        self.deferredGlobalKey,
        function() return PF:PerformScaleRefresh() end
    )
end

function ScaleBehavior:AddContextMenu(rootDescription, attachment)
    rootDescription:CreateTitle("Scale")
    PF:AddMenuSlider(
        rootDescription,
        math.floor((attachment.options.getScale() or 1) * 100 + 0.5),
        60,
        160,
        function(value)
            attachment.options.setScale(value / 100)
            self:Refresh(attachment)
        end,
        20,
        function(value) return value .. "%" end
    )
end
