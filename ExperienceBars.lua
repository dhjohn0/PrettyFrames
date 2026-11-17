local _, PF = ...

local BAR_HEIGHT = 18
local BAR_COLORS = {
    player = { 0.45, 0.20, 0.78 },
    pet = { 0.16, 0.62, 0.30 },
    reputation = { 0.15, 0.55, 0.82 },
}
local COLOR_PRESETS = {
    violet = { 0.45, 0.20, 0.78 },
    blue = { 0.12, 0.42, 0.88 },
    gold = { 0.90, 0.58, 0.10 },
    emerald = { 0.16, 0.62, 0.30 },
    teal = { 0.08, 0.66, 0.64 },
}
local TEXT_CHOICES = {
    { id = "current", label = "Current" },
    { id = "maximum", label = "Maximum" },
    { id = "currentmax", label = "Current / Maximum" },
    { id = "percent", label = "Percentage" },
    { id = "currentpercent", label = "Current + Percentage" },
    { id = "none", label = "Hidden" },
}
local COLOR_CHOICES = {
    player = {
        { id = "violet", label = "Violet" },
        { id = "blue", label = "Blue" },
        { id = "gold", label = "Gold" },
        { id = "emerald", label = "Emerald" },
        { id = "class", label = "Class Color" },
    },
    pet = {
        { id = "emerald", label = "Emerald" },
        { id = "teal", label = "Teal" },
        { id = "gold", label = "Gold" },
        { id = "player", label = "Match Player" },
    },
    reputation = {
        { id = "standing", label = "Standing Color" },
        { id = "blue", label = "Blue" },
        { id = "gold", label = "Gold" },
        { id = "player", label = "Match Player" },
    },
}

local function IsSafeNumber(value)
    return type(value) == "number" and PF:IsDisplaySafe(value)
end

local function FormatProgressValue(value)
    return PF:FormatNumber(value) or ""
end

local function FormatProgressText(info, mode)
    if mode == "none" then return "" end
    local value, maximum = info.value, info.maximum
    local currentText = PF:FormatNumber(value)
    local maximumText = PF:FormatNumber(maximum)
    if not currentText or not maximumText or maximum <= 0 then return info.label end
    local percentage = value / maximum * 100
    local detail
    if mode == "current" then
        detail = FormatProgressValue(value)
    elseif mode == "maximum" then
        detail = FormatProgressValue(maximum)
    elseif mode == "percent" then
        detail = ("%.1f%%"):format(percentage)
    elseif mode == "currentpercent" then
        detail = ("%s  %.1f%%"):format(currentText, percentage)
    else
        detail = currentText .. " / " .. maximumText
    end
    return info.label .. "  " .. detail
end

local function ResolvePlayerColor(options)
    local mode = options.playerColorMode
    if mode == "class" then
        local _, classFile = UnitClass("player")
        local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
        if color then return { color.r, color.g, color.b } end
    elseif mode == "custom" then
        local color = options.customColors and options.customColors.player
        if color then return color end
    end
    return COLOR_PRESETS[mode] or BAR_COLORS.player
end

local function ResolveBarColor(info, options)
    if info.kind == "player" then return ResolvePlayerColor(options) end
    local mode = options[info.kind .. "ColorMode"]
    if mode == "player" then return ResolvePlayerColor(options) end
    if mode == "custom" then
        local color = options.customColors and options.customColors[info.kind]
        if color then return color end
    end
    if info.kind == "reputation" and mode == "standing" then
        return info.color or BAR_COLORS.reputation
    end
    return COLOR_PRESETS[mode] or BAR_COLORS[info.kind]
end

local function PlayerProgress()
    local value = UnitXP and UnitXP("player")
    local maximum = UnitXPMax and UnitXPMax("player")
    if not IsSafeNumber(value) or not IsSafeNumber(maximum) or maximum <= 0 then return end
    local rested = GetXPExhaustion and GetXPExhaustion()
    if not IsSafeNumber(rested) or rested <= 0 then rested = nil end
    return {
        kind = "player",
        label = XP or "Experience",
        value = value,
        maximum = maximum,
        level = UnitLevel("player"),
        rested = rested,
    }
end

