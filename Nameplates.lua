local _, PF = ...

local themeLayout = PF:ThemeLayout("nameplate")
local castThemeLayout = PF:ThemeLayout("castBar")
local CreateUnitMarker = PF.Widgets.CreateUnitMarker
local SetRaidMarkerTexture = PF.Widgets.SetRaidMarkerTexture

local CAST_FILL_TEXTURE = PF.CastBars.fillTexture
local CAST_COLOR = PF.CastBars.castColor
local CHANNEL_COLOR = PF.CastBars.channelColor
local NATIVE_CAST_DECORATIONS = {
    "Border", "BorderShield", "Shield", "Glow", "IconBorder", "Spark",
}
local nativeDecorationAlphaHooks = setmetatable({}, { __mode = "k" })
local nativeDecorationAlphaGuards = setmetatable({}, { __mode = "k" })

-- PrettyFrames deliberately skins Blizzard's existing nameplate components
-- instead of replacing their data flow. Blizzard continues to own health,
-- casts, threat coloring, targeting, and aura updates (including secret combat
-- values); this file only supplies artwork, anchors, fonts, and direct display
-- bindings that do not inspect protected values.

PF.activeNameplates = PF.activeNameplates or {}

-- Theme.lua keeps artwork, text, and Blizzard's native StatusBar in one visual scale.

local function NameplateReplacementEnabled()
    -- The database is initialized during ADDON_LOADED, before nameplates can
    -- be styled. Default to enabled only for the brief pre-initialization
    -- window so existing installations retain their current behavior.
    return not PF.db or PF.db.replaceNameplates ~= false
end

local function IsAccessible(frame)
    if not frame then return false end
    if frame.IsForbidden then
        local ok, forbidden = pcall(frame.IsForbidden, frame)
        if ok and forbidden then return false end
    end
    return true
end

local function UpdateHealthText(unitFrame)
    local unit = unitFrame.prettyFramesUnit
    if not unit or not unitFrame.prettyFramesHealthText then return end

    -- Do not calculate percentages here. On Forever these values may be secret
    -- in combat, but FontString can consume them directly without exposing them
    -- to addon Lua.
    local current = UnitHealth(unit)
    local maximum = UnitHealthMax(unit)
    unitFrame.prettyFramesHealthText:SetFormattedText("%s / %s", current, maximum)
end

local function UpdateLevelText(unitFrame)
    local unit = unitFrame.prettyFramesUnit
    if not unit or not unitFrame.prettyFramesLevelText then return end
    local level = UnitLevel(unit)
    if PF:IsDisplaySafe(level) and level < 0 then
        unitFrame.prettyFramesLevelText:SetText("??")
    else
        unitFrame.prettyFramesLevelText:SetFormattedText("%s", level)
    end
end

local function ApplyNameTypography(unitFrame)
    local name = unitFrame and unitFrame.name
    if not name then return end

    -- These are the same font object and RGB values used by frame.nameText in
    -- Frames.lua. Blizzard refreshes native nameplate name colors after the
    -- plate is created, so this is also called from the secure post-hook below.
    name:SetFontObject(GameFontNormalLarge)
    name:SetFontHeight(10)
    name:SetTextColor(1, 0.91, 0.72)
end

local function ApplyCastColor(castBar, kind)
    castBar.prettyFramesCastKind = kind or castBar.prettyFramesCastKind or "cast"
    local color = castBar.prettyFramesCastKind == "channel" and CHANNEL_COLOR or CAST_COLOR
    local texture = castBar:GetStatusBarTexture()
    if texture then
        -- Set the native texture directly so Blizzard can continue updating the
        -- protected StatusBar value without restoring its yellow/green colors.
        texture:SetVertexColor(unpack(color))
    end
end

local function SuppressNativeCastRegion(region)
    if not region or not region.SetAlpha then return end
    if hooksecurefunc and not nativeDecorationAlphaHooks[region] then
        local hooked = pcall(hooksecurefunc, region, "SetAlpha", function(widget)
            if nativeDecorationAlphaGuards[widget] then return end
            nativeDecorationAlphaGuards[widget] = true
            widget:SetAlpha(0)
            nativeDecorationAlphaGuards[widget] = nil
        end)
        if hooked then nativeDecorationAlphaHooks[region] = true end
    end
    region:SetAlpha(0)
