local _, PF = ...

local themeLayout = PF:ThemeLayout("castBar")

PF.CastBars = PF.CastBars or {}
local CastBars = PF.CastBars

CastBars.fillTexture = "Interface\\TargetingFrame\\UI-StatusBar"
CastBars.castColor = { 0.92, 0.52, 0.12 }
CastBars.channelColor = { 0.18, 0.72, 0.12 }

local CAST_EVENTS = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_EMPOWER_UPDATE",
    "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

local function ValueIsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function HasCastValue(value)
    return ValueIsSecret(value) or value ~= nil
end

CastBars.HasCastValue = HasCastValue

local function GetOrnamentSize(barWidth, extraWidth, minHeight)
    local width = barWidth + (extraWidth or themeLayout.ornamentExtraWidth)
    local height = math.max(
        minHeight or themeLayout.ornamentMinHeight,
        width / themeLayout.ornamentAspect
    )
    return width, height
end

local function SetOrnamentGeometry(region, bar, barWidth, extraWidth, point, minHeight)
    region:SetSize(GetOrnamentSize(barWidth or bar:GetWidth(), extraWidth, minHeight))
    PF:SetThemePoint(region, bar, point or themeLayout.ornamentPoint)
end

local function CreateCastBarOrnament(
    bar, barWidth, extraWidth, minHeight, point, themeFrameName, autoVisibility
)
    -- Forever clips textures created directly on a StatusBar to its animated
    -- fill. Keep the decoration on a sibling frame so its caps stay attached
    -- to the full bar rather than moving with cast progress.
    local holder = CreateFrame("Frame", nil, bar:GetParent())
    SetOrnamentGeometry(holder, bar, barWidth, extraWidth, point, minHeight)
    holder:SetFrameLevel(bar:GetFrameLevel() + 2)
    holder:EnableMouse(false)
    themeFrameName = themeFrameName or bar.themeFrameName or "castBar"
    local capAsset = PF:ThemeFrameAsset(
        themeFrameName, "castBarEndCap", "castBarEndCap"
    )
    local capSize = themeLayout.endCapBarScale
        and bar:GetHeight() * themeLayout.endCapBarScale
        or holder:GetHeight() * (themeLayout.endCapScale or 1)
    local capOffsetX = capSize * (
        themeLayout.castEndCapOffsetX or themeLayout.endCapOffsetX or 0
    )
    local capOffsetY = capSize * (
        themeLayout.castEndCapOffsetY or themeLayout.endCapOffsetY or 0
    )

    -- Constrain each texture inside an explicitly sized child frame. This
    -- makes runtime geometry authoritative even on clients that preserve a
    -- texture's native 128px dimensions despite SetSize on the region.
    holder.leftCap = CreateFrame("Frame", nil, holder)
    holder.leftCap:SetFrameLevel(holder:GetFrameLevel() + 1)
    holder.leftCap:EnableMouse(false)
    holder.leftCap:SetSize(capSize, capSize)
    holder.leftCap:SetPoint("LEFT", holder, "LEFT", -capOffsetX, capOffsetY)
    holder.leftCap.texture = holder.leftCap:CreateTexture(nil, "OVERLAY", nil, 7)
    holder.leftCap.texture:SetAllPoints(holder.leftCap)
    holder.leftCap.texture:SetTexture(capAsset)

    holder.rightCap = CreateFrame("Frame", nil, holder)
    holder.rightCap:SetFrameLevel(holder:GetFrameLevel() + 1)
    holder.rightCap:EnableMouse(false)
    holder.rightCap:SetSize(capSize, capSize)
    holder.rightCap:SetPoint("RIGHT", holder, "RIGHT", capOffsetX, capOffsetY)
    holder.rightCap.texture = holder.rightCap:CreateTexture(nil, "OVERLAY", nil, 7)
    holder.rightCap.texture:SetAllPoints(holder.rightCap)
    holder.rightCap.texture:SetTexture(capAsset)
    holder.rightCap.texture:SetTexCoord(1, 0, 0, 1)
    holder:Hide()

    if autoVisibility ~= false then
        bar:HookScript("OnShow", function()
            holder:Show()
        end)
        bar:HookScript("OnHide", function()
            holder:Hide()
        end)
        if bar:IsShown() then holder:Show() end
    end
    return holder
end

-- Nameplates retain Blizzard's native cast StatusBar, but can safely reuse the
-- same passive sibling ornament without touching protected cast state.
CastBars.CreateOrnament = CreateCastBarOrnament

