local _, PF = ...

local UnitIndicatorBehavior = {
    autoAttach = { groupFrame = true },
    refreshOnAttach = true,
    contextMenuScope = "move",
    contextMenuOrder = 88,
    contextMenuGroup = { key = "unitIndicators", title = "Unit Indicators" },
}
PF.UnitIndicatorBehavior = PF.FrameBehaviors:Register(
    "unitIndicators", UnitIndicatorBehavior
)

function UnitIndicatorBehavior:ValidateAttachment(_, options)
    assert(options.kind == "party" or options.kind == "raid",
        "unit indicator behavior requires a party or raid kind")
    assert(type(options.getOptions) == "function",
        "unit indicator behavior requires getOptions")
end

local function ReadBoolean(value)
    return PF:IsDisplaySafe(value) and value == true
end

function UnitIndicatorBehavior:GetPreviewState(kind, index)
    local state = {}
    if kind == "raid" then
        state.role = ({ [1] = "TANK", [2] = "HEALER" })[index]
        state.leadership = index == 3 and "leader"
            or (index == 4 and "assistant" or nil)
        state.marker = index == 5 and 8 or (index == 6 and 1 or nil)
        state.isTarget = index == 7
        state.status = index == 17 and "AFK"
            or (index == 18 and "OFFLINE"
            or (index == 20 and "DEAD" or ""))
        state.dead = index == 20
    else
        state.role = ({ "TANK", "HEALER", "DAMAGER", "DAMAGER" })[index]
        state.leadership = index == 1 and "leader"
            or (index == 2 and "assistant" or nil)
        state.marker = index == 1 and 8 or (index == 3 and 1 or nil)
        state.isTarget = index == 4
        state.status = index == 2 and "OFFLINE"
            or (index == 3 and "AFK"
            or (index == 4 and "DEAD" or ""))
        state.dead = index == 4
    end
    return state
end

function UnitIndicatorBehavior:GetLiveState(frame)
    local unit = frame.unit
    local exists = UnitExists(unit)
    if not ReadBoolean(exists) then return { status = "" } end

    local connected = UnitIsConnected(unit)
    local dead = UnitIsDeadOrGhost(unit)
    local afk = UnitIsAFK and UnitIsAFK(unit)
    local state = {
        dead = ReadBoolean(dead),
        role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit),
        marker = GetRaidTargetIndex and GetRaidTargetIndex(unit),
        isTarget = ReadBoolean(UnitIsUnit and UnitIsUnit(unit, "target")),
    }
    if ReadBoolean(UnitIsGroupLeader and UnitIsGroupLeader(unit)) then
        state.leadership = "leader"
    elseif ReadBoolean(UnitIsGroupAssistant and UnitIsGroupAssistant(unit)) then
        state.leadership = "assistant"
    end

    if PF:IsDisplaySafe(connected) and connected == false then
        state.status = "OFFLINE"
    elseif state.dead then
        local ghost = UnitIsGhost(unit)
        state.status = ReadBoolean(ghost) and "GHOST" or "DEAD"
    elseif ReadBoolean(afk) then
        state.status = "AFK"
    else
        state.status = ""
    end
    if not PF:IsDisplaySafe(state.role) then state.role = nil end
    return state
end

local function SetStatusText(frame, options, text)
    if options.setStatusText then
        options.setStatusText(frame, text)
    elseif frame.statusText then
        frame.statusText:SetText(text)
    end
end

local function SetRole(frame, role, shown)
    local indicator = frame.unitRoleIndicator
    if not indicator then return end
    PF.Widgets.SetPartyRole(indicator, shown and role or "NONE")
    indicator:SetShown(shown == true)
end

local function SetLeadership(frame, leadership)
    local indicator = frame.unitLeadershipIndicator
    if not indicator then return end
    if leadership == "leader" then
        indicator:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
        indicator:Show()
    elseif leadership == "assistant" then
        indicator:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
        indicator:Show()
    else
        indicator:Hide()
    end
end

function UnitIndicatorBehavior:UpdateFrame(frame, attachment)
    attachment = attachment or self:GetAttachment(frame)
    if not attachment or not frame then return end
    local options = attachment.options
    local settings = options.getOptions()
    if not settings then return end

    local index = tonumber(frame.unit and frame.unit:match("%d+")) or 1
    local previewLimit = options.kind == "raid" and 22 or 4
    local preview = PF.testMode == true and index <= previewLimit
    local state = preview and self:GetPreviewState(options.kind, index)
        or self:GetLiveState(frame)

    SetStatusText(
        frame, options,
        settings.showStatusText ~= false and state.status or ""
    )
    if state.dead and frame.health then
        frame.health:SetStatusBarColor(unpack(PF.colors.dead))
    end

    local roleShown = settings.showRoleIcons ~= false and state.role ~= nil
        and state.role ~= "NONE"
        and (options.showDamageRole ~= false or state.role ~= "DAMAGER")
    SetRole(frame, state.role, roleShown)
    SetLeadership(
        frame,
        settings.showLeadership ~= false and state.leadership or nil
    )
    if frame.unitTargetHighlight then
        frame.unitTargetHighlight:SetShown(
            settings.showTargetHighlight ~= false and state.isTarget == true
        )
    end
    if frame.unitRaidMarker then
        local marker = state.marker
        if settings.showRaidMarkers == false then marker = nil end
        PF.Widgets.SetRaidMarkerTexture(
            frame.unitRaidMarker,
            marker
        )
    end
    state.roleShown = roleShown
    if options.afterApply then options.afterApply(frame, state) end
end

function UnitIndicatorBehavior:RefreshFrame(frame)
    local attachment = self:GetAttachment(frame)
    if attachment then self:UpdateFrame(frame, attachment) end
end

function UnitIndicatorBehavior:Apply(attachment)
    if not attachment then return end
    self:SyncFrames(attachment)
    for frame in pairs(attachment.frames or {}) do
        self:UpdateFrame(frame, attachment)
    end
end

function UnitIndicatorBehavior:AddContextMenu(rootDescription, attachment)
    local settings = attachment.options.getOptions()
    local function AddToggle(label, key)
        rootDescription:CreateCheckbox(label, function()
            return settings[key] ~= false
        end, function()
            settings[key] = settings[key] == false
            if PF.DisplayProfileBehavior then
                PF.DisplayProfileBehavior:MarkCustom(attachment.subject)
            end
            self:Refresh(attachment)
        end)
    end
    AddToggle("Status Text", "showStatusText")
    AddToggle("Role Icons", "showRoleIcons")
    AddToggle("Leadership Icons", "showLeadership")
    AddToggle("Target Highlight", "showTargetHighlight")
    AddToggle("Raid Markers", "showRaidMarkers")
end