end

local function HideNativeCastDecorations(castBar)
    for _, key in ipairs(NATIVE_CAST_DECORATIONS) do
        SuppressNativeCastRegion(castBar[key])
    end

    -- Forever also uses anonymous cast-bar textures that are not exposed by
    -- the usual Border/BorderShield fields. Keep only the regions that form
    -- the PrettyFrames composition and suppress every other native texture.
    local fill = castBar:GetStatusBarTexture()
    local regions = { castBar:GetRegions() }
    for _, region in ipairs(regions) do
        local isTexture = region.IsObjectType and region:IsObjectType("Texture")
        if isTexture and region ~= fill and region ~= castBar.Icon
            and region ~= castBar.prettyBackground then
            SuppressNativeCastRegion(region)
        end
    end
end

local function ApplyCastVisuals(castBar)
    castBar:SetStatusBarTexture(CAST_FILL_TEXTURE)

    if not castBar.prettyBackground then
        castBar.prettyBackground = castBar:CreateTexture(nil, "BACKGROUND", nil, 4)
        castBar.prettyBackground:SetAllPoints(castBar)
    end
    castBar.prettyBackground:SetColorTexture(0.025, 0.018, 0.012, 0.94)

    -- PrettyFrames supplies all cast decoration. Hide the native spark,
    -- shield, borders, and glow so their colors cannot bleed through it.
    HideNativeCastDecorations(castBar)

    local height = castBar:GetHeight()
    local iconExtraSize = themeLayout.castIconExtraSize
        or castThemeLayout.iconExtraSize
    if castBar.Icon then
        castBar.Icon:ClearAllPoints()
        castBar.Icon:SetSize(
            height + iconExtraSize,
            height + iconExtraSize
        )
        PF:SetThemePoint(castBar.Icon, castBar, castThemeLayout.iconPoint)
        castBar.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    if castBar.Text then
        castBar.Text:ClearAllPoints()
        if castBar.Icon then
            castBar.Text:SetPoint(
                "LEFT", castBar.Icon, "RIGHT", castThemeLayout.textLeft, 0
            )
        else
            castBar.Text:SetPoint("LEFT", castBar, "LEFT", castThemeLayout.textLeft, 0)
        end
        castBar.Text:SetPoint("RIGHT", castBar, "RIGHT", castThemeLayout.textRight, 0)
        castBar.Text:SetJustifyH("LEFT")
        castBar.Text:SetTextColor(1, 0.91, 0.72)
        castBar.Text:SetFontObject(GameFontHighlightSmall)
        local font, _, flags = castBar.Text:GetFont()
        castBar.Text:SetFont(
            font, themeLayout.castTextSize or math.max(9, height - 3), flags
        )
    end

    ApplyCastColor(castBar)
end

local function UpdateCastInterruptGlow(unitFrame, event)
    local castBar = unitFrame.CastBarsContainer and unitFrame.CastBarsContainer.castBar
    local unit = unitFrame.prettyFramesUnit
    if not castBar or not castBar.prettyFramesInterruptibleGlow or not unit
        or not PF.CastBars or not PF.CastBars.SetInterruptible then
        return
    end

    -- Blizzard may restore its red cast border while processing the same cast
    -- or interruptibility event. Our driver runs afterward and suppresses it.
    HideNativeCastDecorations(castBar)

    if event == "UNIT_SPELLCAST_START" then
        ApplyCastColor(castBar, "cast")
    elseif event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_EMPOWER_START" then
        ApplyCastColor(castBar, "channel")
    else
        ApplyCastColor(castBar)
    end

    if event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        PF.CastBars.SetInterruptible(castBar, false, unit)
        return
    elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        PF.CastBars.SetInterruptible(castBar, true, unit)
        return
    end

    local kind = "cast"
    local name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
    if not name then
        kind = "channel"
        name, _, _, _, _, _, notInterruptible = UnitChannelInfo(unit)
    end
    if not name then
        castBar.prettyFramesInterruptibleGlow:Hide()
        return
    end
    ApplyCastColor(castBar, kind)
    PF.CastBars.SetInterruptible(castBar, notInterruptible, unit)
