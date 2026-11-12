local _, PF = ...

-- Class resources are deliberately described independently from their visual
-- treatment. A theme opts into primitive kinds; otherwise PrettyFrames tries
-- to preserve the matching Blizzard widget without emulating it.
local POWER = {
    MANA = 0,
    ENERGY = 3,
    COMBO_POINTS = 4,
    SOUL_SHARDS = 7,
    HOLY_POWER = 9,
    CHI = 12,
    ARCANE_CHARGES = 16,
    ESSENCE = 19,
}

local SOUL_SHARD_ITEM_ID = 6265

local COLORS = {
    combo = { 1.00, 0.82, 0.18 },
    soulShards = { 0.62, 0.24, 0.86 },
    ammo = { 0.66, 0.86, 0.38 },
    holyPower = { 0.96, 0.91, 0.55 },
    chi = { 0.35, 0.95, 0.72 },
    arcaneCharges = { 0.35, 0.62, 1.00 },
    essence = { 0.25, 0.78, 1.00 },
    runes = { 0.30, 0.72, 1.00 },
    mana = { 0.08, 0.38, 0.92 },
    stagger = { 0.96, 0.55, 0.16 },
    totems = { 0.92, 0.64, 0.24 },
}

-- Forever keeps several materially distinct arrow types in the ammo slot.
-- Tint the grayscale arrowhead asset by the equipped item rather than using
-- the Hunter resource color. Deprecated client records are included because
-- they can still appear on copied or test characters.
local AMMO_COLORS = {
    [2512] = { 0.72, 0.52, 0.30 },   -- Rough Arrow: wood and hide
    [2514] = { 0.70, 0.66, 0.55 },   -- Depricated Sharp Arrow
    [2515] = { 0.84, 0.79, 0.64 },   -- Sharp Arrow: pale iron
    [3029] = { 0.58, 0.72, 0.34 },   -- Depricated Whipwood Arrow
    [3030] = { 0.78, 0.84, 0.90 },   -- Razor Arrow: polished steel
    [3031] = { 0.70, 0.79, 0.86 },   -- Depricated Razor Arrow
    [3464] = { 0.95, 0.82, 0.42 },   -- Feathered Arrow: warm gold
    [9399] = { 0.38, 0.92, 0.48 },   -- Precision Arrow: sighting green
    [10579] = { 1.00, 0.36, 0.08 },  -- Explosive Arrow
    [11285] = { 0.78, 0.42, 0.30 },  -- Jagged Arrow: dark, worn steel
    [12654] = { 0.58, 0.28, 0.82 },  -- Doomshot: shadow violet
    [18042] = { 0.55, 0.78, 0.95 },  -- Thorium Headed Arrow: blue steel
    [19316] = { 0.30, 0.90, 1.00 },  -- Ice Threaded Arrow
    [231806] = { 1.00, 0.20, 0.04 }, -- Searing Arrow
    [274387] = { 0.92, 0.48, 1.00 }, -- Swiftfeather Arrow: epic wind violet
}

local DEFAULT_AMMO_COLOR = { 0.80, 0.78, 0.70 }

local DEFINITIONS = {
    ROGUE = {
        key = "combo", kind = "points", power = POWER.COMBO_POINTS,
        defaultMax = 5, attach = "target", native = { "ComboFrame" },
    },
    PALADIN = {
        key = "holyPower", kind = "points", power = POWER.HOLY_POWER,
        defaultMax = 5, native = { "PaladinPowerBarFrame" },
    },
    WARLOCK = {
        key = "soulShards", kind = "points", power = POWER.SOUL_SHARDS,
        defaultMax = 5, native = { "WarlockPowerFrame" },
    },
    MAGE = {
        key = "arcaneCharges", kind = "points", power = POWER.ARCANE_CHARGES,
        defaultMax = 4, native = { "MageArcaneChargesFrame" },
    },
    EVOKER = {
        key = "essence", kind = "points", power = POWER.ESSENCE,
        defaultMax = 6, native = { "EssencePlayerFrame" },
    },
    DEATHKNIGHT = {
        key = "runes", kind = "runes", defaultMax = 6,
        native = { "RuneFrame" },
    },
    SHAMAN = {
        key = "totems", kind = "totems", defaultMax = 4,
        native = { "TotemFrame" },
    },
}

local NATIVE_CLASS_FRAMES = {
    DRUID = { "DruidComboPointBarFrame", "ComboFrame" },
    MONK = { "MonkHarmonyBarFrame", "MonkStaggerBar" },
}

-- Test definitions are intentionally independent of the logged-in class.
-- They exercise every resource primitive used by Forever plus a six-point
-- stress case for validating portrait-arc spacing.
local TEST_DEFINITIONS = {
    combo = {
        label = "Combo Points (5)",
        key = "combo", kind = "points", power = POWER.COMBO_POINTS,
        defaultMax = 5, attach = "target",
    },
    combo6 = {
        label = "Jewel Spacing (6)",
        key = "combo", kind = "points", power = POWER.COMBO_POINTS,
        defaultMax = 6, attach = "target",
    },
    shards = {
        label = "Soul Shard Count",
        key = "soulShards", kind = "itemCount", previewCount = 12,
    },
    ammo = {
        label = "Hunter Ammunition",
        key = "ammo", kind = "itemCount", previewCount = 1200,
        activeAsset = "classResourceAmmoActive",
        emptyAsset = "classResourceAmmoEmpty",
        showPointFrame = false,
        layoutKey = "ammo",
    },
    runes = {
        label = "Death Knight Runes",
        key = "runes", kind = "runes", defaultMax = 6,
    },
    totems = {
        label = "Shaman Totems",
        key = "totems", kind = "totems", defaultMax = 4,
    },
    mana = {
        label = "Druid Secondary Mana",
        key = "mana", kind = "bar", power = POWER.MANA, defaultMax = 100,
    },
    druid = {
        label = "Druid Combo Points + Mana",
        key = "combo", kind = "points", power = POWER.COMBO_POINTS,
        defaultMax = 5, attach = "target",
    },
}

