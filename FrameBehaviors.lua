local _, PF = ...

local FrameBehaviors = {
    behaviors = {},
    orderedBehaviors = {},
    deferred = {},
    deferredByBehavior = setmetatable({}, { __mode = "k" }),
    deferredOwners = setmetatable({}, { __mode = "k" }),
    groupAttachments = setmetatable({}, { __mode = "k" }),
}
PF.FrameBehaviors = FrameBehaviors

local function DefaultFrames(subject)
    return { subject }
end

local function DefaultSyncFrames(behavior, attachment)
    local frames = attachment.options.getFrames()
    if type(frames) ~= "table" then frames = {} end
    local previousFrames = attachment.frames or setmetatable({}, { __mode = "k" })
    local nextFrames = setmetatable({}, { __mode = "k" })
    local attachedFrames = {}
    for _, frame in ipairs(frames) do
        if frame and not nextFrames[frame] then
            local previousOwner = behavior.frameAttachments[frame]
            if previousOwner and previousOwner ~= attachment then
                if previousOwner.frames then previousOwner.frames[frame] = nil end
                if behavior.OnFrameDetached then
                    behavior:OnFrameDetached(previousOwner, frame, "reassigned")
                end
            end
            local attach = previousFrames[frame] == true
                or not behavior.OnFrameAttached
                or behavior:OnFrameAttached(attachment, frame) ~= false
            if attach then
                behavior.frameAttachments[frame] = attachment
                nextFrames[frame] = true
                table.insert(attachedFrames, frame)
            end
        end
    end
    for frame in pairs(previousFrames) do
        if not nextFrames[frame] then
            if behavior.frameAttachments[frame] == attachment then
                behavior.frameAttachments[frame] = nil
            end
            if behavior.OnFrameDetached then
                behavior:OnFrameDetached(attachment, frame, "removed")
            end
        end
    end
    attachment.frames = nextFrames
    return attachedFrames
end

local function DefaultAttach(behavior, subject, options)
    assert(subject, behavior.name .. " behavior subject is required")
    if behavior.ValidateAttachment then behavior:ValidateAttachment(subject, options) end
    if type(options.getFrames) ~= "function" then
        options.getFrames = function() return DefaultFrames(subject) end
    end

    local attachment = behavior.subjectAttachments[subject]
    local isNew = attachment == nil
    if isNew then
        attachment = {
            behavior = behavior,
            subject = subject,
            options = options,
            frames = setmetatable({}, { __mode = "k" }),
        }
        behavior.subjectAttachments[subject] = attachment
        table.insert(behavior.attachments, attachment)
    else
        attachment.options = options
    end

    if behavior.ConfigureAttachment then
        behavior:ConfigureAttachment(attachment, isNew)
    end
    for key, value in pairs(attachment) do
        if type(key) == "string" and key:match("^deferred.*Key$")
            and type(value) == "table" then
            PF.FrameBehaviors.deferredOwners[value] = attachment
        end
    end
    behavior:SyncFrames(attachment)
    if behavior.OnAttached then behavior:OnAttached(attachment, isNew) end
    if behavior.refreshOnAttach then behavior:Refresh(attachment) end
    return attachment
end

local function DefaultDetach(behavior, subject, reason)
    local attachment = type(subject) == "table" and subject.behavior == behavior
        and subject or behavior.subjectAttachments[subject]
    if not attachment or attachment.detached then return false end

    PF.FrameBehaviors:CancelDeferred(attachment)
    for key, owner in pairs(PF.FrameBehaviors.deferredOwners) do
        if owner == attachment then PF.FrameBehaviors.deferredOwners[key] = nil end
    end
    if behavior.OnDetaching then behavior:OnDetaching(attachment, reason) end
    for frame in pairs(attachment.frames or {}) do
        if behavior.frameAttachments[frame] == attachment then
            behavior.frameAttachments[frame] = nil
        end
        if behavior.OnFrameDetached then
            behavior:OnFrameDetached(attachment, frame, reason or "detached")
        end
    end
    attachment.frames = setmetatable({}, { __mode = "k" })
    if behavior.subjectAttachments[attachment.subject] == attachment then
        behavior.subjectAttachments[attachment.subject] = nil
    end
    for index = #behavior.attachments, 1, -1 do
        if behavior.attachments[index] == attachment then
            table.remove(behavior.attachments, index)
            break
        end
    end
    attachment.detached = true
    if behavior.OnDetached then behavior:OnDetached(attachment, reason) end
    return true