end

if hooksecurefunc and CompactUnitFrame_UpdateName then
    hooksecurefunc("CompactUnitFrame_UpdateName", function(unitFrame)
        if unitFrame and unitFrame.prettyFramesArtwork then
            ApplyNameTypography(unitFrame)
        end
    end)
end

local function UpdateTargetGlow(unitFrame)
    if not unitFrame.prettyFramesTargetGlow then return end
    -- Blizzard can restore these indicators during its own target update after
    -- the nameplate was initially styled. PrettyFrames uses the integrated
    -- medallion and gold target glow instead.
    if unitFrame.LevelFrame then unitFrame.LevelFrame:SetAlpha(0) end
    if unitFrame.PlayerLevelDiffFrame then unitFrame.PlayerLevelDiffFrame:SetAlpha(0) end
    if unitFrame.ClassificationFrame then unitFrame.ClassificationFrame:SetAlpha(0) end
    if unitFrame.SoftTargetFrame then unitFrame.SoftTargetFrame:SetAlpha(0) end
    local unit = unitFrame.prettyFramesUnit
    local targeted = unit and UnitIsUnit(unit, "target")
    unitFrame.prettyFramesTargetGlow:SetAlpha(PF:IsDisplaySafe(targeted) and targeted and 0.62 or 0)
end

local function SetNativeRaidMarkerAlpha(unitFrame, alpha)
    if unitFrame.RaidTargetFrame then unitFrame.RaidTargetFrame:SetAlpha(alpha) end
    if unitFrame.raidTargetIcon then unitFrame.raidTargetIcon:SetAlpha(alpha) end
    if unitFrame.RaidTargetIcon then unitFrame.RaidTargetIcon:SetAlpha(alpha) end
end

local function UpdateRaidMarker(unitFrame)
    if not unitFrame.prettyFramesRaidMarker then return end
    local unit = unitFrame.prettyFramesUnit
    local markerIndex = unit and GetRaidTargetIndex and GetRaidTargetIndex(unit)
    local customMarkerShown = SetRaidMarkerTexture(unitFrame.prettyFramesRaidMarker, markerIndex)
    -- If this client cannot expose a usable marker index for nameplate unit
    -- tokens, retain Blizzard's marker instead of making the indicator vanish.
    SetNativeRaidMarkerAlpha(unitFrame, customMarkerShown and 0 or 1)
end

local function CreateNameplateArtwork(unitFrame, healthContainer, healthBar)
    local artwork = healthContainer:CreateTexture(nil, "BACKGROUND", nil, -8)
    artwork:SetSize(unpack(themeLayout.artSize))
    PF:SetThemePoint(artwork, healthContainer, themeLayout.artPoint)
    artwork:SetTexture(PF:ThemeFrameAsset("nameplate", "nameplateFrame", "nameplateFrame"))
    unitFrame.prettyFramesArtwork = artwork

    local targetGlow = healthContainer:CreateTexture(nil, "BACKGROUND", nil, -7)
    targetGlow:SetAllPoints(artwork)
    targetGlow:SetTexture(PF:ThemeFrameAsset("nameplate", "nameplateFrame", "nameplateFrame"))
    targetGlow:SetBlendMode("ADD")
    targetGlow:SetVertexColor(1, 0.55, 0.08, 1)
    targetGlow:SetAlpha(0)
    unitFrame.prettyFramesTargetGlow = targetGlow

    local healthText = healthBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    healthText:SetAllPoints(healthBar)
    healthText:SetJustifyH("CENTER")
    healthText:SetTextColor(1, 0.96, 0.84)
    PF:ApplyBoldNumberFont(healthText, 9)
    unitFrame.prettyFramesHealthText = healthText

    local levelText = healthContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    PF:SetThemePoint(levelText, healthContainer, themeLayout.levelPoint)
    levelText:SetTextColor(1, 0.83, 0.35)
    PF:ApplyBoldNumberFont(levelText, 9)
    unitFrame.prettyFramesLevelText = levelText

    unitFrame.prettyFramesRaidMarker = CreateUnitMarker(
        unitFrame, themeLayout.marker.size, healthContainer, themeLayout.marker.point
    )
