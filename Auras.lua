local _, PF = ...

local MAX_AURAS = PF.MAX_AURAS or 40
local RAID_DEBUFF_GROUP = "prettyframes-raid-debuff"
local RAID_OWNED_MAINTENANCE_GROUP = "prettyframes-raid-owned-maintenance"
local RAID_EXTERNAL_MAINTENANCE_GROUP = "prettyframes-raid-external-maintenance"
local BOSS_BUFF_GROUP = "prettyframes-boss-buffs"
local BOSS_DEBUFF_GROUP = "prettyframes-boss-debuffs"

PF.Auras = PF.Auras or {}
local Auras = PF.Auras

local function GetGroupIndicatorOptions(frame)
    if not PF.db then return nil end
    if frame and frame.isPartyFrame then return PF.db.partyLayout end
    return PF.db.raidLayout
end

local MasqueGroup
if LibStub then
    local Masque = LibStub("Masque", true)
    if Masque then
        MasqueGroup = Masque:Group(PF.name, "Auras")
    end
end

local function AddAuraToMasque(button, regions)
    if not MasqueGroup then return end

    -- Supplying the regions explicitly keeps Masque away from the restricted
    -- CustomAuraButtonTemplate internals while still allowing it to create the
    -- skin's normal, mask, gloss, and shadow layers around our aura regions.
    MasqueGroup:AddButton(button, regions, "Aura", true)
end

-- Forever makes live aura data secret in combat. CustomAuraContainerTemplate
-- keeps that data inside Blizzard's secure aura pipeline and writes it directly
-- to the icon/count regions registered below.
local function InitializeNativeAuraButton(button, frame, iconSize, isDebuff, nativeOptions)
    nativeOptions = nativeOptions or {}
    button:SetSize(iconSize, iconSize)
    button:SetFrameLevel(frame:GetFrameLevel() + 25)
    -- CustomAuraButtonTemplate supplies Blizzard's restricted OnEnter/OnLeave
    -- implementation. Enabling input here gives us the exact live aura
    -- tooltip without reading protected combat aura data in addon Lua.
    button:EnableMouse(nativeOptions.enableMouse ~= false)
    if not isDebuff and button.SetCancelAuraButtons then
        -- CustomAuraButtonTemplate performs cancellation inside Blizzard's
        -- restricted aura pipeline. Non-removable buffs simply ignore it.
        button:SetCancelAuraButtons("RightButtonUp")
    end

    -- Masque places aura icons on BACKGROUND sublevel 0. Keep PrettyFrames'
    -- fallback border and inset below that layer so they cannot cover the icon.
    local border = button:CreateTexture(nil, "BACKGROUND", nil, -2)
    border:SetAllPoints(button)
    if nativeOptions.borderColor then
        border:SetColorTexture(unpack(nativeOptions.borderColor))
    elseif isDebuff then
        border:SetColorTexture(0.78, 0.18, 0.12, 1)
    else
        border:SetColorTexture(unpack(PF.colors.bronzeBright))
    end

    local background = button:CreateTexture(nil, "BACKGROUND", nil, -1)
    background:SetPoint("TOPLEFT", 1, -1)
    background:SetPoint("BOTTOMRIGHT", -1, 1)
    background:SetColorTexture(0.025, 0.018, 0.012, 1)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:SetIcon(icon)

    if isDebuff and nativeOptions.showDispelBorder and button.AddDispelTypeTexture then
        -- Blizzard drives this texture from the protected aura's dispel type.
        -- It remains hidden for effects without a dispel type and never
        -- requires the add-on to inspect secret combat aura data.
        local dispelBorder = button:CreateTexture(nil, "OVERLAY", nil, 2)
        dispelBorder:SetPoint("CENTER", icon, "CENTER", 0, 0)
        dispelBorder:SetSize(iconSize * 1.25, iconSize * 1.25)
        button:AddDispelTypeTexture(dispelBorder, {
            showWhenHarmful = true,
            showWhenHelpful = false,
        })
        button.prettyFramesDispelBorder = dispelBorder
    end

    -- Let Blizzard drive the swipe and countdown directly from its protected
    -- aura duration object, just as it does for native nameplate auras.
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT")
    cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
    cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
    cooldown:SetReverse(true)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetDrawSwipe(true)
    cooldown:SetSwipeColor(0, 0, 0, 0.68)
    cooldown:SetHideCountdownNumbers(nativeOptions.showCountdownNumbers == false)
    button:SetDurationCooldown(cooldown)

    -- Stack counts must sit above the Cooldown child frame.
    local textOverlay = CreateFrame("Frame", nil, button)
    textOverlay:SetAllPoints(button)
    textOverlay:SetFrameLevel(cooldown:GetFrameLevel() + 1)
    textOverlay:EnableMouse(false)

    local count = textOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("BOTTOMRIGHT", -2, 2)
    if iconSize <= 16 then
        PF:ApplyBoldNumberFont(count, 7)
    else
        PF:ApplyBoldNumberFont(count)
    end
    button:SetApplicationCount(count, {})

    AddAuraToMasque(button, {
        Icon = icon,
        Cooldown = cooldown,
        Count = count,
        Border = border,
    })