local function CreateInterruptibleGlow(parent, barWidth, extraWidth, minHeight, themeFrameName)
    -- A texture created directly on a StatusBar is clipped to its animated
    -- fill on Forever. Use a sibling frame so the signal always spans the
    -- complete cast bar, independent of current cast progress.
    local glow = CreateFrame("Frame", nil, parent:GetParent())
    SetOrnamentGeometry(
        glow, parent, barWidth, extraWidth or parent.ornamentExtraWidth,
        themeLayout.interruptGlowPoint, minHeight
    )
    -- Keep the interrupt signal above the StatusBar fill and decorative frame.
    -- Its additive blend preserves the underlying art while making the state
    -- readable immediately in both live and preview paths.
    glow:SetFrameLevel(parent:GetFrameLevel() + 4)
    glow:EnableMouse(false)
    glow.texture = glow:CreateTexture(nil, "OVERLAY", nil, 6)
    glow.texture:SetAllPoints(glow)
    themeFrameName = themeFrameName or parent.themeFrameName or "castBar"
    glow.texture:SetTexture(PF:ThemeFrameAsset(
        themeFrameName, "castBarInterruptGlow", "castBarInterruptGlow"
    ))
    -- Discard the source asset's generous transparent side margins so the
    -- luminous rails span the usable bar and finish beneath the bronze caps.
    glow.texture:SetTexCoord(unpack(themeLayout.interruptGlowCrop))
    if themeLayout.interruptGlowColor then
        glow.texture:SetVertexColor(unpack(themeLayout.interruptGlowColor))
    end
    glow.texture:SetBlendMode("ADD")
    glow:SetAlpha(0)
    glow:Hide()
    return glow
end

CastBars.CreateInterruptibleGlow = CreateInterruptibleGlow

local function GetInterruptGlowAlpha()
    return themeLayout.interruptGlowAlpha or 0.72
end

local function SetCastInterruptible(castBar, notInterruptible, unit)
    local glow = castBar.prettyFramesInterruptibleGlow or castBar.interruptibleGlow
    if not glow then return end
    if (unit or castBar.unit) == "player" then
        glow:Hide()
        return
    end

    glow:Show()
    if ValueIsSecret(notInterruptible) then
        -- SetAlphaFromBoolean can consume Forever's restricted boolean without
        -- exposing it to addon logic. False means the cast is interruptible.
        glow:SetAlphaFromBoolean(notInterruptible, 0, GetInterruptGlowAlpha())
    else
        glow:SetAlpha(notInterruptible and 0 or GetInterruptGlowAlpha())
    end
end

CastBars.SetInterruptible = SetCastInterruptible

local function RefreshUnitCastBar(castBar)
    if not castBar.showCastbar then
        if castBar.interruptibleGlow then castBar.interruptibleGlow:Hide() end
        castBar:Hide()
        return
    end

    local name, text, texture, startTime, endTime, _, _, notInterruptible = UnitCastingInfo(castBar.unit)
    local kind = "cast"
    local duration
    if HasCastValue(name) then
        duration = UnitCastingDuration and UnitCastingDuration(castBar.unit)
    else
        local empowered
        name, text, texture, startTime, endTime, _, notInterruptible, _, empowered = UnitChannelInfo(castBar.unit)
        if HasCastValue(name) then
            local isEmpowered = not ValueIsSecret(empowered) and empowered == true
            kind = isEmpowered and "empower" or "channel"
            if isEmpowered and UnitEmpoweredChannelDuration then
                duration = UnitEmpoweredChannelDuration(castBar.unit)
            elseif UnitChannelDuration then
                duration = UnitChannelDuration(castBar.unit)
            end
        end
    end

    if not HasCastValue(name) then
        castBar.fallbackStart = nil
        castBar.fallbackEnd = nil
        if castBar.interruptibleGlow then castBar.interruptibleGlow:Hide() end
        castBar:Hide()
        return
    end

    -- Both setters accept restricted values; do not inspect or combine them.
    castBar.Text:SetText(text)
    castBar.Icon:SetTexture(texture)
    castBar.failureHideAt = nil
    SetCastInterruptible(castBar, notInterruptible)
    castBar:SetStatusBarColor(unpack(
        kind == "channel" and CastBars.channelColor or CastBars.castColor
    ))
    castBar.fallbackStart = nil
    castBar.fallbackEnd = nil

    if not ValueIsSecret(duration) and duration ~= nil
        and castBar.SetTimerDuration and Enum.StatusBarTimerDirection then
        local direction = kind == "channel"
            and Enum.StatusBarTimerDirection.RemainingTime
            or Enum.StatusBarTimerDirection.ElapsedTime
        castBar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, direction)
    elseif not ValueIsSecret(startTime) and not ValueIsSecret(endTime)
        and startTime and endTime and endTime > startTime then
        castBar.fallbackStart = startTime / 1000
        castBar.fallbackEnd = endTime / 1000
        castBar.fallbackChannel = kind == "channel"
        castBar:SetMinMaxValues(castBar.fallbackStart, castBar.fallbackEnd)
    else
        -- A full bar is preferable to losing the cast entirely on clients
        -- that restrict timing but do not expose duration objects.
        castBar:SetMinMaxValues(0, 1)
        castBar:SetValue(1)
    end
    castBar:Show()
