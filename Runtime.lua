local addonName, PF = ...

function PF:SetLocked(locked, silent)
    if InCombatLockdown() then
        self:Print("frame locking cannot change during combat.")
        return false
    end
    self.db.locked = locked
    if locked and self.actionsWindow then self.actionsWindow:Hide() end
    if self.ApplyGroupStateDrivers then
        self:ApplyGroupStateDrivers()
    end
    for _, frame in pairs(self.frames) do
        if frame.moveLabel then
            frame.moveLabel:SetShown(not locked)
        end
        if frame.moveHandle then
            frame.moveHandle:SetShown(not locked)
        end
    end
    if self.ApplyAllActionBindings then self:ApplyAllActionBindings() end
    for _, castBar in ipairs(self.castBars or {}) do
        castBar:EnableMouse(not locked)
        if castBar.preview then
            castBar.preview:EnableMouse(not locked)
        end
    end
    for _, display in ipairs(self.classResourceDisplays or {}) do
        if display.bar then display.bar:EnableMouse(not locked) end
    end
    for _, frame in ipairs(self.configurableFrames) do
        self:ApplyFrameVisibility(frame)
    end
    -- Unlocking previews every Party slot, while locking returns to the live
    -- roster. Rebuild the layout before updating connectors so the move handle
    -- and first/last vine crops use the new preview population immediately.
    if self.ApplyPartyGroupLayout then
        self:ApplyPartyGroupLayout()
    end
    if self.RefreshCastBarPreviews then
        self:RefreshCastBarPreviews()
    end
    if self.ApplyRaidGroupLayout then
        self:ApplyRaidGroupLayout()
    end
    if self.ApplyBossGroupLayout then
        self:ApplyBossGroupLayout()
    end
    if self.UpdatePartyConnectors then
        self:UpdatePartyConnectors()
    end
    if self.UpdateRaidConnectors then
        self:UpdateRaidConnectors()
    end
    if self.RefreshAllFrames then
        self:RefreshAllFrames()
    end
    if self.RefreshPartyRangeStates then
        self:RefreshPartyRangeStates()
    end
    if not silent then
        self:Print(locked and "frames locked." or "frames unlocked; drag to move or right-click a frame for display options.")
    end
    return true
end

function PF:ApplyGroupStateDrivers()
    local party = self.frames.party
    local raid = self.frames.raid
    if not party or not raid then return end
    if InCombatLockdown() then
        self.pendingGroupStateDrivers = true
        return false
    end

    UnregisterStateDriver(party, "visibility")
    UnregisterStateDriver(raid, "visibility")

    local partyEnabled = self.db.replacePartyFrames ~= false
    local raidEnabled = self.db.replaceRaidFrames ~= false

    -- Keep both groups available while arranging or previewing. Individual
    -- Always Hide settings still control their child unit frames.
    if self.testMode or not self.db.locked then
        party:SetShown(partyEnabled)
        raid:SetShown(raidEnabled)
        self.pendingGroupStateDrivers = nil
        return true
    end

    local options = self.db.raidLayout
    local inGroup = IsInGroup and IsInGroup()
    local inRaid = IsInRaid and IsInRaid()
    local useSmallRaidParty = self.ShouldUsePartyFramesForSmallRaid
        and self:ShouldUsePartyFramesForSmallRaid()
    local showParty
    if inRaid then
        showParty = useSmallRaidParty or self.db.partyLayout.hideInRaid ~= true
    else
        showParty = not (options.useInParty and inGroup)
    end
    RegisterStateDriver(party, "visibility", partyEnabled and showParty and "show" or "hide")

    if not raidEnabled then
        RegisterStateDriver(raid, "visibility", "hide")
    elseif options.visibility == "show" then
        RegisterStateDriver(raid, "visibility", "show")
    elseif options.visibility == "hide" then
        RegisterStateDriver(raid, "visibility", "hide")
    else
        local showRaid = (inRaid and not useSmallRaidParty)
            or (not inRaid and options.useInParty and inGroup)
        RegisterStateDriver(raid, "visibility", showRaid and "show" or "hide")
    end

    self.pendingGroupStateDrivers = nil
    return true
end