end

local function CreateNativeAuraContainer(frame, kind, iconSize, nativeOptions)
    if not CustomAuraContainerGroupDefaultOptions then return nil end
    nativeOptions = nativeOptions or {}

    local isCompactAuraFrame = frame.unit == "pet"
        or (frame.unit and frame.unit:match("^party%d+$") ~= nil)
        or frame.isRaidFrame == true

    local holder = CreateFrame("Frame", nil, frame)
    holder:SetSize(iconSize, iconSize)
    holder:SetFrameLevel(frame:GetFrameLevel() + 24)
    holder:EnableMouse(false)
    if holder.SetClipsChildren then holder:SetClipsChildren(true) end

    local ok, container = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
    if not ok or not container then return nil end
    container:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    container:SetFlowLayoutAnchorPoint("TOPLEFT")
    container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
    container:SetFlowLayoutMaximumLineSize(nil)

    local function Initialize(button)
        InitializeNativeAuraButton(button, frame, iconSize, kind == "debuff", nativeOptions)
    end
    local layout = {
        elementSpacing = 4,
        lineSpacing = 4,
        elementWidth = iconSize,
        elementHeight = iconSize,
    }
    local holderGroupId

    if kind == "buff" and frame.isBossFrame then
        local options = {
            maxFrameCount = 3,
            candidateFilters = { isBossOrRoleAura = true },
            initializeFrame = Initialize,
            layout = layout,
        }
        if AuraContainerSortMethod then
            options.sortMethod = AuraContainerSortMethod.ImportantOnly
        end
        container:AddAuraGroup(BOSS_BUFF_GROUP, "HELPFUL", options)
        holderGroupId = BOSS_BUFF_GROUP
    elseif kind == "debuff" and frame.isBossFrame then
        local options = {
            maxFrameCount = 0,
            candidateFilters = { isFromPlayerOrPlayerPet = true },
            initializeFrame = Initialize,
            layout = layout,
        }
        if AuraContainerSortMethod then
            options.sortMethod = AuraContainerSortMethod.ExpirationOnly
                or AuraContainerSortMethod.ImportantOnly
        end
        container:AddAuraGroup(BOSS_DEBUFF_GROUP, "HARMFUL", options)
        holderGroupId = BOSS_DEBUFF_GROUP
    elseif kind == "buff" then
        local options = {
            maxFrameCount = nativeOptions.maxFrameCount or MAX_AURAS,
            initializeFrame = Initialize,
            layout = layout,
        }
        if isCompactAuraFrame and AuraContainerSortMethod then
            options.sortMethod = AuraContainerSortMethod.ImportantOnly
        end
        container:AddAuraGroup("prettyframes-buffs", "HELPFUL", options)
    elseif isCompactAuraFrame then
        -- Blizzard's unit-frame comparator promotes dispellable, boss, role,
        -- and other high-value debuffs without exposing restricted aura data
        -- to addon Lua during combat.
        local options = {
            maxFrameCount = nativeOptions.maxFrameCount or MAX_AURAS,
            initializeFrame = Initialize,
            layout = layout,
        }
        if AuraContainerSortMethod then
            options.sortMethod = AuraContainerSortMethod.UnitFrameDebuff
        end
        container:AddAuraGroup("prettyframes-party-debuffs", "HARMFUL", options)
    else
        -- Register player-owned effects first. The holder clips the combined
        -- groups to the configured three/six slots, so other debuffs fill only
        -- the space left after the player's effects.
        container:AddAuraGroup("prettyframes-player-debuffs", "HARMFUL", {
            maxFrameCount = MAX_AURAS,
            candidateFilters = { isFromPlayerOrPlayerPet = true },
            initializeFrame = Initialize,
            layout = layout,
        })
        container:AddAuraGroup("prettyframes-other-debuffs", "HARMFUL", {
            maxFrameCount = MAX_AURAS,
            candidateFilters = { isFromPlayerOrPlayerPet = false },
            initializeFrame = Initialize,
            layout = layout,
        })
    end

    container:SetUnit(frame.unit)
    container:SetEnabled(true)
    container.prettyFramesEnabled = true
    holder.container = container
    holder.iconSize = iconSize
    holder.groupId = holderGroupId
    return holder