end

local function CreateUnitCastBar(
    parent, unit, width, height, updateEvent, ornamentExtraWidth, themeFrameName
)
    -- Forever exposes restricted enemy timing through duration objects. Feed
    -- those objects directly to a StatusBar so no secret values are inspected
    -- or used in addon arithmetic during combat.
    local castBar = CreateFrame("StatusBar", nil, parent)
    castBar:Hide()
    castBar:SetSize(width, height)
    castBar:SetFrameLevel(parent:GetFrameLevel() + 28)
    castBar:SetStatusBarTexture(CastBars.fillTexture)
    castBar.showCastbar = true
    castBar.unit = unit
    castBar.ornamentExtraWidth = ornamentExtraWidth
    castBar.themeFrameName = themeFrameName or "castBar"

    castBar.prettyBackground = castBar:CreateTexture(nil, "BACKGROUND", nil, 4)
    castBar.prettyBackground:SetAllPoints(castBar)
    castBar.prettyBackground:SetColorTexture(0.025, 0.018, 0.012, 0.94)

    castBar.Icon = castBar:CreateTexture(nil, "ARTWORK", nil, 2)
    castBar.Icon:SetSize(height + themeLayout.iconExtraSize, height + themeLayout.iconExtraSize)
    PF:SetThemePoint(castBar.Icon, castBar, themeLayout.iconPoint)
    castBar.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    castBar.Text = castBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    castBar.Text:SetPoint("LEFT", castBar.Icon, "RIGHT", themeLayout.textLeft, 0)
    castBar.Text:SetPoint("RIGHT", castBar, "RIGHT", themeLayout.textRight, 0)
    castBar.Text:SetJustifyH("LEFT")
    castBar.Text:SetTextColor(1, 0.91, 0.72)
    local font, _, flags = castBar.Text:GetFont()
    castBar.Text:SetFont(font, math.max(9, height - 3), flags)

    castBar.ornament = CreateCastBarOrnament(
        castBar, width, ornamentExtraWidth, nil, nil,
        castBar.themeFrameName, false
    )

    castBar.interruptibleGlow = CreateInterruptibleGlow(
        castBar, nil, nil, nil, castBar.themeFrameName
    )

    -- Test mode uses a separate visual bar so preview animation never changes
    -- the native CastingBarMixin state used for restricted combat updates.
    local preview = CreateFrame("StatusBar", nil, parent)
    preview.themeFrameName = castBar.themeFrameName
    preview:SetAllPoints(castBar)
    preview:SetFrameLevel(castBar:GetFrameLevel() + 1)
    preview:SetStatusBarTexture(CastBars.fillTexture)
    preview:SetStatusBarColor(unpack(CastBars.castColor))
    preview:SetMinMaxValues(0, 1)
    preview:SetValue(0)
    preview:Hide()

    preview.background = preview:CreateTexture(nil, "BACKGROUND", nil, 4)
    preview.background:SetAllPoints(preview)
    preview.background:SetColorTexture(0.025, 0.018, 0.012, 0.94)

    preview.Icon = preview:CreateTexture(nil, "ARTWORK", nil, 2)
    preview.Icon:SetSize(height + themeLayout.iconExtraSize, height + themeLayout.iconExtraSize)
    PF:SetThemePoint(preview.Icon, preview, themeLayout.iconPoint)
    preview.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    preview.Icon:SetTexture("Interface\\Icons\\Spell_Nature_HealingTouch")

    preview.Text = preview:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    preview.Text:SetPoint("LEFT", preview.Icon, "RIGHT", themeLayout.textLeft, 0)
    preview.Text:SetPoint("RIGHT", preview, "RIGHT", themeLayout.textRight, 0)
    preview.Text:SetJustifyH("LEFT")
    preview.Text:SetTextColor(1, 0.91, 0.72)
    preview.Text:SetText("Healing Touch")
    local previewFont, _, previewFlags = preview.Text:GetFont()
    preview.Text:SetFont(previewFont, math.max(9, height - 3), previewFlags)

    -- Live and preview bars occupy identical geometry, so share the complete
    -- ornament tree. This removes a second set of visibility hooks, frame
    -- levels, and cap geometry that can drift from the live presentation.
    preview.ornament = castBar.ornament
    local function RefreshSharedOrnamentVisibility()
        castBar.ornament:SetShown(castBar:IsShown() or preview:IsShown())
    end
    castBar:HookScript("OnShow", RefreshSharedOrnamentVisibility)
    castBar:HookScript("OnHide", RefreshSharedOrnamentVisibility)
    preview:HookScript("OnShow", RefreshSharedOrnamentVisibility)
    preview:HookScript("OnHide", RefreshSharedOrnamentVisibility)
    RefreshSharedOrnamentVisibility()

    preview:SetScript("OnUpdate", function(widget)
        widget:SetValue((GetTime() % 2.8) / 2.8)
    end)

    castBar.preview = preview
    castBar.ownerFrame = parent
    PF.castBars = PF.castBars or {}
    table.insert(PF.castBars, castBar)

    for _, event in ipairs(CAST_EVENTS) do
        PF:RegisterEventSafe(castBar, event, unit)
    end
    if updateEvent then PF:RegisterEventSafe(castBar, updateEvent) end
    PF:RegisterEventSafe(castBar, "PLAYER_ENTERING_WORLD")
    castBar:SetScript("OnEvent", function(widget, event)
        if event == "UNIT_SPELLCAST_INTERRUPTED" then
            widget.fallbackStart = nil
            widget.fallbackEnd = nil
            if widget.interruptibleGlow then widget.interruptibleGlow:Hide() end
            if widget.showCastbar then
                widget:SetMinMaxValues(0, 1)
                widget:SetValue(1)
                widget:SetStatusBarColor(0.82, 0.08, 0.06)
                widget.Text:SetText(INTERRUPTED or SPELL_FAILED_INTERRUPTED or "Interrupted")
                widget.failureHideAt = GetTime() + 0.9
                widget:Show()
            else
                widget:Hide()
            end
        elseif event == "UNIT_SPELLCAST_FAILED" then
            widget.fallbackStart = nil
            widget.fallbackEnd = nil
            widget.failureHideAt = nil
            if widget.interruptibleGlow then widget.interruptibleGlow:Hide() end
            widget:Hide()
        elseif event == "UNIT_SPELLCAST_STOP"
            or event == "UNIT_SPELLCAST_CHANNEL_STOP"
            or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
            if widget.failureHideAt then return end
            widget.fallbackStart = nil
            widget.fallbackEnd = nil
            widget.failureHideAt = nil
            if widget.interruptibleGlow then widget.interruptibleGlow:Hide() end
            widget:Hide()
        else
            RefreshUnitCastBar(widget)
        end
    end)
    castBar:SetScript("OnUpdate", function(widget)
        if widget.failureHideAt then
            if GetTime() >= widget.failureHideAt then
                widget.failureHideAt = nil
                widget:Hide()
            end
            return
        end
        if not widget.fallbackStart or not widget.fallbackEnd then return end
        local now = GetTime()
        local value = math.min(widget.fallbackEnd, math.max(widget.fallbackStart, now))
        if widget.fallbackChannel then
            value = widget.fallbackEnd - (value - widget.fallbackStart)
        end
        widget:SetValue(value)
    end)
    RefreshUnitCastBar(castBar)
    return castBar