end

local function DefaultGetAttachment(behavior, subject)
    return behavior.subjectAttachments[subject] or behavior.frameAttachments[subject]
end

local function DefaultRefreshSubject(behavior, subject)
    return behavior:Refresh(behavior:GetAttachment(subject))
end

local function DefaultRefreshAll(behavior)
    for _, attachment in ipairs(behavior.attachments) do
        behavior:Refresh(attachment)
    end
end

local function DefaultRefresh(behavior, attachment)
    if attachment and behavior.Apply then return behavior:Apply(attachment) end
end

local function DefaultHasCapability(behavior, attachment, name)
    if not attachment then return false end
    local localCapabilities = attachment.options.capabilities
    local value = type(localCapabilities) == "table" and localCapabilities[name]
    if value ~= nil then return value == true end
    local capabilities = behavior.capabilities
    if type(capabilities) == "function" then
        return capabilities(behavior, attachment, name) == true
    end
    return type(capabilities) == "table" and capabilities[name] == true
end

function FrameBehaviors:Register(name, behavior)
    assert(type(name) == "string" and name ~= "", "frame behavior name is required")
    assert(type(behavior) == "table", "frame behavior must be a table")
    assert(not self.behaviors[name], "frame behavior already registered: " .. name)

    behavior.name = name
    behavior.attachments = behavior.attachments or {}
    behavior.subjectAttachments = behavior.subjectAttachments
        or setmetatable({}, { __mode = "k" })
    behavior.frameAttachments = behavior.frameAttachments
        or setmetatable({}, { __mode = "k" })
    behavior.SyncFrames = behavior.SyncFrames or DefaultSyncFrames
    behavior.Attach = behavior.Attach or DefaultAttach
    behavior.Detach = behavior.Detach or DefaultDetach
    behavior.GetAttachment = behavior.GetAttachment or DefaultGetAttachment
    behavior.HasCapability = behavior.HasCapability or DefaultHasCapability
    behavior.RefreshSubject = behavior.RefreshSubject or DefaultRefreshSubject
    behavior.Refresh = behavior.Refresh or DefaultRefresh
    behavior.RefreshAll = behavior.RefreshAll or DefaultRefreshAll
    self.behaviors[name] = behavior
    table.insert(self.orderedBehaviors, behavior)
    return behavior
end

function FrameBehaviors:Get(name)
    return self.behaviors[name]
end

function FrameBehaviors:Attach(name, subject, options)
    local behavior = assert(self.behaviors[name], "unknown frame behavior: " .. tostring(name))
    return behavior:Attach(subject, options or {})
end

function FrameBehaviors:AttachDefaults(kind, subject, context)
    assert(type(kind) == "string" and kind ~= "", "attachment kind is required")
    if not subject then return end
    context = context or {}
    local attachments = {}
    for _, behavior in ipairs(self.orderedBehaviors) do
        local handlers = behavior.autoAttach
        local handler = type(handlers) == "table" and handlers[kind]
        local attachment
        if handler == true and kind == "groupFrame" then
            local configured = context.behaviors and context.behaviors[behavior.name]
            if configured then
                assert(configured == true or type(configured) == "table",
                    "group behavior options must be a table: " .. behavior.name)
                local options = {}
                if type(configured) == "table" then
                    for key, value in pairs(configured) do options[key] = value end
                end
                if options.kind == nil then options.kind = context.kind end
                if options.getFrames == nil then options.getFrames = context.getFrames end
                if options.getOptions == nil then options.getOptions = context.getOptions end
                if options.contextMenuScope == nil then
                    options.contextMenuScope = "move"
                end
                attachment = behavior:Attach(subject, options)
            end
        else
            if type(handler) == "string" then handler = behavior[handler] end
            if type(handler) == "function" then
                attachment = handler(
                    behavior, subject, context.settingKey, context
                )
            end
        end
        if attachment then attachments[behavior.name] = attachment end
    end
    return attachments