local TEST_RESOURCE_ORDER = { "combo", "combo6", "shards", "ammo", "runes", "totems", "mana", "druid" }

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function SafeNumber(value, fallback)
    if type(value) == "number" and not IsSecret(value) then return value end
    return fallback
end

local function GetSpecID()
    if not GetSpecialization or not GetSpecializationInfo then return nil end
    local index = GetSpecialization()
    if not index then return nil end
    return GetSpecializationInfo(index)
end

local function ResolveDefinition(testMode)
    if testMode and PF.testClassResourceKey then
        return TEST_DEFINITIONS[PF.testClassResourceKey]
    end
    local _, class = UnitClass("player")
    if not class then return nil end
    if not testMode and UnitHasVehicleUI then
        local inVehicle = UnitHasVehicleUI("player")
        if not IsSecret(inVehicle) and inVehicle then return nil end
    end

    if class == "DRUID" then
        local displayedPower = SafeNumber(UnitPowerType("player"), POWER.MANA)
        if displayedPower == POWER.ENERGY then
            local comboMax = SafeNumber(UnitPowerMax("player", POWER.COMBO_POINTS), 5)
            return {
                key = "combo", kind = "points", power = POWER.COMBO_POINTS,
                defaultMax = comboMax > 0 and comboMax or 5, attach = "target",
                native = NATIVE_CLASS_FRAMES.DRUID,
            }
        end
        local manaMax = SafeNumber(UnitPowerMax("player", POWER.MANA), 0)
        if manaMax > 0 and displayedPower ~= POWER.MANA then
            return {
                key = "mana", kind = "bar", power = POWER.MANA,
                defaultMax = manaMax, native = { "DruidManaBar" },
            }
        end
        return nil
    elseif class == "MONK" then
        if GetSpecID() == 268 then
            return {
                key = "stagger", kind = "bar", stagger = true, defaultMax = 100,
                native = { "MonkStaggerBar" },
            }
        end
        local chiMax = SafeNumber(UnitPowerMax("player", POWER.CHI), 0)
        if chiMax > 0 then
            return {
                key = "chi", kind = "points", power = POWER.CHI,
                defaultMax = chiMax > 0 and chiMax or 5,
                native = NATIVE_CLASS_FRAMES.MONK,
            }
        end
        return nil
    elseif class == "WARLOCK" then
        local shardMax = SafeNumber(UnitPowerMax("player", POWER.SOUL_SHARDS), 0)
        if shardMax > 0 then
            return DEFINITIONS.WARLOCK
        end
        -- Forever keeps Soul Shards as physical, non-stacking inventory
        -- items rather than UnitPower. One counted jewel represents the
        -- complete carried supply, including a Soul Bag in the reagent slot.
        return {
            key = "soulShards", kind = "itemCount",
            itemID = SOUL_SHARD_ITEM_ID, previewCount = 12,
            native = { "WarlockPowerFrame" },
        }
    elseif class == "HUNTER" then
        return {
            key = "ammo", kind = "itemCount",
            inventorySlot = INVSLOT_AMMO or 0, previewCount = 1200,
            activeAsset = "classResourceAmmoActive",
            emptyAsset = "classResourceAmmoEmpty",
            showPointFrame = false,
            layoutKey = "ammo",
        }
    end

    local definition = DEFINITIONS[class]
    if not definition then return nil end
    if definition.power then
        local maximum = SafeNumber(UnitPowerMax("player", definition.power), 0)
        if maximum <= 0 then return nil end
    end
    return definition
end

local function ResolveDruidSecondaryMana(testMode)
    if testMode and PF.testClassResourceKey then
        if PF.testClassResourceKey ~= "druid" then return nil end
        return {
            key = "mana", kind = "bar", power = POWER.MANA,
            defaultMax = 100, native = { "DruidManaBar" },
        }
    end

    local _, class = UnitClass("player")
    if class ~= "DRUID" then return nil end
    if not testMode and UnitHasVehicleUI then
        local inVehicle = UnitHasVehicleUI("player")
        if not IsSecret(inVehicle) and inVehicle then return nil end
    end
    local displayedPower = SafeNumber(UnitPowerType("player"), POWER.MANA)
    local manaMax = SafeNumber(UnitPowerMax("player", POWER.MANA), 0)
    if displayedPower == POWER.ENERGY and manaMax > 0 then
        return {
            key = "mana", kind = "bar", power = POWER.MANA,
            defaultMax = manaMax, native = { "DruidManaBar" },
        }
    end
    return nil
end