end

function PF:RefreshCastBarDisplay(castBar)
    if not castBar then return end
    local owner = castBar.ownerFrame
    local settingKey = owner and (owner.castBarSettingKey or owner.settingKey)
    local setting = settingKey and self:GetFrameSetting(settingKey)
    local hidden = setting and setting.hideCastBar == true

    castBar.showCastbar = not hidden
    if hidden then
        if castBar.interruptibleGlow then castBar.interruptibleGlow:Hide() end
        castBar:Hide()
    end
    local showPreview = false
    if castBar.preview then
        showPreview = (self.testMode == true or self.db.locked == false) and not hidden
        castBar.preview:SetShown(showPreview)
        if showPreview and castBar.interruptibleGlow
            and castBar.unit ~= "player" then
            -- The live glow is a sibling layer and is not clipped by the
            -- StatusBar fill. Reuse it for the identically anchored test
            -- bar instead of maintaining a second clipped preview glow.
            -- Raise the glow above the shared cap wrappers so the additive
            -- signal is never occluded.
            castBar.interruptibleGlow:SetFrameLevel(
                castBar.preview:GetFrameLevel() + 3
            )
            castBar.interruptibleGlow:SetAlpha(GetInterruptGlowAlpha())
            castBar.interruptibleGlow:Show()
        elseif castBar.interruptibleGlow then
            castBar.interruptibleGlow:Hide()
        end
    end
    if not hidden and not showPreview then
        if castBar.interruptibleGlow then
            castBar.interruptibleGlow:SetFrameLevel(castBar:GetFrameLevel() + 4)
        end
        RefreshUnitCastBar(castBar)
    end
end

function PF:RefreshCastBarPreviews()
    for _, castBar in ipairs(self.castBars or {}) do
        self:RefreshCastBarDisplay(castBar)
    end
end

CastBars.CreateUnitCastBar = CreateUnitCastBar