function PF:SuppressBlizzardFrames()
    if self.db.replaceUnitFrames == false
        and self.db.replaceBossFrames == false
        and self.db.replacePartyFrames == false
        and self.db.replaceRaidFrames == false then
        return
    end
    if InCombatLockdown() then
        self.pendingBlizzardSuppression = true
        return false
    end

    local frameGroups = {
        unit = {
            enabled = function() return PF.db and PF.db.replaceUnitFrames ~= false end,
            names = {
                "PlayerFrame", "TargetFrame", "FocusFrame",
                "PlayerCastingBarFrame", "OverlayPlayerCastingBarFrame", "CastingBarFrame",
            },
        },
        boss = {
            enabled = function()
                return PF.db and PF.db.replaceBossFrames == true
                    and PF.frames and PF.frames.boss and PF.frames.boss.initialized == true
            end,
            names = {
                "BossTargetFrameContainer", "Boss1TargetFrame", "Boss2TargetFrame",
                "Boss3TargetFrame", "Boss4TargetFrame", "Boss5TargetFrame",
            },
        },
        party = {
            enabled = function() return PF.db and PF.db.replacePartyFrames ~= false end,
            names = { "PartyFrame", "CompactPartyFrame" },
        },
        raid = {
            enabled = function() return PF.db and PF.db.replaceRaidFrames ~= false end,
            names = { "CompactRaidFrameManager", "CompactRaidFrameContainer" },
        },
    }

    for _, group in pairs(frameGroups) do
        if group.enabled() then
            for _, name in ipairs(group.names) do
                local frame = _G[name]
                if frame then
                    if group == frameGroups.unit and name:find("CastingBarFrame", 1, true)
                        and frame.SetUnit then
                        -- Fully detach Blizzard's player cast widgets while
                        -- their PrettyFrames replacement is enabled. Merely
                        -- setting alpha can be undone by an interrupted cast.
                        pcall(frame.SetUnit, frame, nil)
                    end
                    frame:SetAlpha(0)
                    if frame.EnableMouse then
                        frame:EnableMouse(false)
                    end
                    if not self.suppressedFrames[frame] then
                        self.suppressedFrames[frame] = group.enabled
                        hooksecurefunc(frame, "SetAlpha", function(widget)
                            local enabled = PF.suppressedFrames[widget]
                            if enabled and enabled() and widget:GetAlpha() ~= 0 then
                                if InCombatLockdown() then
                                    PF.pendingBlizzardSuppression = true
                                else
                                    widget:SetAlpha(0)
                                end
                            end
                        end)
                    end
                end
            end
        end
    end
    self.pendingBlizzardSuppression = nil
    return true
end

function PF:SetTestMode(enabled, silent)
    if InCombatLockdown() then
        self:Print("test mode cannot change during combat.")
        return
    end
    self.testMode = enabled
    if self.ApplyAllActionBindings then self:ApplyAllActionBindings() end
    self:ApplyGroupStateDrivers()
    for _, frame in ipairs(self.unitFrames) do
        self:ApplyFrameVisibility(frame)
        self:UpdateUnitFrame(frame, true)
    end
    if self.UpdateClassResourceDisplay then
        self:UpdateClassResourceDisplay(true)
    end
    if self.ApplyPartyGroupLayout then
        self:ApplyPartyGroupLayout()
    end
    if self.ApplyBossFramesVisibility then
        self:ApplyBossFramesVisibility()
    end
    if self.RefreshCastBarPreviews then
        self:RefreshCastBarPreviews()
    end
    if self.UpdateRaidConnectors then
        self:UpdateRaidConnectors()
    end
    if self.RefreshPartyRangeStates then
        self:RefreshPartyRangeStates()
    end
    if not silent then
        self:Print(enabled and "test mode enabled." or "test mode disabled.")
    end
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == addonName then
            PF:InitializeDatabase()
        elseif PF.db and (loaded == "Clique" or loaded == "Blizzard_ClickBindingUI")
            and PF.ApplyAllActionBindings then
            PF:ApplyAllActionBindings()
        end
    elseif event == "PLAYER_LOGIN" then
        PF:CreateAllFrames()
        PF:RefreshScale()
        if PF.db.mirrorPlayerTarget then
            PF:MirrorPlayerTargetPosition("player")
        end
        PF:SuppressBlizzardFrames()
        PF:RegisterRuntimeEvents(driver)
    else
        PF:HandleEvent(event, ...)
    end
end)

function PF:RegisterRuntimeEvents(frame)
    local events = {
        "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED",
        "INSTANCE_ENCOUNTER_ENGAGE_UNIT",
        "PLAYER_FOCUS_CHANGED", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT",
        "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_LEVEL",
        "UNIT_FACTION", "UNIT_CONNECTION", "UNIT_MODEL_CHANGED", "UNIT_PORTRAIT_UPDATE",
        "UNIT_AURA", "UNIT_TARGET", "UNIT_PET", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "RAID_TARGET_UPDATE",
        "PLAYER_ROLES_ASSIGNED", "PLAYER_UPDATE_RESTING", "PLAYER_FLAGS_CHANGED", "UNIT_FLAGS",
        "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE", "UNIT_PHASE", "INCOMING_RESURRECT_CHANGED",
        "INCOMING_SUMMON_CHANGED",
        "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED",
        "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED",
        "UPDATE_MACROS",
        "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE", "UPDATE_SHAPESHIFT_FORM",
        "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "RUNE_POWER_UPDATE",
        "PLAYER_TOTEM_UPDATE", "UNIT_POWER_POINT_CHARGE",
        "ITEM_COUNT_CHANGED", "BAG_UPDATE_DELAYED",
        "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED",
    }
    for _, event in ipairs(events) do
        frame:RegisterEvent(event)
    end