local function PetProgress()
    if not UnitExists("pet") then return end
    local value, maximum
    if GetPetExperience then
        value, maximum = GetPetExperience()
    end
    if (not IsSafeNumber(maximum) or maximum <= 0) and UnitXP and UnitXPMax then
        value = UnitXP("pet")
        maximum = UnitXPMax("pet")
    end
    if not IsSafeNumber(value) or not IsSafeNumber(maximum) or maximum <= 0 then return end
    local name = UnitName("pet")
    if not PF:IsDisplaySafe(name) then name = nil end
    return {
        kind = "pet",
        label = name and (name .. " XP") or ((PET or "Pet") .. " XP"),
        value = value,
        maximum = maximum,
        level = UnitLevel("pet"),
    }
end

local function WatchedReputationProgress()
    local name, reaction, minimum, maximum, value
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local data = C_Reputation.GetWatchedFactionData()
        if type(data) == "table" then
            name = data.name
            reaction = data.reaction
            minimum = data.currentReactionThreshold or data.minValue or 0
            maximum = data.nextReactionThreshold or data.maxValue
            value = data.currentStanding or data.standing or data.value
        end
    end
    if not name and GetWatchedFactionInfo then
        name, reaction, minimum, maximum, value = GetWatchedFactionInfo()
    end
    if type(name) ~= "string" or name == "" or not IsSafeNumber(value) then return end
    if not IsSafeNumber(minimum) then minimum = 0 end
    if not IsSafeNumber(maximum) then return end

    local progressMaximum = maximum - minimum
    local progressValue = value - minimum
    if progressMaximum <= 0 then
        progressMaximum, progressValue = 1, 1
    end
    progressValue = math.max(0, math.min(progressMaximum, progressValue))

    local color = BAR_COLORS.reputation
    local factionColor = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    if factionColor then
        color = { factionColor.r, factionColor.g, factionColor.b }
    end
    return {
        kind = "reputation",
        label = name,
        value = progressValue,
        maximum = progressMaximum,
        color = color,
        reaction = reaction,
    }
end

local function GetProgressGeometry(width)
    local layout = PF:ThemeLayout("castBar")
    local baseExtraWidth = layout.ornamentExtraWidth or 0
    -- Progress bars do not have a spell icon covering their ends. Give their
    -- ornament a wider horizontal footprint so the decorative caps overlap
    -- only the fill edges, while retaining the theme's authored height.
    local ornamentWidth = width
        + (layout.progressOrnamentExtraWidth or baseExtraWidth)
    local ornamentHeight = layout.progressOrnamentHeight
        or layout.ornamentMinHeight or BAR_HEIGHT
    local barHeight = layout.progressBarHeight or BAR_HEIGHT
    return barHeight, barHeight + (layout.progressBarGap or 11), ornamentWidth, ornamentHeight
end

local function LayoutProgressOrnament(holder, width, height, barHeight)
    holder:SetSize(width, height)
    local barScale = holder.progressEndCapBarScale or holder.endCapBarScale
    local capSize = barScale
        and barHeight * barScale
        or height * (holder.endCapScale or 1)
    local capOffsetX = capSize * (
        holder.progressEndCapOffsetX or holder.endCapOffsetX or 0
    )
    local capOffsetY = capSize * (holder.endCapOffsetY or 0)
    holder.leftCap:SetSize(capSize, capSize)
    holder.leftCap:ClearAllPoints()
    holder.leftCap:SetPoint("LEFT", holder, "LEFT", -capOffsetX, capOffsetY)
    holder.rightCap:SetSize(capSize, capSize)
    holder.rightCap:ClearAllPoints()
    holder.rightCap:SetPoint("RIGHT", holder, "RIGHT", capOffsetX, capOffsetY)
end

local function CreateProgressOrnament(bar, width, height, barHeight)
    local layout = PF:ThemeLayout("castBar")
    local holder = CreateFrame("Frame", nil, bar:GetParent())
    holder:SetFrameLevel(bar:GetFrameLevel() + 2)
    holder:EnableMouse(false)
    holder.endCapScale = layout.endCapScale or 1
    holder.endCapBarScale = layout.endCapBarScale
    holder.progressEndCapBarScale = layout.progressEndCapBarScale
    holder.endCapOffsetX = layout.endCapOffsetX
    holder.progressEndCapOffsetX = layout.progressEndCapOffsetX
    holder.endCapOffsetY = layout.endCapOffsetY
    PF:SetThemePoint(holder, bar, layout.ornamentPoint)
    local asset = PF:ThemeFrameAsset("castBar", "castBarEndCap", "castBarEndCap")
    holder.leftCap = holder:CreateTexture(nil, "OVERLAY", nil, 7)
    holder.leftCap:SetTexture(asset)
    holder.rightCap = holder:CreateTexture(nil, "OVERLAY", nil, 7)
    holder.rightCap:SetTexture(asset)
    holder.rightCap:SetTexCoord(1, 0, 0, 1)
    LayoutProgressOrnament(holder, width, height, barHeight)
    holder:Hide()
    bar:HookScript("OnShow", function() holder:Show() end)
    bar:HookScript("OnHide", function() holder:Hide() end)
    if bar:IsShown() then holder:Show() end
    return holder