function PF:SetClassResourceTest(resourceKey)
    if InCombatLockdown() then
        self:Print("class-resource test cannot change during combat.")
        return false
    end

    resourceKey = resourceKey and resourceKey:lower() or "next"
    if resourceKey == "auto" or resourceKey == "current" then
        self.testClassResourceKey = nil
    elseif resourceKey == "next" then
        local nextIndex = 1
        for index, key in ipairs(TEST_RESOURCE_ORDER) do
            if key == self.testClassResourceKey then
                nextIndex = index % #TEST_RESOURCE_ORDER + 1
                break
            end
        end
        self.testClassResourceKey = TEST_RESOURCE_ORDER[nextIndex]
    elseif TEST_DEFINITIONS[resourceKey] then
        self.testClassResourceKey = resourceKey
    else
        self:Print("use /pf test resource combo|combo6|shards|ammo|runes|totems|mana|druid|next|auto")
        return false
    end

    if not self.testMode then
        self:SetTestMode(true, true)
    else
        self:UpdateClassResourceDisplay(true)
    end

    local definition = self.testClassResourceKey and TEST_DEFINITIONS[self.testClassResourceKey]
    self:Print(definition and ("class-resource preview: " .. definition.label .. ".")
        or "class-resource preview follows the current character.")
    return true
end

local function CreateBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.035, 0.022, 0.012, 0.96)
    frame:SetBackdropBorderColor(unpack(PF.colors.bronzeBright))
end

local function ShowItemCountTooltip(segment)
    local definition = segment.itemTooltipDefinition
    if not definition then return end

    GameTooltip:SetOwner(segment, "ANCHOR_RIGHT")
    if definition.inventorySlot and GameTooltip.SetInventoryItem then
        local hasItem = GameTooltip:SetInventoryItem("player", definition.inventorySlot)
        if hasItem then
            GameTooltip:Show()
        else
            GameTooltip:Hide()
        end
    elseif definition.itemID then
        if GameTooltip.SetItemByID then
            GameTooltip:SetItemByID(definition.itemID)
        else
            GameTooltip:SetHyperlink("item:" .. definition.itemID)
        end
        GameTooltip:Show()
    end
end

local function SetItemCountTooltip(segment, definition)
    segment.itemTooltipDefinition = definition
    local enabled = definition ~= nil
    if segment.EnableMouseMotion then
        segment:EnableMouseMotion(enabled)
        if segment.EnableMouseClick then segment:EnableMouseClick(false) end
    else
        segment:EnableMouse(enabled)
    end
    if not enabled and GameTooltip.IsOwned and GameTooltip:IsOwned(segment) then
        GameTooltip:Hide()
    end
end

local function CreateSegment(parent)
    local segment = CreateFrame("StatusBar", nil, parent, "BackdropTemplate")
    CreateBackdrop(segment)
    segment:SetBackdropColor(0, 0, 0, 0)
    segment:SetBackdropBorderColor(0, 0, 0, 0)
    segment:SetStatusBarTexture(PF:ThemeFrameAsset("classResources", "statusBar", "statusBar"))
    segment:SetMinMaxValues(0, 1)
    segment:SetValue(0)
    segment.mask = segment:CreateMaskTexture()
    segment.mask:SetAllPoints(segment)
    segment.mask:SetTexture(
        "Interface\\CharacterFrame\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE"
    )
    segment:GetStatusBarTexture():AddMaskTexture(segment.mask)
    segment.empty = segment:CreateTexture(nil, "BACKGROUND")
    segment.empty:SetAllPoints(segment)
    segment.empty:SetColorTexture(0.025, 0.016, 0.010, 0.96)
    segment.empty:AddMaskTexture(segment.mask)
    segment.cooldown = CreateFrame("Cooldown", nil, segment, "CooldownFrameTemplate")
    segment.cooldown:SetAllPoints(segment)
    segment.cooldown:SetDrawEdge(false)
    segment.cooldown:SetDrawBling(false)
    segment.cooldown:Hide()
    segment.art = segment:CreateTexture(nil, "OVERLAY", nil, 7)
    segment.art:SetAllPoints(segment)
    segment.art:SetTexture(PF:ThemeFrameAsset(
        "classResources", "classResourcePointFrame", "classResourcePointFrame"
    ))
    segment.countText = segment:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
    segment.countText:SetPoint("CENTER", segment, "CENTER", 0, 0)
    segment.countText:SetDrawLayer("OVERLAY", 8)
    segment.countText:SetTextColor(1, 1, 1, 1)
    segment.countText:SetShadowColor(0, 0, 0, 1)
    segment.countText:SetShadowOffset(1, -1)
    segment.countText:Hide()
    segment:SetScript("OnEnter", ShowItemCountTooltip)
    segment:SetScript("OnLeave", function(widget)
        if not GameTooltip.IsOwned or GameTooltip:IsOwned(widget) then GameTooltip:Hide() end
    end)
    return segment
end