end

function FrameBehaviors:AttachGroup(subject, context)
    assert(subject, "group frame subject is required")
    assert(type(context) == "table", "group frame context is required")
    assert(context.kind == "party" or context.kind == "raid" or context.kind == "boss",
        "unknown group frame kind: " .. tostring(context.kind))
    assert(type(context.getFrames) == "function",
        "group frame attachment requires getFrames")
    assert(type(context.getOptions) == "function",
        "group frame attachment requires getOptions")
    assert(type(context.behaviors) == "table",
        "group frame attachment requires behaviors")

    local requested = {}
    for name, configured in pairs(context.behaviors) do
        if configured then
            local behavior = assert(self.behaviors[name],
                "unknown group frame behavior: " .. tostring(name))
            local handlers = behavior.autoAttach
            assert(type(handlers) == "table" and handlers.groupFrame == true,
                "behavior does not support group frames: " .. tostring(name))
            requested[name] = true
        end
    end

    local previous = self.groupAttachments[subject]
    if previous then
        for name in pairs(previous) do
            if not requested[name] then
                self.behaviors[name]:Detach(subject, "group behavior removed")
            end
        end
    end

    local attachments = self:AttachDefaults("groupFrame", subject, context)
    self.groupAttachments[subject] = requested
    return attachments
end

function FrameBehaviors:DetachGroup(subject, reason)
    local registered = self.groupAttachments[subject]
    if not registered then return false end
    local detached = false
    for name in pairs(registered) do
        detached = self.behaviors[name]:Detach(
            subject, reason or "group detached"
        ) or detached
    end
    self.groupAttachments[subject] = nil
    return detached
end

function FrameBehaviors:Detach(name, subject, reason)
    local behavior = assert(self.behaviors[name], "unknown frame behavior: " .. tostring(name))
    return behavior:Detach(subject, reason)
end

function FrameBehaviors:DetachAll(subject, reason)
    local detached = false
    for _, behavior in ipairs(self.orderedBehaviors) do
        if behavior.subjectAttachments[subject] then
            detached = behavior:Detach(subject, reason) or detached
        end
    end
    self.groupAttachments[subject] = nil
    return detached
end

function FrameBehaviors:RefreshFrame(frame)
    for _, behavior in ipairs(self.orderedBehaviors) do
        if behavior.RefreshFrame then behavior:RefreshFrame(frame) end
    end
end

function FrameBehaviors:RefreshAll()
    for _, behavior in ipairs(self.orderedBehaviors) do
        if behavior.RefreshAll then behavior:RefreshAll() end
    end
end

function FrameBehaviors:NotifyEditModeChanged(editing, testMode, reason)
    local state = {
        editing = editing == true,
        testMode = testMode == true,
        reason = reason,
    }
    for _, behavior in ipairs(self.orderedBehaviors) do
        if behavior.OnEditModeChanged then
            behavior:OnEditModeChanged(state)
        end
    end
end

function FrameBehaviors:Refresh(name, subject)
    local behavior = assert(self.behaviors[name], "unknown frame behavior: " .. tostring(name))
    return behavior:RefreshSubject(subject)
end