end

local function SetBarGeometry(bar, width, barHeight, ornamentWidth, ornamentHeight)
    bar:SetSize(width, barHeight)
    LayoutProgressOrnament(bar.ornament, ornamentWidth, ornamentHeight, barHeight)
end

local function FormatTooltipNumber(value)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(value) end
    return tostring(math.floor(value + 0.5))
end

local function AddValueLine(label, value, maximum)
    if not IsSafeNumber(value) or not IsSafeNumber(maximum) or maximum <= 0 then return end
    GameTooltip:AddDoubleLine(
        label,
        ("%s / %s  (%.1f%%)"):format(
            FormatTooltipNumber(value), FormatTooltipNumber(maximum), value / maximum * 100
        ),
        0.82, 0.82, 0.82, 1, 1, 1
    )
end

local function ShowProgressTooltip(bar)
    if PF.db and not PF.db.locked then return end
    local info = bar.info
    if not info then return end
    GameTooltip:SetOwner(bar, "ANCHOR_CURSOR_RIGHT")
    if info.kind == "player" then
        GameTooltip:SetText(info.label)
        if IsSafeNumber(info.level) then
            GameTooltip:AddLine(("Level %d"):format(info.level), 1, 0.82, 0)
        end
        AddValueLine(XP or "Experience", info.value, info.maximum)
        local remaining = math.max(0, info.maximum - info.value)
        GameTooltip:AddDoubleLine(
            "Remaining",
            FormatTooltipNumber(remaining),
            0.82, 0.82, 0.82, 1, 1, 1
        )
        local rested = info.rested
        if IsSafeNumber(rested) and rested > 0 then
            GameTooltip:AddDoubleLine(
                "Rested",
                ("%s  (%.1f%% of level)"):format(
                    FormatTooltipNumber(rested),
                    rested / info.maximum * 100
                ),
                1, 0.82, 0, 1, 0.82, 0
            )
            GameTooltip:AddLine(
                "200% of normal experience\ngained from monsters.",
                1, 1, 1, true
            )
        end
    elseif info.kind == "pet" then
        GameTooltip:SetText(info.label)
        if IsSafeNumber(info.level) then
            GameTooltip:AddLine(("Level %d"):format(info.level), 1, 0.82, 0)
        end
        AddValueLine("Experience", info.value, info.maximum)
    else
        GameTooltip:SetText(info.label)
        local standing = info.reaction and _G["FACTION_STANDING_LABEL" .. info.reaction]
        if standing then GameTooltip:AddLine(standing, 1, 0.82, 0) end
        AddValueLine(REPUTATION or "Reputation", info.value, info.maximum)
    end
    GameTooltip:Show()
end

local OpenProgressBarMenu