end

local function CreateRaidDebuffContainer(frame, iconSize)
    if not CustomAuraContainerGroupDefaultOptions then return nil end

    local holder = CreateFrame("Frame", nil, frame)
    holder:SetSize(iconSize, iconSize)
    holder:SetFrameLevel(frame:GetFrameLevel() + 24)
    holder:EnableMouse(false)
    if holder.SetClipsChildren then holder:SetClipsChildren(true) end

    local ok, container = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
    if not ok or not container then return nil end
    container:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    container:SetFlowLayoutAnchorPoint("TOPLEFT")
    container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
    container:SetFlowLayoutMaximumLineSize(iconSize)

    local function Initialize(button)
        InitializeNativeAuraButton(button, frame, iconSize, true, {
            enableMouse = false,
            showDispelBorder = true,
        })
    end
    local groupOptions = GetGroupIndicatorOptions(frame)
    local showPrimary = not groupOptions or groupOptions.showDebuffs ~= false
    local showDispellable = not groupOptions or groupOptions.showDispellableDebuffs ~= false
    local filter = showDispellable and not showPrimary and "HARMFUL|RAID" or "HARMFUL"
    local candidateFilters = showPrimary and not showDispellable
        and { isBossOrRoleAura = true } or nil
    local options = {
        maxFrameCount = (showPrimary or showDispellable) and 1 or 0,
        candidateFilters = candidateFilters,
        initializeFrame = Initialize,
        layout = {
            elementSpacing = 0,
            lineSpacing = 0,
            elementWidth = iconSize,
            elementHeight = iconSize,
        },
    }
    if AuraContainerSortMethod then
        options.sortMethod = AuraContainerSortMethod.UnitFrameDebuff
    end
    container:AddAuraGroup(RAID_DEBUFF_GROUP, filter, options)

    container:SetUnit(frame.unit)
    container:SetEnabled(true)
    container.prettyFramesEnabled = true
    holder.container = container
    holder.iconSize = iconSize
    return holder
end