function FrameBehaviors:RunOutOfCombat(name, key, callback, owner)
    local behavior = type(name) == "table" and name or assert(
        self.behaviors[name], "unknown frame behavior: " .. tostring(name)
    )
    assert(type(callback) == "function", "deferred behavior callback is required")
    if not InCombatLockdown() then return callback() end
    owner = owner or self.deferredOwners[key]

    local behaviorEntries = self.deferredByBehavior[behavior]
    if not behaviorEntries then
        behaviorEntries = {}
        self.deferredByBehavior[behavior] = behaviorEntries
    end
    key = key or callback
    local entry = behaviorEntries[key]
    if entry then
        entry.callback = callback
        entry.owner = owner
        entry.cancelled = nil
    else
        entry = { behavior = behavior, key = key, callback = callback, owner = owner }
        behaviorEntries[key] = entry
        table.insert(self.deferred, entry)
    end
    return false
end


function FrameBehaviors:CancelDeferred(owner)
    if not owner then return false end
    local cancelled = false
    for _, entry in ipairs(self.deferred) do
        if entry.owner == owner then
            entry.cancelled = true
            local entries = self.deferredByBehavior[entry.behavior]
            if entries and entries[entry.key] == entry then entries[entry.key] = nil end
            cancelled = true
        end
    end
    return cancelled
end

function FrameBehaviors:FlushDeferred()
    if InCombatLockdown() or #self.deferred == 0 then return false end
    local pending = self.deferred
    self.deferred = {}
    self.deferredByBehavior = setmetatable({}, { __mode = "k" })
    for _, entry in ipairs(pending) do
        if not entry.cancelled and not (entry.owner and entry.owner.detached) then
            if geterrorhandler then
                xpcall(entry.callback, geterrorhandler())
            else
                entry.callback()
            end
        end
    end
    return true
end

local function UsesContextMenuLevel(behavior, attachment, level)
    local scope = attachment.options.contextMenuScope or behavior.contextMenuScope or "both"
    return scope == "both" or scope == level
end

local function ResolveContextMenuGroup(behavior, attachment)
    local group = attachment.options.contextMenuGroup or behavior.contextMenuGroup
    if type(group) == "function" then group = group(behavior, attachment) end
    if type(group) == "string" then return group, group end
    if type(group) == "table" then
        return group.key or group.id or group.title, group.title or group.label or group.key
    end
end

local function ResolveContextMenuOrder(behavior, attachment)
    local order = attachment.options.contextMenuOrder
    if order == nil then order = behavior.contextMenuOrder end
    if type(order) == "function" then order = order(behavior, attachment) end
    return type(order) == "number" and order or 1000
end

function FrameBehaviors:AddContextMenus(rootDescription, subject, level)
    level = level or "individual"
    local context = { groups = {} }
    function context:GetMenu(key, title)
        assert(type(key) == "string" and key ~= "", "context menu group key is required")
        local menu = self.groups[key]
        if not menu then
            menu = rootDescription:CreateButton(title or key)
            self.groups[key] = menu
        end
        return menu
    end

    local menuBehaviors = {}
    for index, behavior in ipairs(self.orderedBehaviors) do
        local attachment = behavior.GetAttachment and behavior:GetAttachment(subject)
        if attachment and behavior.AddContextMenu
            and UsesContextMenuLevel(behavior, attachment, level) then
            table.insert(menuBehaviors, {
                behavior = behavior,
                attachment = attachment,
                order = ResolveContextMenuOrder(behavior, attachment),
                registrationOrder = index,
            })
        end
    end
    table.sort(menuBehaviors, function(left, right)
        if left.order == right.order then
            return left.registrationOrder < right.registrationOrder
        end
        return left.order < right.order
    end)
    for _, entry in ipairs(menuBehaviors) do
        local key, title = ResolveContextMenuGroup(entry.behavior, entry.attachment)
        local menuRoot = key and context:GetMenu(key, title) or rootDescription
        entry.behavior:AddContextMenu(menuRoot, entry.attachment, context)
    end
    return context
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:SetScript("OnEvent", function()
    FrameBehaviors:FlushDeferred()
end)
driver:SetScript("OnUpdate", function(_, elapsed)
    for _, behavior in ipairs(FrameBehaviors.orderedBehaviors) do
        if behavior.OnUpdate then behavior:OnUpdate(elapsed) end
    end
end)