end

local function StyleCastBar(unitFrame, healthBar)
    local castBar = unitFrame.CastBarsContainer and unitFrame.CastBarsContainer.castBar
    if not castBar then return end

    -- Blizzard anchors the native cast bar directly beneath its much smaller
    -- stock health bar. Our artwork extends farther below that anchor, so move
    -- only the cast StatusBar down while leaving the health container and all
    -- protected cast timing/state bindings untouched.
    local castContainer = unitFrame.CastBarsContainer
    castBar:ClearAllPoints()
    castBar:SetPoint("TOPLEFT", castContainer, "TOPLEFT", 0, themeLayout.castYOffset)
    castBar:SetPoint("TOPRIGHT", castContainer, "TOPRIGHT", 0, themeLayout.castYOffset)
    if themeLayout.castHeight then
        castBar:SetHeight(themeLayout.castHeight)
    end

    ApplyCastVisuals(castBar)

    if not castBar.prettyFramesVisualHooked then
        castBar:HookScript("OnShow", function(widget)
            ApplyCastVisuals(widget)
        end)
        castBar.prettyFramesVisualHooked = true
    end

    if not castBar.prettyFramesColorHooked and hooksecurefunc then
        -- Native cast updates may reapply their state color after a cast starts.
        -- Recolor only the texture region; do not call the hooked method again.
        hooksecurefunc(castBar, "SetStatusBarColor", function(widget)
            ApplyCastColor(widget)
        end)
        castBar.prettyFramesColorHooked = true
    end

    if not castBar.prettyFramesOrnament and PF.CastBars and PF.CastBars.CreateOrnament then
        -- Keep the artwork on a sibling frame: textures placed directly on a
        -- StatusBar can be clipped to its animated fill on Forever. Blizzard
        -- still owns the native bar, its visibility, and all protected values.
        local castWidth = castBar:GetWidth()
        if not castWidth or castWidth <= 0 then
            castWidth = castContainer:GetWidth()
        end
        if not castWidth or castWidth <= 0 then
            castWidth = themeLayout.healthSize[1]
        end
        castBar.prettyFramesOrnament = PF.CastBars.CreateOrnament(
            castBar, castWidth, themeLayout.castOrnamentExtraWidth,
            themeLayout.castOrnamentMinHeight, themeLayout.castOrnamentPoint,
            "nameplate"
        )

        if PF.CastBars.CreateInterruptibleGlow then
            castBar.prettyFramesInterruptibleGlow = PF.CastBars.CreateInterruptibleGlow(
                castBar, castWidth,
                themeLayout.castInterruptGlowExtraWidth
                    or themeLayout.castOrnamentExtraWidth,
                themeLayout.castInterruptGlowMinHeight
                    or themeLayout.castOrnamentMinHeight,
                "nameplate"
            )
            castBar:HookScript("OnHide", function(widget)
                widget.prettyFramesInterruptibleGlow:Hide()
            end)
        end
    end
end