local function CreateRaidMaintenanceContainer(frame, iconSize)
    if not CustomAuraContainerGroupDefaultOptions then return nil end

    local holder = CreateFrame("Frame", nil, frame)
    holder:SetSize(iconSize * 3 + 2, iconSize)
    holder:SetFrameLevel(frame:GetFrameLevel() + 24)
    holder:EnableMouse(false)

    local ok, container = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
    if not ok or not container then return nil end
    container:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    container:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
    container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
    container:SetFlowLayoutMaximumLineSize(iconSize * 3 + 2)

    local layout = {
        elementSpacing = 1,
        lineSpacing = 1,
        elementWidth = iconSize,
        elementHeight = iconSize,
    }
    local function InitializeOwned(button)
        InitializeNativeAuraButton(button, frame, iconSize, false, {
            enableMouse = false,
            showCountdownNumbers = false,
            borderColor = { 0.30, 0.82, 0.38, 0.78 },
        })
    end
    local function InitializeExternal(button)
        InitializeNativeAuraButton(button, frame, iconSize, false, {
            enableMouse = false,
            showCountdownNumbers = false,
            borderColor = { 0.30, 0.62, 1.00, 0.78 },
        })
    end

    local ownedOptions = {
        maxFrameCount = 2,
        candidateFilters = {
            isFromPlayerOrPlayerPet = true,
            maxDuration = (GetGroupIndicatorOptions(frame) or {}).maintenanceDuration
                or (frame.isPartyFrame and 60 or 120),
        },
        initializeFrame = InitializeOwned,
        layout = {
            elementSpacing = layout.elementSpacing,
            lineSpacing = layout.lineSpacing,
            elementWidth = layout.elementWidth,
            elementHeight = layout.elementHeight,
            layoutIndex = 1,
        },
    }
    if AuraContainerSortMethod then
        ownedOptions.sortMethod = AuraContainerSortMethod.ExpirationOnly
            or AuraContainerSortMethod.ImportantOnly
    end
    container:AddAuraGroup(RAID_OWNED_MAINTENANCE_GROUP, "HELPFUL", ownedOptions)

    local externalOptions = {
        maxFrameCount = 1,
        candidateFilters = {
            isFromPlayerOrPlayerPet = false,
            isBossOrRoleAura = true,
        },
        initializeFrame = InitializeExternal,
        layout = {
            elementSpacing = layout.elementSpacing,
            lineSpacing = layout.lineSpacing,
            elementWidth = layout.elementWidth,
            elementHeight = layout.elementHeight,
            layoutIndex = 2,
        },
    }
    if AuraContainerSortMethod then
        externalOptions.sortMethod = AuraContainerSortMethod.ImportantOnly
    end
    container:AddAuraGroup(RAID_EXTERNAL_MAINTENANCE_GROUP, "HELPFUL", externalOptions)

    container:SetUnit(frame.unit)
    container:SetEnabled(true)
    container.prettyFramesEnabled = true
    holder.container = container
    holder.iconSize = iconSize
    return holder
end

local function CreateAuraIcons(frame, count, iconSize, mirrored)
    frame.auras = {}
    for index = 1, count do
        local aura = CreateFrame("Frame", nil, frame)
        aura:SetSize(iconSize, iconSize)
        aura:SetAlpha(0)
        if mirrored then
            aura:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -frame:GetWidth() * 0.79 + 15 - (index - 1) * (iconSize + 4), -frame:GetHeight() * 0.29 - 5)
        else
            aura:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", frame:GetWidth() * 0.79 - 15 + (index - 1) * (iconSize + 4), -frame:GetHeight() * 0.29 - 5)
        end
        aura:SetFrameLevel(frame:GetFrameLevel() + 25)
        local border = aura:CreateTexture(nil, "BACKGROUND", nil, -2)
        border:SetAllPoints(aura)
        border:SetColorTexture(unpack(PF.colors.bronzeBright))

        local background = aura:CreateTexture(nil, "BACKGROUND", nil, -1)
        background:SetPoint("TOPLEFT", 1, -1)
        background:SetPoint("BOTTOMRIGHT", -1, 1)
        background:SetColorTexture(0.025, 0.018, 0.012, 1)

        aura.icon = aura:CreateTexture(nil, "ARTWORK")
        aura.icon:SetPoint("TOPLEFT", 2, -2)
        aura.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        aura.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        aura.count = aura:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        aura.count:SetPoint("BOTTOMRIGHT", -2, 2)
        PF:ApplyBoldNumberFont(aura.count)
        AddAuraToMasque(aura, {
            Icon = aura.icon,
            Count = aura.count,
            Border = border,
        })
        frame.auras[index] = aura
    end
    frame.nativeBuffs = CreateNativeAuraContainer(frame, "buff", iconSize)
end