local function CreateDisplay(layout, globalName)
    local holder = CreateFrame("Frame", globalName, UIParent)
    holder:SetFrameStrata("MEDIUM")
    holder:SetFrameLevel(90)
    holder:EnableMouse(false)
    holder.layout = layout
    holder.segments = {}
    for index = 1, 10 do
        holder.segments[index] = CreateSegment(holder)
    end

    holder.bar = CreateFrame("StatusBar", nil, holder, "BackdropTemplate")
    CreateBackdrop(holder.bar)
    holder.bar:SetBackdropBorderColor(0, 0, 0, 0)
    holder.bar:SetStatusBarTexture(PF:ThemeFrameAsset("classResources", "statusBar", "statusBar"))
    holder.bar:SetMinMaxValues(0, 1)
    holder.bar:SetValue(0)
    holder.bar.art = holder.bar:CreateTexture(nil, "OVERLAY", nil, 7)
    holder.bar.art:SetTexture(PF:ThemeFrameAsset(
        "classResources", "classResourceBarFrame", "classResourceBarFrame"
    ))
    holder.bar.text = holder.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    holder.bar.text:SetAllPoints(holder.bar)
    holder.bar.text:SetDrawLayer("OVERLAY", 8)
    holder.bar.text:SetTextColor(1, 0.96, 0.84)
    PF:ApplyBoldNumberFont(holder.bar.text, 9)
    holder.bar.ownerDisplay = holder
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    holder.bar:EnableMouse(not PF.db.locked)
    holder.bar:RegisterForDrag("LeftButton")
    holder.bar:SetScript("OnDragStart", function()
        local setting = PF:GetFrameSetting("player")
        if setting.classResourceIndependent and not PF.db.locked and not InCombatLockdown() then
            holder:StartMoving()
        end
    end)
    holder.bar:SetScript("OnDragStop", function()
        holder:StopMovingOrSizing()
        PF:SaveClassResourcePosition(holder)
    end)
    holder.bar:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton == "RightButton" and not PF.db.locked then
            PF:OpenClassResourceContextMenu(holder)
        end
    end)
    holder.bar:Hide()

    holder.totems = {}
    for index = 1, 4 do
        local totem = CreateFrame("Frame", nil, holder, "BackdropTemplate")
        CreateBackdrop(totem)
        totem:SetBackdropColor(0, 0, 0, 0)
        totem:SetBackdropBorderColor(0, 0, 0, 0)
        totem.icon = totem:CreateTexture(nil, "ARTWORK")
        local iconInset = layout.totemIconInset or 5
        totem.icon:SetPoint("TOPLEFT", iconInset, -iconInset)
        totem.icon:SetPoint("BOTTOMRIGHT", -iconInset, iconInset)
        totem.cooldown = CreateFrame("Cooldown", nil, totem, "CooldownFrameTemplate")
        totem.cooldown:SetAllPoints(totem.icon)
        totem.cooldown:SetDrawEdge(false)
        totem.cooldown:SetDrawBling(false)
        totem.art = totem:CreateTexture(nil, "OVERLAY", nil, 7)
        totem.art:SetAllPoints(totem)
        totem.art:SetTexture(PF:ThemeFrameAsset(
            "classResources", "classResourceTotemFrame", "classResourceTotemFrame"
        ))
        holder.totems[index] = totem
    end
    holder:Hide()
    return holder
end

function PF:SaveClassResourcePosition(display)
    if not display then return end
    local x, y = display:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not x or not y or not parentX or not parentY then return end
    self:GetFrameSetting("player").classResourcePosition = { x - parentX, y - parentY }
end

function PF:OpenClassResourceContextMenu(display)
    if InCombatLockdown() then return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        self:Print("the class-resource menu is unavailable on this client build.")
        return
    end
    if not display or not display.currentDefinition
        or display.currentDefinition.kind ~= "bar" then return end

    local setting = self:GetFrameSetting("player")
    MenuUtil.CreateContextMenu(display.bar, function(_, rootDescription)
        rootDescription:CreateTitle("Secondary Resource Bar")
        rootDescription:CreateTitle("Positioning")
        local function IsPositioningSelected(value)
            return (setting.classResourceIndependent == true) == (value == "independent")
        end
        local function SetPositioning(value)
            local independent = value == "independent"
            if independent == (setting.classResourceIndependent == true) then return end
            if independent then
                -- Preserve the user's last independent location when the bar
                -- is temporarily attached again. Seed it from the attached
                -- position only the first time independent mode is enabled.
                if not setting.classResourcePosition then
                    PF:SaveClassResourcePosition(display)
                end
                setting.classResourceIndependent = true
            else
                PF:SaveClassResourcePosition(display)
                setting.classResourceIndependent = false
            end
            PF:UpdateClassResourceDisplay(true)
        end
        rootDescription:CreateRadio("Attached to Frame", IsPositioningSelected, SetPositioning, "attached")
        rootDescription:CreateRadio("Independent", IsPositioningSelected, SetPositioning, "independent")
    end)
end

local function HideCustom(display)
    if not display then return end
    display:Hide()
    display.bar:Hide()
    for _, segment in ipairs(display.segments) do
        segment:Hide()
        SetItemCountTooltip(segment, nil)
    end
    for _, totem in ipairs(display.totems) do totem:Hide() end
end

local function SaveNativePlacement(frame)
    if frame.prettyFramesOriginalPlacement then return end
    local placement = { parent = frame:GetParent(), points = {} }
    for index = 1, frame:GetNumPoints() do
        placement.points[index] = { frame:GetPoint(index) }
    end
    frame.prettyFramesOriginalPlacement = placement
end

local function RestoreNativeFrame(frame)
    local placement = frame and frame.prettyFramesOriginalPlacement
    if not placement then return end
    pcall(frame.SetParent, frame, placement.parent)
    frame:ClearAllPoints()
    for _, point in ipairs(placement.points) do
        pcall(frame.SetPoint, frame, unpack(point))
    end
    frame:SetAlpha(1)
    frame.prettyFramesUsedAsFallback = nil
end

function PF:RestoreNativeClassResource()
    if self.nativeClassResourceFrame then
        RestoreNativeFrame(self.nativeClassResourceFrame)
        self.nativeClassResourceFrame = nil
    end
end

