local _, PF = ...

local GroupConnectorBehavior = {
    autoAttach = { groupFrame = true },
}
PF.GroupConnectorBehavior = PF.FrameBehaviors:Register(
    "groupConnectors", GroupConnectorBehavior
)

function GroupConnectorBehavior:ValidateAttachment(_, options)
    assert(options.kind == "party" or options.kind == "raid" or options.kind == "boss",
        "group connector behavior requires a party, raid, or boss kind")
    assert(type(options.getPairs) == "function",
        "group connector behavior requires getPairs")
    assert(type(options.initializeConnector) == "function",
        "group connector behavior requires initializeConnector")
    assert(type(options.getVisibility) == "function",
        "group connector behavior requires getVisibility")
    assert(type(options.namePrefix) == "string" and options.namePrefix ~= "",
        "group connector behavior requires namePrefix")
    assert(type(options.storageKey) == "string" and options.storageKey ~= "",
        "group connector behavior requires storageKey")
end

function GroupConnectorBehavior:ConfigureAttachment(attachment)
    attachment.deferredApplyKey = attachment.deferredApplyKey or {}
    attachment.deferredRelinkKey = attachment.deferredRelinkKey or {}
    attachment.deferredSyncKey = attachment.deferredSyncKey or {}
    attachment.visibilityHooks = attachment.visibilityHooks or setmetatable({}, { __mode = "k" })
end

function GroupConnectorBehavior:AssignConnector(connector, upper, lower)
    UnregisterUnitWatch(connector)
    connector:SetParent(upper)
    connector:SetAttribute("unit", lower.unit)
    connector.upperFrame = upper
    connector.lowerFrame = lower
end

function GroupConnectorBehavior:InstallVisibilityHook(attachment, frame)
    if attachment.visibilityHooks[frame] then return end
    local previous = frame.OnVisibilityApplied
    local hook = function(widget, ...)
        if previous then previous(widget, ...) end
        if not attachment.detached then
            GroupConnectorBehavior:Refresh(attachment)
        end
    end
    attachment.visibilityHooks[frame] = { previous = previous, hook = hook }
    frame.OnVisibilityApplied = hook
end

function GroupConnectorBehavior:InstallVisibilityHooks(attachment)
    for frame in pairs(attachment.frames or {}) do
        self:InstallVisibilityHook(attachment, frame)
    end
end

function GroupConnectorBehavior:OnFrameAttached(attachment, frame)
    self:InstallVisibilityHook(attachment, frame)
    return true
end

function GroupConnectorBehavior:OnFrameDetached(attachment, frame)
    local registration = attachment.visibilityHooks[frame]
    if not registration then return end
    if frame.OnVisibilityApplied == registration.hook then
        frame.OnVisibilityApplied = registration.previous
    end
    attachment.visibilityHooks[frame] = nil
end

function GroupConnectorBehavior:Build(attachment)
    local subject = attachment.subject
    local options = attachment.options
    local connectors = subject[options.storageKey]
    if connectors then
        attachment.connectors = connectors
        self:InstallVisibilityHooks(attachment)
        return connectors
    end

    connectors = {}
    for index, pair in ipairs(options.getPairs()) do
        local connector = CreateFrame(
            "Button", options.namePrefix .. index, pair.upper,
            "SecureUnitButtonTemplate"
        )
        connector:EnableMouse(false)
        self:AssignConnector(connector, pair.upper, pair.lower)
        options.initializeConnector(connector, pair, index)
        connectors[index] = connector
    end
    subject[options.storageKey] = connectors
    attachment.connectors = connectors
    self:InstallVisibilityHooks(attachment)
    return connectors
end

function GroupConnectorBehavior:ApplyVisibility(attachment)
    local options = attachment.options
    local visibility = options.getVisibility() or "auto"
    local editing = PF.db and not PF.db.locked
    local enabled = not options.isEnabled or options.isEnabled() == true
    local previewHidden = options.previewHiddenWhileEditing ~= false

    for _, connector in ipairs(attachment.connectors or {}) do
        UnregisterUnitWatch(connector)
        connector:SetAlpha(1)
        local connectorEnabled = enabled and (
            not options.isConnectorEnabled
            or options.isConnectorEnabled(connector) == true
        )
        if not connectorEnabled then
            connector:Hide()
        elseif editing and previewHidden then
            connector:SetAlpha(visibility == "hide" and 0.5 or 1)
            connector:Show()
        elseif visibility == "hide" then
            connector:Hide()
        elseif editing or PF.testMode or visibility == "show" then
            connector:Show()
        else
            RegisterUnitWatch(connector)
        end
    end
end

function GroupConnectorBehavior:Apply(attachment)
    if not attachment then return end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredApplyKey,
        function()
            self:Build(attachment)
            self:ApplyVisibility(attachment)
            return true
        end,
        attachment
    )
end

function GroupConnectorBehavior:OnAttached(attachment)
    self:Refresh(attachment)
end

function GroupConnectorBehavior:OnEditModeChanged()
    self:RefreshAll()
end

function GroupConnectorBehavior:Relink(subject, pairs, arrange)
    local attachment = self:GetAttachment(subject)
    if not attachment then return false end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredRelinkKey,
        function()
            local connectors = self:Build(attachment)
            for index, pair in ipairs(pairs) do
                local connector = connectors[index]
                if connector then
                    self:AssignConnector(connector, pair.upper, pair.lower)
                    if arrange then arrange(connector, pair, index) end
                end
            end
            self:ApplyVisibility(attachment)
            return true
        end,
        attachment
    )
end

function GroupConnectorBehavior:SyncUnits(subject)
    local attachment = self:GetAttachment(subject)
    if not attachment then return false end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredSyncKey,
        function()
            for _, connector in ipairs(self:Build(attachment)) do
                UnregisterUnitWatch(connector)
                connector:SetAttribute("unit", connector.lowerFrame.unit)
            end
            self:ApplyVisibility(attachment)
            return true
        end,
        attachment
    )
end

function GroupConnectorBehavior:OnDetaching(attachment)
    local subject = attachment.subject
    local function Cleanup()
        -- A rapid detach/reattach reuses the named secure connectors. Do not
        -- let an older deferred teardown hide the new attachment's frames.
        local current = GroupConnectorBehavior:GetAttachment(subject)
        if current and current ~= attachment then return true end
        for _, connector in ipairs(attachment.connectors or {}) do
            UnregisterUnitWatch(connector)
            connector:Hide()
        end
        return true
    end
    if InCombatLockdown() then
        PF.FrameBehaviors:RunOutOfCombat(self, {}, Cleanup)
    else
        Cleanup()
    end
end

local function RefreshGroup(key)
    local subject = PF.frames and PF.frames[key]
    return subject and GroupConnectorBehavior:RefreshSubject(subject)
end

function PF:UpdatePartyConnectors() return RefreshGroup("party") end
function PF:UpdateRaidConnectors() return RefreshGroup("raid") end
function PF:UpdateBossConnectors() return RefreshGroup("boss") end