local function CreateDebuffIcons(frame, count, iconSize)
    frame.debuffs = {}
    for index = 1, count do
        local aura = CreateFrame("Frame", nil, frame)
        aura:SetSize(iconSize, iconSize)
        aura:SetAlpha(0)
        aura:SetFrameLevel(frame:GetFrameLevel() + 25)
        local border = aura:CreateTexture(nil, "BACKGROUND", nil, -2)
        border:SetAllPoints(aura)
        border:SetColorTexture(0.78, 0.18, 0.12, 1)

        local background = aura:CreateTexture(nil, "BACKGROUND", nil, -1)
        background:SetPoint("TOPLEFT", 1, -1)
        background:SetPoint("BOTTOMRIGHT", -1, 1)
        background:SetColorTexture(0.025, 0.018, 0.012, 1)

        aura.icon = aura:CreateTexture(nil, "ARTWORK")
        aura.icon:SetPoint("TOPLEFT", 2, -2)
        aura.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        aura.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        aura.count = aura:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        aura.count:SetPoint("BOTTOMRIGHT", -2, 2)
        PF:ApplyBoldNumberFont(aura.count)
        AddAuraToMasque(aura, {
            Icon = aura.icon,
            Count = aura.count,
            Border = border,
        })
        frame.debuffs[index] = aura
    end
    frame.nativeDebuffs = CreateNativeAuraContainer(frame, "debuff", iconSize)
end

local function LayoutAuraGroups(frame, mirrored, wideStart, compactStart, upperY, lowerY, upperShift)
    local buffsAreWide = frame.buffsAbove == true
    frame.buffDisplayLimit = frame.maxBuffs or frame.defaultMaxBuffs or 3
    frame.debuffDisplayLimit = frame.maxDebuffs or frame.defaultMaxDebuffs or 6

    local function LayoutGroup(group, isWide, limit)
        local start = isWide and wideStart or compactStart
        local y = isWide and upperY or lowerY
        local xShift = isWide and (upperShift or 0) or 0
        local perRow = isWide and 6 or 3
        for index, aura in ipairs(group or {}) do
            aura:ClearAllPoints()
            local column = (index - 1) % perRow
            local row = math.floor((index - 1) / perRow)
            local stride = aura:GetWidth() + 4
            local x = column * stride
            local rowY = y + row * stride
            if mirrored then
                aura:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -start + xShift - x, rowY)
            else
                aura:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", start + xShift + x, rowY)
            end
            if index > limit then
                aura:SetAlpha(0)
            end
        end
    end

    LayoutGroup(frame.auras, buffsAreWide, frame.buffDisplayLimit)
    LayoutGroup(frame.debuffs, not buffsAreWide, frame.debuffDisplayLimit)

    local function LayoutNative(holder, isWide, limit)
        if not holder then return end
        local start = isWide and wideStart or compactStart
        local y = isWide and upperY or lowerY
        local xShift = isWide and (upperShift or 0) or 0
        local iconSize = holder.iconSize
        local perRow = isWide and 6 or 3
        local columns = math.min(limit, perRow)
        local rows = limit > 0 and math.ceil(limit / perRow) or 0
        local stride = iconSize + 4
        holder:SetSize(math.max(1, columns * stride - 4), math.max(1, rows * stride - 4))
        holder:SetShown(limit > 0)
        holder:ClearAllPoints()
        holder.container:SetFlowLayoutMaximumLineSize(perRow * stride - 4)
        if mirrored then
            holder:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -start + xShift, y)
            holder.container:ClearAllPoints()
            holder.container:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
            holder.container:SetFlowLayoutAnchorPoint("BOTTOMRIGHT")
            holder.container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Up)
        else
            holder:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", start + xShift, y)
            holder.container:ClearAllPoints()
            holder.container:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
            holder.container:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
            holder.container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
        end
    end

    LayoutNative(frame.nativeBuffs, buffsAreWide, frame.buffDisplayLimit)
    LayoutNative(frame.nativeDebuffs, not buffsAreWide, frame.debuffDisplayLimit)
end

local COMPACT_AURA_DEFAULT_LIMIT = 5
local COMPACT_AURA_ICON_SIZE = 24
local COMPACT_AURA_SPACING = 4
local COMPACT_AURA_EDGE_OVERLAP = 14