local function CreateProgressBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetFrameLevel(parent:GetFrameLevel() + 1)
    -- Progress bars use the selected theme's regular health/power bar asset.
    -- Spell castbars retain their dedicated Blizzard fill texture.
    local fillTexture = PF:ThemeAsset("statusBar")
    bar:SetStatusBarTexture(fillTexture)
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", ShowProgressTooltip)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bar:SetScript("OnMouseUp", function(widget, button)
        if button == "RightButton" and PF.db and not PF.db.locked
            and OpenProgressBarMenu then
            OpenProgressBarMenu(widget)
        end
    end)

    bar.background = bar:CreateTexture(nil, "BACKGROUND", nil, 4)
    bar.background:SetAllPoints(bar)
    bar.background:SetColorTexture(0.025, 0.018, 0.012, 0.94)

    bar.restedOverlay = CreateFrame("Frame", nil, parent)
    bar.restedOverlay:SetFrameLevel(bar:GetFrameLevel() + 1)
    bar.restedOverlay:EnableMouse(false)
    bar.restedOverlay.texture = bar.restedOverlay:CreateTexture(nil, "ARTWORK")
    bar.restedOverlay.texture:SetAllPoints(bar.restedOverlay)
    bar.restedOverlay.texture:SetTexture(fillTexture)
    bar.restedOverlay.texture:SetVertexColor(0.40, 0.56, 0.92, 0.42)
    bar.restedOverlay:Hide()

    bar.textLayer = CreateFrame("Frame", nil, parent)
    bar.textLayer:SetAllPoints(bar)
    bar.textLayer:SetFrameLevel(bar:GetFrameLevel() + 3)
    bar.textLayer:EnableMouse(false)
    bar.Text = bar.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.Text:SetPoint("LEFT", bar.textLayer, "LEFT", 10, 0)
    bar.Text:SetPoint("RIGHT", bar.textLayer, "RIGHT", -10, 0)
    bar.Text:SetJustifyH("CENTER")
    bar.Text:SetTextColor(1, 0.91, 0.72)
    PF:ApplyBoldNumberFont(bar.Text, 11)

    bar.themeFrameName = "castBar"
    local barHeight, _, ornamentWidth, ornamentHeight = GetProgressGeometry(420)
    bar.ornament = CreateProgressOrnament(
        bar, ornamentWidth, ornamentHeight, barHeight
    )
    return bar
end

local function OpenExperienceMenu(owner)
    if InCombatLockdown() or not PF.db or PF.db.locked then return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        PF:Print("the experience bar menu is unavailable on this client build.")
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        local options = PF.db.experienceBar
        root:CreateTitle("Progress Bars")
        root:CreateButton("Center Horizontally", function()
            local position = options.position
            options.position = {
                0,
                position and position[2] or (options.growUpwards and 28 or 104),
            }
            PF:RefreshExperienceBars()
        end)
        root:CreateDivider()
        root:CreateTitle("Scale")
        PF:AddMenuSlider(root, math.floor(options.scale * 100 + 0.5), 60, 160, function(value)
            options.scale = value / 100
            PF:RefreshExperienceBars()
        end, 20, function(value) return value .. "%" end)

        root:CreateTitle("Width")
        PF:AddMenuSlider(root, options.width, 240, 720, function(value)
            options.width = math.floor(value + 0.5)
            PF:RefreshExperienceBars()
        end, 48, function(value) return value .. " px" end)

        root:CreateTitle("Growth Direction")
        root:CreateRadio("Grow Up", function() return options.growUpwards == true end, function()
            options.growUpwards = true
            PF:RefreshExperienceBars()
        end)
        root:CreateRadio("Grow Down", function() return options.growUpwards ~= true end, function()
            options.growUpwards = false
            PF:RefreshExperienceBars()
        end)

        root:CreateTitle("Bars")
        local choices = {
            { "showPlayer", "Player Experience" },
            { "showPet", "Pet Experience" },
            { "showReputation", "Selected Reputation" },
        }
        for _, choice in ipairs(choices) do
            local key, label = choice[1], choice[2]
            root:CreateCheckbox(label, function() return options[key] == true end, function()
                options[key] = options[key] ~= true
                PF:RefreshExperienceBars()
            end)
        end
    end)
end

local function OpenProgressColorPicker(kind)
    if not ColorPickerFrame or not PF.db then return end
    local options = PF.db.experienceBar
    options.customColors = options.customColors or {}
    local colorKey = kind .. "ColorMode"
    local originalMode = options[colorKey]
    local original = options.customColors[kind]
    original = original and { original[1], original[2], original[3] } or nil
    local initial = original or ResolveBarColor({ kind = kind }, options)

    local function ApplyColor()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        options.customColors[kind] = { r, g, b }
        options[colorKey] = "custom"
        PF:RefreshExperienceBars()
    end
    local function RestoreColor()
        options.customColors[kind] = original
        options[colorKey] = originalMode
        PF:RefreshExperienceBars()
    end

    options.customColors[kind] = { initial[1], initial[2], initial[3] }
    options[colorKey] = "custom"
    PF:RefreshExperienceBars()
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = initial[1], g = initial[2], b = initial[3],
            hasOpacity = false,
            swatchFunc = ApplyColor,
            cancelFunc = RestoreColor,
        })
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.func = ApplyColor
        ColorPickerFrame.cancelFunc = RestoreColor
        ColorPickerFrame:SetColorRGB(initial[1], initial[2], initial[3])
        ColorPickerFrame:Show()
    end