local function ApplyNameplateStructure(unitFrame)
    if not IsAccessible(unitFrame) then return end
    local healthContainer = unitFrame.HealthBarsContainer
    local healthBar = healthContainer and healthContainer.healthBar
    if not healthBar then return end

    if not unitFrame.prettyFramesArtwork then
        CreateNameplateArtwork(unitFrame, healthContainer, healthBar)
    end

    -- Keep Blizzard's native StatusBar and protected value bindings, but place
    -- that bar explicitly inside the much wider recessed opening in our art.
    -- Artwork and text are anchored to the unchanged container so moving the
    -- fill does not drag the rest of the composition with it.
    healthBar:ClearAllPoints()
    healthBar:SetSize(unpack(themeLayout.healthSize))
    PF:SetThemePoint(healthBar, healthContainer, themeLayout.healthPoint)

    if unitFrame.LevelFrame then unitFrame.LevelFrame:SetAlpha(0) end
    if unitFrame.PlayerLevelDiffFrame then unitFrame.PlayerLevelDiffFrame:SetAlpha(0) end
    if unitFrame.ClassificationFrame then unitFrame.ClassificationFrame:SetAlpha(0) end
    if unitFrame.SoftTargetFrame then unitFrame.SoftTargetFrame:SetAlpha(0) end
    SetNativeRaidMarkerAlpha(unitFrame, 1)

    -- Preserve the native StatusBar object and its protected update bindings.
    if healthBar.barTexture then
        healthBar.barTexture:SetTexture(PF:ThemeFrameAsset("nameplate", "statusBar", "statusBar"))
    end
    if healthBar.bgTexture then healthBar.bgTexture:SetAlpha(0) end
    if healthBar.selectedBorder then healthBar.selectedBorder:SetAlpha(0) end
    if healthBar.deselectedOverlay then healthBar.deselectedOverlay:SetAlpha(0) end
    if healthBar.Text then healthBar.Text:SetAlpha(0) end
    if healthBar.LeftText then healthBar.LeftText:SetAlpha(0) end
    if healthBar.RightText then healthBar.RightText:SetAlpha(0) end

    if unitFrame.name then
        unitFrame.name:ClearAllPoints()
        unitFrame.name:SetPoint("BOTTOMLEFT", healthContainer, "TOPLEFT", 2, -3)
        unitFrame.name:SetPoint("BOTTOMRIGHT", healthContainer, "TOPRIGHT", 2, -3)
        unitFrame.name:SetJustifyH("LEFT")
        ApplyNameTypography(unitFrame)
    end

    -- Blizzard continues to populate and update these native aura lists.  Only
    -- their anchors change: the compact skin's name plaque now occupies the
    -- space where the default aura row would otherwise be drawn.
    local aurasFrame = unitFrame.AurasFrame
    if aurasFrame then
        if aurasFrame.DebuffListFrame then
            aurasFrame.DebuffListFrame:ClearAllPoints()
            aurasFrame.DebuffListFrame:SetPoint("BOTTOMLEFT", healthContainer, "TOPLEFT", 0, 12)
        end
        if aurasFrame.BuffListFrame then
            aurasFrame.BuffListFrame:ClearAllPoints()
            aurasFrame.BuffListFrame:SetPoint("BOTTOMRIGHT", healthContainer, "TOPRIGHT", 0, 12)
        end
    end

    StyleCastBar(unitFrame, healthBar)
    unitFrame.prettyFramesLayoutApplied = true
end

-- Blizzard acquires a pooled UnitFrame and runs its setup anchor passes before
-- broadcasting NAME_PLATE_UNIT_ADDED. Mark each acquisition so those setup
-- passes finish with our layout; the marker is cleared by StyleNameplate once
-- Blizzard has completed the unit-frame setup sequence.
if hooksecurefunc and NamePlateBaseMixin and NamePlateBaseMixin.AcquireUnitFrame then
    hooksecurefunc(NamePlateBaseMixin, "AcquireUnitFrame", function(nameplate)
        local unitFrame = nameplate and nameplate.UnitFrame
        if NameplateReplacementEnabled() and IsAccessible(unitFrame) then
            unitFrame.prettyFramesNeedsLayout = true
            unitFrame.prettyFramesLayoutApplied = nil
        end
    end)
end

if hooksecurefunc and NamePlateUnitFrameMixin and NamePlateUnitFrameMixin.UpdateAnchors then
    hooksecurefunc(NamePlateUnitFrameMixin, "UpdateAnchors", function(unitFrame)
        if not NameplateReplacementEnabled() or not unitFrame.prettyFramesNeedsLayout then return end

        local ok = pcall(ApplyNameplateStructure, unitFrame)
        if not ok then
            unitFrame.prettyFramesLayoutApplied = nil
        end
    end)
end