local function LayoutCompactAuraRow(frame, displayFrames, nativeHolder, limit, yOffset, leftSide, edgeOverlap)
    local stride = COMPACT_AURA_ICON_SIZE + COMPACT_AURA_SPACING
    edgeOverlap = edgeOverlap or COMPACT_AURA_EDGE_OVERLAP
    for index, aura in ipairs(displayFrames or {}) do
        aura:ClearAllPoints()
        local step = (index - 1) * stride
        if leftSide then
            aura:SetPoint("TOPRIGHT", frame, "TOPLEFT", edgeOverlap - step, yOffset)
        else
            aura:SetPoint("TOPLEFT", frame, "TOPRIGHT", -edgeOverlap + step, yOffset)
        end
        if index > limit then
            aura:SetAlpha(0)
        end
    end

    if not nativeHolder then return end
    nativeHolder:SetSize(math.max(1, limit * stride - COMPACT_AURA_SPACING), COMPACT_AURA_ICON_SIZE)
    nativeHolder:SetShown(limit > 0)
    nativeHolder:ClearAllPoints()
    nativeHolder.container:ClearAllPoints()
    nativeHolder.container:SetFlowLayoutMaximumLineSize(nil)
    if leftSide then
        nativeHolder:SetPoint("TOPRIGHT", frame, "TOPLEFT", edgeOverlap, yOffset)
        nativeHolder.container:SetPoint("TOPRIGHT", nativeHolder, "TOPRIGHT", 0, 0)
        nativeHolder.container:SetFlowLayoutAnchorPoint("TOPRIGHT")
        nativeHolder.container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Down)
    else
        nativeHolder:SetPoint("TOPLEFT", frame, "TOPRIGHT", -edgeOverlap, yOffset)
        nativeHolder.container:SetPoint("TOPLEFT", nativeHolder, "TOPLEFT", 0, 0)
        nativeHolder.container:SetFlowLayoutAnchorPoint("TOPLEFT")
        nativeHolder.container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
    end
end

local function LayoutCompactAuras(frame, leftSide)
    frame.aurasLeft = leftSide == true
    frame.buffDisplayLimit = frame.maxBuffs or frame.defaultMaxBuffs or COMPACT_AURA_DEFAULT_LIMIT
    frame.debuffDisplayLimit = frame.maxDebuffs or frame.defaultMaxDebuffs or COMPACT_AURA_DEFAULT_LIMIT
    local buffY = frame.compactAuraBuffY or -33
    local debuffY = frame.compactAuraDebuffY or -61
    local edgeOverlap = frame.compactAuraActiveEdgeOverlap
        or frame.compactAuraEdgeOverlap
        or COMPACT_AURA_EDGE_OVERLAP
    LayoutCompactAuraRow(
        frame, frame.auras, frame.nativeBuffs, frame.buffDisplayLimit, buffY, frame.aurasLeft, edgeOverlap
    )
    LayoutCompactAuraRow(
        frame, frame.debuffs, frame.usePrimaryDebuffIndicator and nil or frame.nativeDebuffs,
        frame.debuffDisplayLimit, debuffY, frame.aurasLeft, edgeOverlap
    )
end

local previewBuffIcons = {
    "Interface\\Icons\\Spell_Nature_Rejuvenation",
    "Interface\\Icons\\Spell_Holy_GreaterHeal",
    "Interface\\Icons\\Ability_Druid_Maul",
    "Interface\\Icons\\Spell_Nature_LightningShield",
    "Interface\\Icons\\Spell_Holy_PowerWordShield",
    "Interface\\Icons\\Ability_Hunter_AspectMastery",
}

local previewDebuffIcons = {
    "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    "Interface\\Icons\\Spell_Frost_FrostNova",
    "Interface\\Icons\\Spell_Fire_Immolation",
    "Interface\\Icons\\Ability_PoisonSting",
    "Interface\\Icons\\Spell_Nature_CorrosiveBreath",
    "Interface\\Icons\\Ability_Creature_Disease_05",
}

local function DisplayAura(auraFrame, aura, previewIcon, previewCount)
    if previewIcon then
        auraFrame.icon:SetTexture(previewIcon)
        auraFrame.count:SetText(previewCount or "")
        auraFrame:SetAlpha(1)
    elseif aura then
        auraFrame.icon:SetTexture(aura.icon)
        local applications = aura.applications
        if PF:IsDisplaySafe(applications) and applications > 1 then
            auraFrame.count:SetText(applications)
        else
            auraFrame.count:SetText("")
        end
        auraFrame:SetAlpha(1)
    else
        auraFrame:SetAlpha(0)
    end
end

local function GetAuraDataByIndexSafe(unit, index, filter)
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return nil end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
    return ok and aura or nil
end