end

OpenProgressBarMenu = function(bar)
    if InCombatLockdown() or not PF.db or PF.db.locked or not bar.info then return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        PF:Print("the progress bar menu is unavailable on this client build.")
        return
    end
    MenuUtil.CreateContextMenu(bar, function(_, root)
        local options = PF.db.experienceBar
        local kind = bar.info.kind
        local labels = {
            player = "Player Experience",
            pet = "Pet Experience",
            reputation = "Selected Reputation",
        }
        root:CreateTitle(labels[kind] or "Progress Bar")
        root:CreateTitle("Text")
        local textKey = kind .. "TextMode"
        for _, choice in ipairs(TEXT_CHOICES) do
            local selected = choice
            root:CreateRadio(selected.label, function(value)
                return options[textKey] == value
            end, function(value)
                options[textKey] = value
                PF:RefreshExperienceBars()
            end, selected.id)
        end

        root:CreateDivider()
        root:CreateTitle("Bar Color")
        local colorKey = kind .. "ColorMode"
        for _, choice in ipairs(COLOR_CHOICES[kind] or {}) do
            local selected = choice
            root:CreateRadio(selected.label, function(value)
                return options[colorKey] == value
            end, function(value)
                options[colorKey] = value
                PF:RefreshExperienceBars()
            end, selected.id)
        end
        root:CreateRadio("Custom...", function()
            return options[colorKey] == "custom"
        end, function()
            OpenProgressColorPicker(kind)
        end)

        if kind == "player" then
            root:CreateDivider()
            root:CreateCheckbox("Show Rested Experience", function()
                return options.showRested ~= false
            end, function()
                options.showRested = options.showRested == false
                PF:RefreshExperienceBars()
            end)
        end
    end)
end