function PF:RestoreSuppressedClassResources()
    self.customClassResourceActive = nil
    for frame in pairs(self.classResourceSuppressedFrames or {}) do
        if frame and frame.SetAlpha and not frame.prettyFramesUsedAsFallback then
            frame:SetAlpha(1)
        end
    end
    self.classResourceSuppressedFrames = setmetatable({}, { __mode = "k" })
end

function PF:SuppressNativeClassResource(definition)
    self.classResourceSuppressedFrames = self.classResourceSuppressedFrames
        or setmetatable({}, { __mode = "k" })
    self.customClassResourceActive = true
    for _, name in ipairs(definition.native or {}) do
        local native = _G[name]
        local forbidden = native and native.IsForbidden and native:IsForbidden()
        if native and native.SetAlpha and not forbidden then
            native:SetAlpha(0)
            self.classResourceSuppressedFrames[native] = true
            if not native.prettyFramesClassResourceHooked then
                native.prettyFramesClassResourceHooked = true
                hooksecurefunc(native, "SetAlpha", function(widget)
                    if PF.customClassResourceActive
                        and PF.classResourceSuppressedFrames
                        and PF.classResourceSuppressedFrames[widget]
                        and widget:GetAlpha() ~= 0 then
                        widget:SetAlpha(0)
                    end
                end)
            end
        end
    end
end

function PF:TryNativeClassResource(definition)
    if self.nativeClassResourceFrame and self.activeClassResource
        and self.activeClassResource.key == definition.key then
        return true
    end
    self:RestoreNativeClassResource()
    self:RestoreSuppressedClassResources()
    if not definition then return false end
    local owner = definition.attach == "target" and self.frames.target or self.frames.player
    if not owner then return false end
    for _, name in ipairs(definition.native or {}) do
        local native = _G[name]
        local forbidden = native and native.IsForbidden and native:IsForbidden()
        if native and native.SetParent and not forbidden then
            SaveNativePlacement(native)
            local moved = pcall(function()
                native:SetParent(owner)
                native:ClearAllPoints()
                native:SetPoint("BOTTOM", owner, "TOP", 0, 6)
                native:SetAlpha(1)
                native.prettyFramesUsedAsFallback = true
            end)
            if moved then
                self.nativeClassResourceFrame = native
                return true
            end
            RestoreNativeFrame(native)
        end
    end
    return false
end

local function SetColor(widget, color)
    widget:SetStatusBarColor(color[1], color[2], color[3], 1)
end