end

function PF:HandleEvent(event, unit)
    if self.HandleClassResourceEvent then
        self:HandleClassResourceEvent(event, unit)
    end
    if event == "UPDATE_MACROS" then
        if self.ApplyAllActionBindings then self:ApplyAllActionBindings() end
        if self.RefreshActionsWindow then self:RefreshActionsWindow() end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        -- Most builds deliver this just before lockdown, but Forever may
        -- already report lockdown. Secure state drivers activate prepared
        -- actions independently; the Lua path only closes edit affordances.
        self.restoreEditModeAfterCombat = self.db and not self.db.locked or false
        self.restoreTestModeAfterCombat = self.testMode == true
        if self.actionsWindow then self.actionsWindow:Hide() end
        if StaticPopup_Hide then
            StaticPopup_Hide("PRETTYFRAMES_ACTION_NEW")
            StaticPopup_Hide("PRETTYFRAMES_ACTION_RENAME")
            StaticPopup_Hide("PRETTYFRAMES_ACTION_DUPLICATE")
            StaticPopup_Hide("PRETTYFRAMES_ACTION_DELETE")
        end

        if InCombatLockdown() then
            -- The secure state driver on each action frame has already copied
            -- its prepared bindings. Keep insecure edit callbacks closed even
            -- on clients where this event arrives after lockdown begins.
            self.testMode = false
            if self.db then self.db.locked = true end
            self.pendingCombatEditExit = true
        else
            if self.restoreTestModeAfterCombat then
                self:SetTestMode(false, true)
            end
            if self.restoreEditModeAfterCombat then
                self:SetLocked(true, true)
            end
        end
        return
    end

    if event == "PLAYER_UPDATE_RESTING" then
        if self.UpdatePlayerRestingIndicator then
            self:UpdatePlayerRestingIndicator()
        end
        return
    end

    if event == "RAID_TARGET_UPDATE" then
        -- Some Forever builds attach an argument to this event while others
        -- do not. A marker can affect any visible unit token, so always refresh
        -- the complete unit-frame set instead of routing by that argument.
        self:RefreshAllFrames()
        return
    end

    if event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        if self.RefreshBossFrames then self:RefreshBossFrames(true) end
        return
    end

    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        self:SuppressBlizzardFrames()
        if event == "PLAYER_ENTERING_WORLD" and self.UpdatePlayerRestingIndicator then
            self:UpdatePlayerRestingIndicator()
        end
        if self.ApplyRaidUnitBindings then
            self:ApplyRaidUnitBindings()
        end
        if self.ApplyPartyUnitBindings then
            self:ApplyPartyUnitBindings()
        end
        if self.ApplyGroupStateDrivers then
            self:ApplyGroupStateDrivers()
        end
    end

    if event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
        if self.RefreshRaidFrames then
            self:RefreshRaidFrames()
        end
        return
    end

    if event == "PLAYER_TARGET_CHANGED" and self.RefreshRaidFrames then
        self:RefreshRaidFrames()
    end

    if (event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED")
        and self.ApplyPartyGroupLayout then
        self:ApplyPartyGroupLayout()
    end
    if event == "PLAYER_ROLES_ASSIGNED" and self.db.raidLayout.sort == "role"
        and self.ApplyRaidUnitBindings then
        self:ApplyRaidUnitBindings()
    end

    if event == "GROUP_ROSTER_UPDATE" and InCombatLockdown() then
        self.pendingRefresh = true
        if self.RefreshPartyFrames then
            self:RefreshPartyFrames(false)
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        self.pendingCombatEditExit = nil
        if self.pendingBlizzardSuppression then
            self:SuppressBlizzardFrames()
        end
        if self.pendingRaidUnitBindings and self.ApplyRaidUnitBindings then
            self:ApplyRaidUnitBindings()
        end
        if self.pendingPartyUnitBindings and self.ApplyPartyUnitBindings then
            self:ApplyPartyUnitBindings()
        end
        if self.pendingGroupStateDrivers and self.ApplyGroupStateDrivers then
            self:ApplyGroupStateDrivers()
        end
        if self.pendingActionSources and self.ApplyPendingActionSources then
            self:ApplyPendingActionSources()
        elseif self.pendingActionBindings and self.ApplyAllActionBindings then
            self:ApplyAllActionBindings()
        end

        local pendingFlips = self.pendingFrameFlips
        self.pendingFrameFlips = setmetatable({}, { __mode = "k" })
        for frame in pairs(pendingFlips) do
            self:ApplyFrameFlip(frame)
        end

        if self.pendingScaleRefresh then
            self:RefreshScale()
        end
        local pendingScales = self.pendingFrameScales
        self.pendingFrameScales = setmetatable({}, { __mode = "k" })
        for frame in pairs(pendingScales) do
            self:ApplyFrameScale(frame)
        end

        local pendingVisibility = self.pendingVisibilityFrames
        self.pendingVisibilityFrames = setmetatable({}, { __mode = "k" })
        for frame in pairs(pendingVisibility) do
            self:ApplyFrameVisibility(frame)
        end
        if self.frames.pet then
            self:ApplyFrameVisibility(self.frames.pet)
        end

        if self.pendingPartyLayout and self.ApplyPartyGroupLayout then
            self:ApplyPartyGroupLayout()
        end
        if self.pendingPartyAuraLayout and self.ApplyPartyAuraLayout then
            self:ApplyPartyAuraLayout()
        end
        if self.pendingRaidLayout and self.ApplyRaidGroupLayout then
            self:ApplyRaidGroupLayout()
        end
        if self.pendingBossLayout and self.ApplyBossGroupLayout then
            self:ApplyBossGroupLayout()
        end
        if self.pendingBossVisibility and self.ApplyBossFramesVisibility then
            self:ApplyBossFramesVisibility()
        end

        self.pendingRefresh = nil
        self:RefreshAllFrames()

        local restoreEditMode = self.restoreEditModeAfterCombat
        local restoreTestMode = self.restoreTestModeAfterCombat
        self.restoreEditModeAfterCombat = nil
        self.restoreTestModeAfterCombat = nil
        if restoreEditMode then
            self:SetLocked(false, true)
        end
        if restoreTestMode then
            self:SetTestMode(true, true)
        end
        return
    end

    if event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then
        self:RefreshTargetThreatDisplays()
    elseif event == "UNIT_PET" and unit == "player" then
        self:RefreshTargetThreatDisplays()
    end

    local secondaryUnit
    if event == "PLAYER_TARGET_CHANGED" then
        unit = "target"
        secondaryUnit = "targettarget"
    elseif event == "PLAYER_FOCUS_CHANGED" then
        unit = "focus"
    elseif event == "UNIT_TARGET" and unit == "target" then
        unit = "targettarget"
    elseif event == "UNIT_PET" and unit == "player" then
        unit = "pet"
    end

    if unit then
        local updateModel = event == "UNIT_MODEL_CHANGED"
            or event == "UNIT_PORTRAIT_UPDATE"
            or event == "PLAYER_TARGET_CHANGED"
            or event == "PLAYER_FOCUS_CHANGED"
            or event == "UNIT_TARGET"
            or event == "UNIT_PET"
        for _, frame in ipairs(self.unitFrames) do
            if frame.unit == unit or frame.unit == secondaryUnit then
                if event == "UNIT_PET" then
                    self:ApplyFrameVisibility(frame)
                end
                self:UpdateUnitFrame(frame, updateModel)
                if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
                    self:RefreshNativeAuras(frame)
                end
            end
        end
        if event == "UNIT_NAME_UPDATE" and unit:find("^party")
            and self.db.partyLayout.sort == "name" then
            self:ApplyPartyGroupLayout()
        end
        if event == "UNIT_NAME_UPDATE"
            and (unit:find("^raid") or unit:find("^party") or unit == "player")
            and self.db.raidLayout.sort == "name" and self.ApplyRaidUnitBindings then
            self:ApplyRaidUnitBindings()
        end
    else
        self:RefreshAllFrames()
    end
end

function PF:RefreshAllFrames()
    for _, frame in ipairs(self.unitFrames) do
        self:UpdateUnitFrame(frame, true)
    end
end

function PF:Set3DPortraitsEnabled(enabled)
    self.db.enable3DPortraits = enabled == true
    self:RefreshAllFrames()
end

function PF:RefreshPartyFrames(updateModels)
    local anchor = self.frames and self.frames.party
    if not anchor or not anchor.partyFrames then return end
    for _, frame in ipairs(anchor.partyFrames) do
        self:UpdateUnitFrame(frame, updateModels == true)
    end
end

function PF:RefreshRaidFrames()
    local anchor = self.frames.raid
    if not anchor or not anchor.raidFrames then return end
    for _, frame in ipairs(anchor.raidFrames) do
        self:UpdateUnitFrame(frame, false)
    end
end