local function IsPlayerOwnedDebuff(aura)
    local owned = aura.isFromPlayerOrPlayerPet
    if PF:IsDisplaySafe(owned) and owned == true then
        return true
    end
    local sourceUnit = aura.sourceUnit
    if PF:IsDisplaySafe(sourceUnit) and sourceUnit then
        local sameUnit = UnitIsUnit(sourceUnit, "player")
        return PF:IsDisplaySafe(sameUnit) and sameUnit == true
    end
    return false
end

function PF:UpdateAuras(frame)
    local useNative = not self.testMode
    local groupOptions
    if frame.isRaidFrame then
        groupOptions = self.db and self.db.raidLayout
    elseif frame.isPartyFrame and frame.nativeDebuffs then
        groupOptions = self.db and self.db.partyLayout
    end
    local function SetHolderEnabled(holder, enabled)
        local container = holder and holder.container
        if container and container.prettyFramesEnabled ~= enabled then
            container:SetEnabled(enabled)
            container.prettyFramesEnabled = enabled
        end
    end
    SetHolderEnabled(frame.nativeBuffs, useNative)
    SetHolderEnabled(frame.nativeDebuffs, useNative and (not groupOptions
        or groupOptions.showDebuffs ~= false
        or groupOptions.showDispellableDebuffs ~= false))
    SetHolderEnabled(frame.nativeMaintenance, useNative and (not groupOptions
        or groupOptions.showMaintenance ~= false))

    if frame.auras then
        local limit = frame.buffDisplayLimit or #frame.auras
        for index, auraFrame in ipairs(frame.auras) do
            if index > limit then
                auraFrame:SetAlpha(0)
            elseif self.testMode then
                local previewIndex = ((index - 1) % #previewBuffIcons) + 1
                DisplayAura(auraFrame, nil, previewBuffIcons[previewIndex], index == 2 and "2" or "")
            elseif frame.nativeBuffs then
                auraFrame:SetAlpha(0)
            else
                local aura = GetAuraDataByIndexSafe(frame.unit, index, "HELPFUL")
                DisplayAura(auraFrame, aura)
            end
        end
    end

    if not frame.debuffs then return end
    local debuffLimit = frame.debuffDisplayLimit or #frame.debuffs
    if self.testMode then
        for index, auraFrame in ipairs(frame.debuffs) do
            if index > debuffLimit then
                auraFrame:SetAlpha(0)
            else
                local previewIndex = ((index - 1) % #previewDebuffIcons) + 1
                DisplayAura(auraFrame, nil, previewDebuffIcons[previewIndex], index == 1 and "3" or "")
            end
        end
        return
    end

    if frame.nativeDebuffs then
        for _, auraFrame in ipairs(frame.debuffs) do auraFrame:SetAlpha(0) end
        return
    end

    local playerOwned, other = {}, {}
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for index = 1, 40 do
            local aura = GetAuraDataByIndexSafe(frame.unit, index, "HARMFUL")
            if not aura then break end
            table.insert(IsPlayerOwnedDebuff(aura) and playerOwned or other, aura)
        end
    end

    local ordered = {}
    for _, aura in ipairs(playerOwned) do table.insert(ordered, aura) end
    for _, aura in ipairs(other) do table.insert(ordered, aura) end
    for index, auraFrame in ipairs(frame.debuffs) do
        if index > debuffLimit then
            auraFrame:SetAlpha(0)
        else
            DisplayAura(auraFrame, ordered[index])
        end
    end
end

function PF:RefreshNativeAuras(frame)
    for _, holder in ipairs({ frame.nativeBuffs, frame.nativeDebuffs, frame.nativeMaintenance }) do
        if holder and holder.container and holder.container.prettyFramesEnabled then
            holder.container:UpdateAllAuras()
        end
    end
end

Auras.CreateAuraIcons = CreateAuraIcons
Auras.CreateDebuffIcons = CreateDebuffIcons
Auras.CreateRaidDebuffContainer = CreateRaidDebuffContainer
Auras.CreateRaidMaintenanceContainer = CreateRaidMaintenanceContainer
Auras.LayoutAuraGroups = LayoutAuraGroups
Auras.LayoutCompactAuras = LayoutCompactAuras
