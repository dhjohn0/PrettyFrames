local _, PF = ...

local VisibilityBehavior = {
    autoAttach = { unitFrame = "AttachUnitFrame", groupFrame = true },
    contextMenuOrder = 30,
    deferredGroupStateKey = {},
}
PF.VisibilityBehavior = PF.FrameBehaviors:Register("visibility", VisibilityBehavior)

function VisibilityBehavior:ValidateAttachment(_, options)
    assert(type(options.getVisibility) == "function",
        "visibility behavior requires getVisibility")
    assert(type(options.setVisibility) == "function",
        "visibility behavior requires setVisibility")
    if options.getStateVisibility then
        assert(options.kind == "party" or options.kind == "raid",
            "group state visibility requires a party or raid kind")
        assert(type(options.getStateVisibility) == "function",
            "group state visibility requires getStateVisibility")
        assert(type(options.isEnabled) == "function",
            "group state visibility requires isEnabled")
    end
end

function VisibilityBehavior:AttachUnitFrame(frame, settingKey)
    if not frame or not settingKey then return end
    if settingKey:match("^party%d+$") or frame.isBossFrame then return end
    return PF.FrameBehaviors:Attach("visibility", frame, {
        contextMenuScope = "move",
        getVisibility = function()
            return PF:GetFrameSetting(settingKey).visibility or "auto"
        end,
        setVisibility = function(value)
            PF:GetFrameSetting(settingKey).visibility = value
        end,
        apply = function()
            PF:ApplyFrameVisibility(frame)
            if frame.isBossGroup then
                for _, bossFrame in ipairs(frame.bossFrames or {}) do
                    PF:UpdateUnitFrame(bossFrame, true)
                end
            else
                PF:UpdateUnitFrame(frame, true)
            end
        end,
    })
end

function VisibilityBehavior:ConfigureAttachment(attachment)
    attachment.deferredApplyKey = attachment.deferredApplyKey or {}
end

function VisibilityBehavior:Apply(attachment)
    if not attachment then return end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredApplyKey,
        function()
            local result
            if attachment.options.apply then
                result = attachment.options.apply()
            end
            if attachment.options.getStateVisibility then
                self:ApplyGroupStateDrivers()
            end
            return result
        end,
        attachment
    )
end

function VisibilityBehavior:ApplyFrame(frame)
    if not frame then return end
    if frame.isBossGroup or frame.isBossFrame then
        return PF:ApplyBossFramesVisibility()
    end
    local attachment = self:GetAttachment(frame)
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        frame,
        function() return PF:PerformFrameVisibility(frame) end,
        attachment
    )
end

function VisibilityBehavior:ApplyGroupStateDrivers()
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        self.deferredGroupStateKey,
        function()
            local editing = PF.testMode or (PF.db and not PF.db.locked)
            for _, attachment in ipairs(self.attachments) do
                local options = attachment.options
                if not attachment.detached and options.getStateVisibility then
                    UnregisterStateDriver(attachment.subject, "visibility")
                    local enabled = options.isEnabled() == true
                    if editing then
                        attachment.subject:SetShown(enabled)
                    else
                        local state = enabled and (
                            options.getStateDriver and options.getStateDriver()
                                or options.getStateVisibility()
                        ) or "hide"
                        RegisterStateDriver(
                            attachment.subject, "visibility",
                            type(state) == "string" and state or "hide"
                        )
                    end
                end
            end
            return true
        end
    )
end

function VisibilityBehavior:OnAttached(attachment)
    if attachment.options.getStateVisibility then
        self:ApplyGroupStateDrivers()
    end
end

function VisibilityBehavior:OnDetaching(attachment)
    if not attachment.options.getStateVisibility then return end
    local subject = attachment.subject
    local function Cleanup()
        local current = VisibilityBehavior:GetAttachment(subject)
        if current and current ~= attachment then return true end
        UnregisterStateDriver(subject, "visibility")
        subject:Hide()
        return true
    end
    if InCombatLockdown() then
        PF.FrameBehaviors:RunOutOfCombat(self, {}, Cleanup)
    else
        Cleanup()
    end
end

function VisibilityBehavior:OnEditModeChanged()
    self:RefreshAll()
    self:ApplyGroupStateDrivers()
end

function VisibilityBehavior:AddContextMenu(rootDescription, attachment)
    local menu = rootDescription:CreateButton("Visibility")
    local function IsSelected(value)
        return attachment.options.getVisibility() == value
    end
    local function SetSelected(value)
        attachment.options.setVisibility(value)
        self:Refresh(attachment)
    end
    menu:CreateRadio("Automatic", IsSelected, SetSelected, "auto")
    menu:CreateRadio("Always Show", IsSelected, SetSelected, "show")
    menu:CreateRadio("Always Hide", IsSelected, SetSelected, "hide")
end

function PF:ApplyGroupStateDrivers()
    return VisibilityBehavior:ApplyGroupStateDrivers()
end


function PF:ApplyBossFramesVisibility()
    local subject = PF.frames and PF.frames.boss
    return subject and VisibilityBehavior:RefreshSubject(subject)
end