function PF:RefreshExperienceBars()
    local container = self.frames.experienceBars
    if not container or not self.db or self.db.replaceExperienceBar ~= true then return end
    local options = self.db.experienceBar
    local progress = {}
    local function AddProgress(info)
        if info then table.insert(progress, info) end
    end
    if options.showPlayer then AddProgress(PlayerProgress()) end
    if options.showPet then AddProgress(PetProgress()) end
    if options.showReputation then AddProgress(WatchedReputationProgress()) end

    local width = options.width
    local barHeight, barSpacing, ornamentWidth, ornamentHeight = GetProgressGeometry(width)
    local totalHeight = math.max(barHeight, (#progress - 1) * barSpacing + barHeight)
    container:SetScale(options.scale)
    container:SetSize(width, totalHeight)
    container:ClearAllPoints()
    local position = options.position
    local x = position and position[1] or 0
    local y = position and position[2] or (options.growUpwards and 28 or 104)
    container:SetPoint(options.growUpwards and "BOTTOM" or "TOP", UIParent, "BOTTOM", x, y)

    for index, bar in ipairs(container.bars) do
        local info = progress[index]
        bar.info = info
        bar:ClearAllPoints()
        SetBarGeometry(bar, width, barHeight, ornamentWidth, ornamentHeight)
        if info then
            -- Bar order is always Player, Pet, Reputation from top to bottom.
            -- Growth direction controls which edge of the container remains
            -- fixed as its height changes, not the order of its children.
            bar:SetPoint("TOP", container, "TOP", 0, -(index - 1) * barSpacing)
            bar:SetMinMaxValues(0, info.maximum)
            bar:SetValue(info.value)
            local color = ResolveBarColor(info, options)
            bar:SetStatusBarColor(unpack(color))
            bar.Text:SetText(FormatProgressText(
                info, options[info.kind .. "TextMode"] or "currentmax"
            ))
            local rested = info.kind == "player" and options.showRested ~= false
                and info.rested
            if IsSafeNumber(rested) and rested > 0 then
                local startFraction = info.value / info.maximum
                local endFraction = math.min(info.maximum, info.value + rested) / info.maximum
                local startX = width * startFraction
                local endX = width * endFraction
                if endX > startX then
                    bar.restedOverlay:ClearAllPoints()
                    bar.restedOverlay:SetPoint("TOPLEFT", bar, "TOPLEFT", startX, 0)
                    bar.restedOverlay:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", endX, 0)
                    -- Sample the same portion of the full-width bar texture
                    -- instead of squeezing the complete asset into this slice.
                    bar.restedOverlay.texture:SetTexCoord(startFraction, endFraction, 0, 1)
                    bar.restedOverlay.texture:SetVertexColor(
                        math.min(1, color[1] * 0.55 + 0.45),
                        math.min(1, color[2] * 0.55 + 0.45),
                        math.min(1, color[3] * 0.55 + 0.45),
                        0.42
                    )
                    bar.restedOverlay:Show()
                else
                    bar.restedOverlay:Hide()
                end
            else
                bar.restedOverlay:Hide()
            end
            bar:Show()
        else
            bar.restedOverlay:Hide()
            bar:Hide()
        end
    end
    container:SetShown(#progress > 0)
end

function PF:RefreshExperienceBarInteraction(editing)
    local container = self.frames.experienceBars
    if not container then return end
    editing = editing == true and not InCombatLockdown()
    container.editing = editing
    container:EnableMouse(false)
    if container.moveHandle then container.moveHandle:SetShown(editing) end
    for _, bar in ipairs(container.bars) do
        bar:EnableMouse(true)
    end
end

function PF:CreateExperienceBars()
    if not self.db or self.db.replaceExperienceBar ~= true or self.frames.experienceBars then return end
    local container = CreateFrame("Frame", "PrettyFramesExperienceBars", UIParent)
    container:SetFrameStrata("MEDIUM")
    container:SetFrameLevel(20)
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    local function SavePosition(frame)
        local parentCenter = UIParent:GetCenter()
        local parentBottom = UIParent:GetBottom() or 0
        local frameCenter = frame:GetCenter()
        local edge = PF.db.experienceBar.growUpwards and frame:GetBottom() or frame:GetTop()
        if parentCenter and frameCenter and edge then
            frameCenter, edge = PF:ConvertRegionCoordinatesToUIParent(frame, frameCenter, edge)
            if not frameCenter or not edge then return end
            PF.db.experienceBar.position = {
                frameCenter - parentCenter,
                edge - parentBottom,
            }
            PF:RefreshExperienceBars()
        end
    end
    container.bars = {
        CreateProgressBar(container),
        CreateProgressBar(container),
        CreateProgressBar(container),
    }
    local handle = CreateFrame("Frame", nil, container, "BackdropTemplate")
    handle:SetSize(128, 22)
    handle:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 8)
    self:RaiseEditHandle(handle)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    self:CreateBackdrop(handle, 1)
    handle:SetBackdropColor(0.08, 0.045, 0.02, 0.96)
    handle:SetScript("OnDragStart", function()
        if container.editing and not InCombatLockdown() then
            container:StartMoving()
            container.prettyFramesMoving = true
        end
    end)
    handle:SetScript("OnDragStop", function()
        if not container.prettyFramesMoving then return end
        container.prettyFramesMoving = nil
        if InCombatLockdown() then return end
        container:StopMovingOrSizing()
        SavePosition(container)
    end)
    handle:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then OpenExperienceMenu(handle) end
    end)
    handle.text = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    handle.text:SetPoint("CENTER")
    handle.text:SetText("MOVE EXP")
    handle.text:SetTextColor(unpack(self.colors.bronzeBright))
    handle:Hide()
    container.moveHandle = handle
    self.frames.experienceBars = container
    self.FrameBehaviors:Attach("editMode", container, {
        apply = function(editing)
            PF:RefreshExperienceBarInteraction(editing)
            return true
        end,
    })

    local events = {
        "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP",
        "UPDATE_EXHAUSTION", "UNIT_PET", "UNIT_LEVEL", "UNIT_XP_UPDATE",
        "UNIT_PET_EXPERIENCE",
        "PET_UI_UPDATE", "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
    }
    for _, event in ipairs(events) do PF:RegisterEventSafe(container, event) end
    container:SetScript("OnEvent", function(_, event, unit)
        if unit and (event == "UNIT_PET" or event == "UNIT_LEVEL" or event == "UNIT_XP_UPDATE"
            or event == "UNIT_PET_EXPERIENCE")
            and unit ~= "player" and unit ~= "pet" then return end
        PF:RefreshExperienceBars()
    end)
    self:RefreshExperienceBars()
end