function PF:StyleNameplate(unit)
    if not NameplateReplacementEnabled() then return end
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return end
    local ok, nameplate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not IsAccessible(nameplate) or not nameplate.UnitFrame then return end

    local unitFrame = nameplate.UnitFrame
    -- The acquisition/anchor hooks above normally complete structural styling
    -- before this event. Existing plates seen during a reload get one safe
    -- out-of-combat fallback; never attempt structural recovery in lockdown.
    if not unitFrame.prettyFramesLayoutApplied then
        if InCombatLockdown() then return end
        local styled = pcall(ApplyNameplateStructure, unitFrame)
        if not styled or not unitFrame.prettyFramesLayoutApplied then return end
    end

    unitFrame.prettyFramesNeedsLayout = nil
    unitFrame.prettyFramesUnit = unit
    self.activeNameplates[unit] = unitFrame
    local updated = pcall(function()
        UpdateHealthText(unitFrame)
        UpdateLevelText(unitFrame)
        UpdateTargetGlow(unitFrame)
        UpdateRaidMarker(unitFrame)
        UpdateCastInterruptGlow(unitFrame)
    end)
    if not updated then
        unitFrame.prettyFramesUnit = nil
        self.activeNameplates[unit] = nil
    end
end

function PF:ClearNameplate(unit)
    local unitFrame = self.activeNameplates[unit]
    if unitFrame then
        unitFrame.prettyFramesUnit = nil
        if unitFrame.prettyFramesTargetGlow then unitFrame.prettyFramesTargetGlow:SetAlpha(0) end
        if unitFrame.prettyFramesRaidMarker then SetRaidMarkerTexture(unitFrame.prettyFramesRaidMarker) end
        local castBar = unitFrame.CastBarsContainer and unitFrame.CastBarsContainer.castBar
        if castBar and castBar.prettyFramesInterruptibleGlow then
            castBar.prettyFramesInterruptibleGlow:Hide()
        end
    end
    self.activeNameplates[unit] = nil
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("NAME_PLATE_UNIT_ADDED")
driver:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
driver:RegisterEvent("UNIT_HEALTH")
driver:RegisterEvent("UNIT_MAXHEALTH")
driver:RegisterEvent("UNIT_LEVEL")
driver:RegisterEvent("PLAYER_TARGET_CHANGED")
driver:RegisterEvent("RAID_TARGET_UPDATE")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
for _, event in ipairs({
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}) do
    if not C_EventUtils or not C_EventUtils.IsEventValid or C_EventUtils.IsEventValid(event) then
        driver:RegisterEvent(event)
    end
end
driver:SetScript("OnEvent", function(_, event, unit)
    if not NameplateReplacementEnabled() then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        PF:StyleNameplate(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        PF:ClearNameplate(unit)
    elseif event == "PLAYER_TARGET_CHANGED" then
        for _, unitFrame in pairs(PF.activeNameplates) do
            pcall(UpdateTargetGlow, unitFrame)
        end
    elseif event == "RAID_TARGET_UPDATE" then
        for _, unitFrame in pairs(PF.activeNameplates) do
            pcall(UpdateRaidMarker, unitFrame)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if C_NamePlate and C_NamePlate.GetNamePlates then
            local ok, nameplates = pcall(C_NamePlate.GetNamePlates)
            if ok and nameplates then
                for _, nameplate in ipairs(nameplates) do
                    if IsAccessible(nameplate) and nameplate.UnitFrame and nameplate.UnitFrame.unit then
                        PF:StyleNameplate(nameplate.UnitFrame.unit)
                    end
                end
            end
        end
    elseif event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_EMPOWER_START"
        or event == "UNIT_SPELLCAST_INTERRUPTIBLE"
        or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        local unitFrame = unit and PF.activeNameplates[unit]
        if unitFrame then
            pcall(UpdateCastInterruptGlow, unitFrame, event)
        end
    else
        local unitFrame = unit and PF.activeNameplates[unit]
        if unitFrame then
            if event == "UNIT_LEVEL" then
                pcall(UpdateLevelText, unitFrame)
            else
                pcall(UpdateHealthText, unitFrame)
            end
        end
    end
end)