local function GetPointMaximum(display, definition, preview)
    local maximum = preview and definition.defaultMax
        or SafeNumber(UnitPowerMax("player", definition.power), definition.defaultMax)
    return math.max(1, math.min(#display.segments, maximum or definition.defaultMax))
end

local function LayoutDisplay(display, definition, preview)
    local layout = display.layout
    local owner = definition.attach == "target" and PF.frames.target or PF.frames.player
    if not owner then return false end
    display:SetParent(owner)
    -- SetParent can recalculate frame levels. Keep class resources above the
    -- unit-frame skin and text layers after attaching them to their owner.
    display:SetFrameStrata(owner:GetFrameStrata())
    display:SetFrameLevel(owner:GetFrameLevel() + 30)
    for _, segment in ipairs(display.segments) do
        segment:SetFrameLevel(display:GetFrameLevel() + 1)
    end
    display.bar:SetFrameLevel(display:GetFrameLevel() + 1)
    for _, totem in ipairs(display.totems) do
        totem:SetFrameLevel(display:GetFrameLevel() + 1)
    end
    display:ClearAllPoints()

    local arcRadius = layout.pointResourceArcRadius or layout.comboPointArcRadius
    local resourceLayoutKey = definition.layoutKey
    local totemArc = definition.kind == "totems"
        and layout.totemArcPositions and owner.portrait
    local portraitArc = (definition.kind == "points" or definition.kind == "itemCount")
        and arcRadius and owner.portrait
    local resourceSetting = definition.kind == "bar" and PF:GetFrameSetting("player")
    local independentBar = resourceSetting and resourceSetting.classResourceIndependent
        and resourceSetting.classResourcePosition
    if independentBar then
        display:SetPoint(
            "CENTER", UIParent, "CENTER",
            resourceSetting.classResourcePosition[1],
            resourceSetting.classResourcePosition[2]
        )
    elseif totemArc then
        display:SetPoint("CENTER", owner.portrait, "CENTER")
    elseif definition.kind == "totems" and layout.totemPoint and owner.portrait then
        PF:SetThemePoint(display, owner.portrait, layout.totemPoint)
    elseif definition.kind == "bar" and layout.barPoint then
        local mirrored = owner.isMirrored or owner.currentFlipped
        local point = mirrored
            and (layout.barMirrorPoint or PF:MirrorThemePoint(layout.barPoint))
            or layout.barPoint
        PF:SetThemePoint(display, owner, point)
    elseif portraitArc then
        local offset = definition.kind == "itemCount"
            and ((resourceLayoutKey and layout[resourceLayoutKey .. "Offset"])
                or layout.itemCountOffset or layout.pointResourceOffset)
            or (definition.key == "combo"
                and (layout.comboPointOffset or layout.pointResourceOffset)
                or layout.pointResourceOffset)
        offset = offset or { 0, 0 }
        display:SetPoint("CENTER", owner.portrait, "CENTER", offset[1], offset[2])
    else
        PF:SetThemePoint(
            display,
            owner,
            definition.attach == "target" and layout.targetPoint or layout.playerPoint
        )
    end

    local count = definition.kind == "totems" and 4
        or (definition.kind == "points" and GetPointMaximum(display, definition, preview))
        or (definition.kind == "itemCount" and 1)
        or definition.defaultMax or 6
    local size = definition.kind == "totems" and layout.totemSize
        or (definition.kind == "itemCount"
            and ((resourceLayoutKey and layout[resourceLayoutKey .. "Size"])
                or layout.itemCountSize))
        or (portraitArc and (layout.pointResourceSize or layout.comboPointSize))
        or layout.pointSize
    local spacing = definition.kind == "totems" and layout.totemSpacing or layout.pointSpacing
    if portraitArc then
        local radius = arcRadius
        local horizontalRadius = layout.pointResourceArcRadiusX
            or layout.comboPointArcRadiusX or radius
        local arcSpacing = layout.pointResourceArcSpacing
            or layout.comboPointArcSpacing or spacing
        local chord = math.min(radius * 2, size + arcSpacing)
        local angleStep = math.deg(2 * math.asin(chord / (radius * 2)))
        local centerAngle = definition.kind == "itemCount"
            and ((resourceLayoutKey and layout[resourceLayoutKey .. "ArcAngle"])
                or layout.itemCountArcAngle or layout.pointResourceArcAngle)
            or (count >= 6 and layout.sixPointArcAngle)
            or layout.pointResourceArcAngle
            or layout.comboPointArcAngle or 60
        local startAngle = centerAngle + angleStep * (count - 1) / 2
        local xDirection = (owner.isMirrored or owner.currentFlipped) and 1 or -1

        display:SetSize(owner.portrait:GetSize())
        for index, segment in ipairs(display.segments) do
            segment:ClearAllPoints()
            segment:SetSize(size, size)
            if index <= count then
                local angle = math.rad(startAngle - angleStep * (index - 1))
                segment:SetPoint(
                    "CENTER",
                    display,
                    "CENTER",
                    math.cos(angle) * horizontalRadius * xDirection,
                    math.sin(angle) * radius
                )
            else
                segment:SetPoint("CENTER", display, "CENTER")
            end
        end
    elseif totemArc then
        display:SetSize(owner.portrait:GetSize())
        for _, segment in ipairs(display.segments) do
            segment:ClearAllPoints()
            segment:SetSize(size, size)
            segment:SetPoint("CENTER", display, "CENTER")
        end
    elseif definition.kind == "bar" then
        display:SetSize(unpack(layout.barArtSize or layout.barSize))
        for _, segment in ipairs(display.segments) do
            segment:ClearAllPoints()
            segment:SetSize(size, size)
            segment:SetPoint("CENTER", display, "CENTER")
        end
    else
        display:SetSize(count * size + math.max(0, count - 1) * spacing, size)
        for index, segment in ipairs(display.segments) do
            segment:ClearAllPoints()
            segment:SetSize(size, size)
            segment:SetPoint("LEFT", display, "LEFT", (index - 1) * (size + spacing), 0)
        end
    end
    for index, totem in ipairs(display.totems) do
        totem:ClearAllPoints()
        totem:SetSize(size, size)
        totem.art:SetShown(layout.showTotemFrame ~= false)
        if totemArc then
            local position = layout.totemArcPositions[index]
            local mirrored = owner.isMirrored or owner.currentFlipped
            totem:SetPoint(
                "CENTER", display, "CENTER",
                mirrored and -position[1] or position[1], position[2]
            )
        else
            totem:SetPoint("LEFT", display, "LEFT", (index - 1) * (size + spacing), 0)
        end
    end
    display.bar:ClearAllPoints()
    display.bar:SetSize(unpack(layout.barSize))
    display.bar:SetPoint("CENTER", display, "CENTER")
    display.bar.art:ClearAllPoints()
    display.bar.art:SetPoint("CENTER", display.bar, "CENTER")
    display.bar.art:SetSize(unpack(layout.barArtSize or layout.barSize))
    return true
end

local function GetInventoryResourceCount(definition)
    if definition.inventorySlot and GetInventoryItemCount then
        return SafeNumber(GetInventoryItemCount("player", definition.inventorySlot), 0)
    elseif C_Item and C_Item.GetItemCount then
        return SafeNumber(C_Item.GetItemCount(definition.itemID, false, false, false, false), 0)
    elseif GetItemCount then
        return SafeNumber(GetItemCount(definition.itemID, false, false), 0)
    end
    return 0
end

local function GetEquippedAmmoItemID(inventorySlot)
    if GetInventoryItemID then
        local itemID = SafeNumber(GetInventoryItemID("player", inventorySlot))
        if itemID then return itemID end
    end
    if GetInventoryItemLink then
        local link = GetInventoryItemLink("player", inventorySlot)
        if type(link) == "string" and not IsSecret(link) then
            return tonumber(link:match("item:(%d+)"))
        end
    end
end

local function GetAmmoColor(definition, preview)
    if preview then return DEFAULT_AMMO_COLOR end

    local itemID = GetEquippedAmmoItemID(definition.inventorySlot)
    if itemID and AMMO_COLORS[itemID] then return AMMO_COLORS[itemID] end

    -- Unknown future arrows use their item-quality color instead of silently
    -- falling back to Hunter green.
    local quality = GetInventoryItemQuality
        and SafeNumber(GetInventoryItemQuality("player", definition.inventorySlot))
    local qualityColor = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if qualityColor then
        return {
            qualityColor.r or qualityColor[1],
            qualityColor.g or qualityColor[2],
            qualityColor.b or qualityColor[3],
        }
    end
    return DEFAULT_AMMO_COLOR
end

local function UpdateItemCount(display, definition, preview)
    local segment = display.segments[1]
    local count = preview and definition.previewCount or GetInventoryResourceCount(definition)
    local color = definition.key == "ammo" and GetAmmoColor(definition, preview)
        or COLORS[definition.key] or COLORS.combo
    local resourceLayoutKey = definition.layoutKey
    local textOffsetY = (resourceLayoutKey
        and display.layout[resourceLayoutKey .. "TextOffsetY"])
        or display.layout.itemCountTextOffsetY or 0

    segment:Show()
    local activeRole = definition.activeAsset or "classResourceJewelActive"
    local emptyRole = definition.emptyAsset or "classResourceJewelEmpty"
    segment:SetStatusBarTexture(PF:ThemeFrameAsset("classResources", activeRole, activeRole))
    segment.empty:SetTexture(PF:ThemeFrameAsset("classResources", emptyRole, emptyRole))
    segment.art:SetShown(definition.showPointFrame ~= false)
    segment.empty:SetVertexColor(1, 1, 1, 1)
    segment:SetMinMaxValues(0, 1)
    segment:SetValue(count > 0 and 1 or 0)
    SetColor(segment, color)
    segment.cooldown:Hide()
    local font, _, flags = segment.countText:GetFont()
    if font then
        local fontSize = count >= 1000 and 13 or (count >= 100 and 15 or 18)
        segment.countText:SetFont(font, fontSize, flags)
    end
    segment.countText:ClearAllPoints()
    segment.countText:SetPoint("CENTER", segment, "CENTER", 0, textOffsetY)
    segment.countText:SetText(tostring(count))
    segment.countText:Show()
    SetItemCountTooltip(segment, not preview and definition or nil)
end

local function UpdatePoints(display, definition, preview)
    local maximum = GetPointMaximum(display, definition, preview)
    local current
    if preview then
        current = math.max(1, math.floor(maximum * 0.6))
    elseif definition.key == "combo" and GetComboPoints then
        -- Forever's native ComboFrame is target-driven even though combo
        -- points are a player power. This API clears immediately for an invalid
        -- target and accepts its restricted result as a StatusBar value sink.
        current = GetComboPoints("player", "target")
    else
        current = UnitPower("player", definition.power)
    end
    local color = COLORS[definition.key] or COLORS.combo
    for index, segment in ipairs(display.segments) do
        segment:SetShown(index <= maximum)
        if index <= maximum then
            segment.art:Show()
            segment:SetStatusBarTexture(PF:ThemeFrameAsset(
                "classResources", "classResourceJewelActive", "classResourceJewelActive"
            ))
            segment.empty:SetTexture(PF:ThemeFrameAsset(
                "classResources", "classResourceJewelEmpty", "classResourceJewelEmpty"
            ))
            segment.empty:SetVertexColor(1, 1, 1, 1)
            segment:SetMinMaxValues(index - 1, index)
            segment:SetValue(current)
            SetColor(segment, color)
            segment.cooldown:Hide()
        end
    end
end

local function UpdateRunes(display, preview)
    for index, segment in ipairs(display.segments) do
        segment:SetShown(index <= 6)
        if index <= 6 then
            segment.art:Show()
            segment:SetMinMaxValues(0, 1)
            segment:SetValue(1)
            SetColor(segment, COLORS.runes)
            if preview and index > 4 then
                segment.cooldown:SetCooldown(GetTime(), 5 + index)
                segment.cooldown:Show()
            elseif GetRuneCooldown then
                local start, duration = GetRuneCooldown(index)
                local applied = start and duration and pcall(segment.cooldown.SetCooldown, segment.cooldown, start, duration)
                segment.cooldown:SetShown(applied == true)
            else
                segment.cooldown:Hide()
            end
        end
    end
end

local function UpdateBar(display, definition, preview)
    display.bar:Show()
    SetColor(display.bar, COLORS[definition.key] or COLORS.mana)
    local current, maximum
    if preview then
        current, maximum = 60, 100
    elseif definition.stagger and UnitStagger then
        current, maximum = UnitStagger("player"), UnitHealthMax("player")
    else
        current = UnitPower("player", definition.power)
        maximum = UnitPowerMax("player", definition.power)
    end
    display.bar:SetMinMaxValues(0, maximum)
    display.bar:SetValue(current)

    local safeCurrent = SafeNumber(current)
    local safeMaximum = SafeNumber(maximum)
    if safeCurrent and safeMaximum then
        display.bar.text:SetText(
            math.floor(safeCurrent + 0.5) .. " / " .. math.floor(safeMaximum + 0.5)
        )
    else
        display.bar.text:SetText("")
    end
end

local function UpdateTotems(display, preview)
    for index, totem in ipairs(display.totems) do
        totem:Show()
        -- The decorative texture supplies the intended bronze bezel. Keep the
        -- generic BackdropTemplate edge transparent so it does not add a thin
        -- square orange box around that artwork.
        totem:SetBackdropBorderColor(0, 0, 0, 0)
        if preview then
            totem.icon:SetTexture("Interface\\Icons\\Spell_Nature_StoneClawTotem")
            totem:SetAlpha(index <= 3 and 1 or 0.28)
            if index <= 3 then totem.cooldown:SetCooldown(GetTime(), 20 + index * 4) end
        elseif GetTotemInfo then
            local haveTotem, _, start, duration, icon = GetTotemInfo(index)
            totem.icon:SetTexture(icon)
            if totem.SetAlphaFromBoolean and IsSecret(haveTotem) then
                totem:SetAlphaFromBoolean(haveTotem, 1, 0)
            else
                totem:SetAlpha(haveTotem and 1 or 0)
            end
            if start and duration then pcall(totem.cooldown.SetCooldown, totem.cooldown, start, duration) end
        else
            totem:SetAlpha(0)
        end
    end
end

function PF:CreateClassResourceDisplay()
    local theme = self:GetTheme()
    local layout = theme and theme.layout and theme.layout.classResources
    if layout then
        self.classResourceDisplay = CreateDisplay(layout, "PrettyFramesClassResource")
        self.druidManaResourceDisplay = CreateDisplay(layout, "PrettyFramesDruidManaResource")
        self.classResourceDisplays = {
            self.classResourceDisplay,
            self.druidManaResourceDisplay,
        }
    end
    self:UpdateClassResourceDisplay(true)
end

local function RenderCustomResource(self, display, definition, preview)
    local handled = display and display.layout.handled
        and display.layout.handled[definition.kind]
    if not handled then
        HideCustom(display)
        return false
    end

    display.currentDefinition = definition
    if not LayoutDisplay(display, definition, preview) then
        HideCustom(display)
        return false
    end
    display:Show()
    self:SuppressNativeClassResource(definition)
    display.bar:Hide()
    for index, segment in ipairs(display.segments) do
        segment:Hide()
        segment.countText:Hide()
        SetItemCountTooltip(
            segment,
            definition.kind == "itemCount" and index == 1 and not preview and definition or nil
        )
    end
    for _, totem in ipairs(display.totems) do totem:Hide() end

    if definition.kind == "points" then
        UpdatePoints(display, definition, preview)
    elseif definition.kind == "itemCount" then
        UpdateItemCount(display, definition, preview)
    elseif definition.kind == "runes" then
        UpdateRunes(display, preview)
    elseif definition.kind == "bar" then
        UpdateBar(display, definition, preview)
    elseif definition.kind == "totems" then
        UpdateTotems(display, preview)
    end
    return true
end

function PF:UpdateClassResourceDisplay(force)
    local preview = self.testMode == true
    local definition = ResolveDefinition(preview)
    local secondaryDefinition = ResolveDruidSecondaryMana(preview)
    local setting = self.db and self:GetFrameSetting("player")
    local enabled = self.db and self.db.replaceUnitFrames ~= false
        and setting and setting.classResourceVisibility ~= "hidden"

    if not enabled then
        HideCustom(self.classResourceDisplay)
        HideCustom(self.druidManaResourceDisplay)
        self:RestoreNativeClassResource()
        self:RestoreSuppressedClassResources()
        self.activeClassResource = nil
        self.activeClassResourceSignature = nil
        return
    end

    if not definition then
        HideCustom(self.classResourceDisplay)
        HideCustom(self.druidManaResourceDisplay)
        self:RestoreNativeClassResource()
        self:RestoreSuppressedClassResources()
        self.activeClassResource = nil
        self.activeClassResourceSignature = nil
        return
    end

    local display = self.classResourceDisplay
    local handled = display and display.layout.handled
        and display.layout.handled[definition.kind]
    if not handled then
        HideCustom(display)
        HideCustom(self.druidManaResourceDisplay)
        self:TryNativeClassResource(definition)
        self.activeClassResource = definition
        self.activeClassResourceSignature = definition.key
        return
    end

    local signature = definition.key
        .. (secondaryDefinition and ("+" .. secondaryDefinition.key) or "")
    if self.activeClassResourceSignature ~= signature then
        self:RestoreNativeClassResource()
        self:RestoreSuppressedClassResources()
    end
    if not RenderCustomResource(self, display, definition, preview) then return end
    if secondaryDefinition then
        RenderCustomResource(
            self, self.druidManaResourceDisplay, secondaryDefinition, preview
        )
    else
        HideCustom(self.druidManaResourceDisplay)
    end
    self.activeClassResource = definition
    self.activeClassResourceSignature = signature
end

function PF:HandleClassResourceEvent(event, unit)
    if event == "ITEM_COUNT_CHANGED" then
        local _, class = UnitClass("player")
        if unit ~= SOUL_SHARD_ITEM_ID and class ~= "HUNTER" then return end
    elseif event == "BAG_UPDATE_DELAYED" then
        -- Defensive fallback for inventory moves that do not change the total.
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if unit ~= "player" then return end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local _, class = UnitClass("player")
        if class ~= "HUNTER" then return end
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER"
        or event == "UNIT_DISPLAYPOWER"
        or event == "UNIT_POWER_POINT_CHARGE" or event == "UNIT_HEALTH"
        or event == "UNIT_MAXHEALTH" then
        if unit ~= "player" then return end
    elseif event ~= "PLAYER_TARGET_CHANGED"
        and event ~= "PLAYER_ENTERING_WORLD"
        and event ~= "PLAYER_SPECIALIZATION_CHANGED"
        and event ~= "PLAYER_TALENT_UPDATE"
        and event ~= "UPDATE_SHAPESHIFT_FORM"
        and event ~= "UNIT_ENTERED_VEHICLE"
        and event ~= "UNIT_EXITED_VEHICLE"
        and event ~= "RUNE_POWER_UPDATE"
        and event ~= "PLAYER_TOTEM_UPDATE" then
        return
    end
    self:UpdateClassResourceDisplay()
end
