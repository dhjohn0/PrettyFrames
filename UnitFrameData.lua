local _, PF = ...

local ShowPortraitFallback = PF.Widgets.ShowPortraitFallback
local RequestPortraitModel = PF.Widgets.RequestPortraitModel
local SetPartyRole = PF.Widgets.SetPartyRole
local SetRaidMarkerTexture = PF.Widgets.SetRaidMarkerTexture
local raidTestNames = PF.Widgets.raidTestNames

local powerColors = {
    [0] = { 0.05, 0.35, 0.82 }, -- mana
    [1] = { 0.82, 0.10, 0.08 }, -- rage
    [2] = { 0.90, 0.45, 0.08 }, -- focus
    [3] = { 0.92, 0.82, 0.12 }, -- energy
    [6] = { 0.00, 0.82, 1.00 }, -- runic power
    [11] = { 0.15, 0.58, 1.00 }, -- maelstrom
    [13] = { 0.30, 0.52, 0.90 }, -- insanity
    [17] = { 0.78, 0.20, 0.92 }, -- fury
    [18] = { 0.25, 0.78, 0.52 }, -- pain
}

local function SetBarValue(bar, current, maximum)
    bar:SetMinMaxValues(0, maximum)
    bar:SetValue(current)
end

local function UnitColor(unit)
    local isPlayer = UnitIsPlayer(unit)
    if PF:IsDisplaySafe(isPlayer) and isPlayer == true then
        local _, class = UnitClass(unit)
        local color = PF:IsDisplaySafe(class) and class and RAID_CLASS_COLORS[class]
        if color then
            return color.r, color.g, color.b
        end
    end
    local canAttack = UnitCanAttack("player", unit)
    if PF:IsDisplaySafe(canAttack) and canAttack == true then
        return 0.72, 0.12, 0.10
    end
    local isFriend = UnitIsFriend("player", unit)
    if PF:IsDisplaySafe(isFriend) and isFriend == true then
        return 0.24, 0.64, 0.12
    end
    return unpack(PF.colors.health)
end
local function SetUnitNameToFit(frame, name, surname)
    local text = frame.nameText
    if not text then return end

    -- Never let a surname wrap into the health bar. Forever's native fitting
    -- path scales the complete string only when its bounded name region needs
    -- it, preserving the configured font size for ordinary names.
    if text.SetMaxLines then text:SetMaxLines(1) end
    if text.SetWordWrap then text:SetWordWrap(false) end
    if text.SetNonSpaceWrap then text:SetNonSpaceWrap(false) end

    if surname then
        if PF:IsDisplaySafe(name) and PF:IsDisplaySafe(surname) then
            local fullName = surname ~= "" and (name .. " " .. surname) or name
            if text.SetTextToFit then
                text:SetTextToFit(fullName)
            else
                text:SetText(fullName)
            end
        else
            -- Protected identity values cannot be joined in addon Lua. Keep
            -- the secure formatter and rely on the one-line bounded region.
            if text.SetTextScale then text:SetTextScale(1) end
            text:SetFormattedText("%s %s", name, surname)
        end
    elseif text.SetTextToFit then
        text:SetTextToFit(name)
    else
        text:SetText(name)
    end
end

local function SetTargetThreatColor(frame, status)
    if status >= 2 then
        frame.threatGlow.texture:SetVertexColor(1.00, 0.10, 0.04)
        frame.threatGlow.texture:SetAlpha(0.82)
        frame.threatText:SetTextColor(1.00, 0.25, 0.12)
    elseif status == 1 then
        frame.threatGlow.texture:SetVertexColor(1.00, 0.48, 0.06)
        frame.threatGlow.texture:SetAlpha(0.64)
        frame.threatText:SetTextColor(1.00, 0.62, 0.08)
    else
        frame.threatGlow.texture:SetVertexColor(1.00, 0.88, 0.16)
        frame.threatGlow.texture:SetAlpha(0.16)
        frame.threatText:SetTextColor(1.00, 0.90, 0.28)
    end
end

local function ReadTargetThreat(self, sourceUnit, targetUnit)
    local status, scaledPercentage, rawPercentage
    if UnitDetailedThreatSituation then
        local _
        _, status, scaledPercentage, rawPercentage =
            UnitDetailedThreatSituation(sourceUnit, targetUnit)
    elseif UnitThreatSituation then
        status = UnitThreatSituation(sourceUnit, targetUnit)
    end

    -- Detailed numeric values are protected more aggressively than the
    -- coarse threat state. Prefer the readable state when Forever exposes it
    -- so bosses still retain the yellow/orange/red fallback.
    local detailedStatusIsSecret = issecretvalue and issecretvalue(status)
    if UnitThreatSituation and (detailedStatusIsSecret or status == nil) then
        local situation = UnitThreatSituation(sourceUnit, targetUnit)
        if self:IsDisplaySafe(situation) then status = situation end
    end
    return status, scaledPercentage, rawPercentage
end

function PF:UpdateTargetThreat(frame, exists, preview)
    if not frame or not frame.hasThreatDisplay then return end
    local setting = frame.settingKey and self:GetFrameSetting(frame.settingKey)
    if not setting then return end

    if exists == nil then exists = UnitExists(frame.unit) end
    if preview == nil then preview = self.testMode == true end
    frame.threatGlow:Hide()
    frame.threatText:Hide()
    frame.threatText:SetTextColor(1.00, 0.90, 0.28)

    local status, scaledPercentage, rawPercentage
    local petStatus, petScaledPercentage, petRawPercentage
    if preview then
        if frame.unit == "focus" then
            status, scaledPercentage, rawPercentage = 3, 100, 100
        else
            status, scaledPercentage, rawPercentage = 1, 86, 105
        end
        if setting.showPetThreat and frame.unit == "target" then
            petStatus, petScaledPercentage, petRawPercentage = 2, 100, 100
        end
    elseif exists then
        status, scaledPercentage, rawPercentage = ReadTargetThreat(self, "player", frame.unit)
        if setting.showPetThreat and UnitExists("pet") then
            petStatus, petScaledPercentage, petRawPercentage =
                ReadTargetThreat(self, "pet", frame.unit)
        end
    else
        return
    end

    local usingPet = false
    if setting.showPetThreat and self:IsDisplaySafe(petStatus) then
        if not self:IsDisplaySafe(status) or petStatus > status then
            usingPet = true
        elseif petStatus == status
            and self:IsDisplaySafe(petScaledPercentage)
            and self:IsDisplaySafe(scaledPercentage)
            and petScaledPercentage > scaledPercentage then
            usingPet = true
        end
    end
    if usingPet then
        status = petStatus
        scaledPercentage = petScaledPercentage
        rawPercentage = petRawPercentage
    end

    local statusIsSecret = issecretvalue and issecretvalue(status)
    if not statusIsSecret and status == nil then return end

    if setting.showThreatGlow ~= false and not statusIsSecret then
        SetTargetThreatColor(frame, status)
        if status == 0 and self:IsDisplaySafe(scaledPercentage) then
            local progress = math.max(0, math.min(1, scaledPercentage / 100))
            frame.threatGlow.texture:SetAlpha(0.08 + progress * 0.38)
        end
        frame.threatGlow:Show()
    end

    local mode = setting.threatTextMode
    if mode == "none" then return end
    local percentage = mode == "raw" and rawPercentage or scaledPercentage
    local percentageIsSecret = issecretvalue and issecretvalue(percentage)
    if not percentageIsSecret and percentage == nil then return end

    if usingPet then
        -- Preserve the pet label even at 100%, where the player display uses
        -- the shorter AGGRO state instead of a number.
        frame.threatText:SetFormattedText("Pet: %.0f%%", percentage)
    elseif mode == "aggro" and not statusIsSecret and status >= 2 then
        frame.threatText:SetText("AGGRO")
    else
        -- Forever permits protected threat values to flow directly into a
        -- FontString, but addon Lua must not compare or perform math on them.
        frame.threatText:SetFormattedText("%.0f%%", percentage)
    end
    if not statusIsSecret then SetTargetThreatColor(frame, status) end
    frame.threatText:Show()
end

function PF:RefreshTargetThreatDisplays()
    for _, key in ipairs({ "target", "focus" }) do
        local frame = self.frames and self.frames[key]
        if frame then self:UpdateTargetThreat(frame) end
    end
end

function PF:ClearUnitFrameData(frame)
    if frame.nameText then frame.nameText:SetText("") end
    if frame.healthText then frame.healthText:SetText("") end
    if frame.isRaidFrame then
        frame.raidHealthTextHasValue = false
    end
    if frame.powerText then frame.powerText:SetText("") end
    if frame.statusText then
        if frame.isRaidFrame and self.SetRaidStatusText then
            self:SetRaidStatusText(frame, "")
        else
            frame.statusText:SetText("")
        end
    end
    if frame.levelText then frame.levelText:SetText("") end
    if frame.unitMarker then SetRaidMarkerTexture(frame.unitMarker) end
    if frame.hasThreatDisplay then self:UpdateTargetThreat(frame, false, false) end

    if frame.health then
        frame.health:SetMinMaxValues(0, 1)
        frame.health:SetValue(0)
        frame.health:SetStatusBarColor(unpack(self.colors.health))
    end
    if frame.power then
        frame.power:SetMinMaxValues(0, 1)
        frame.power:SetValue(0)
        frame.power:SetStatusBarColor(unpack(self.colors.power))
    end

    if frame.classIndicator then
        frame.classIndicator:SetAlpha(0)
    end
    if frame.roleIndicator then
        SetPartyRole(frame.roleIndicator, "NONE")
        frame.roleIndicator:SetAlpha(0)
    end

    if frame.oneBarSkinTexture then
        local setting = frame.settingKey and self:GetFrameSetting(frame.settingKey)
        local showPower = not (setting and setting.forceOneBar)
        frame.skin:SetAlpha(showPower and 1 or 0)
        frame.oneBarSkin:SetAlpha(showPower and 0 or 1)
        if frame.power then frame.power:SetShown(showPower) end
        if frame.power and frame.power.background then
            frame.power.background:SetShown(showPower)
        end
        if frame.powerText then frame.powerText:SetShown(showPower) end
        if frame.ApplyPowerLayout then
            frame:ApplyPowerLayout(showPower)
        end
    end

    if frame.portrait then
        if frame.portrait.model then
            frame.portrait.modelRequested = false
            frame.portrait.modelReady = false
            frame.portrait.model:ClearModel()
            frame.portrait.model:Hide()
        end
        if frame.portrait.fallback then
            frame.portrait.fallback:SetTexture(nil)
            frame.portrait.fallback:Show()
        end
    end

    for _, auraFrame in ipairs(frame.auras or {}) do
        auraFrame:SetAlpha(0)
    end
    for _, auraFrame in ipairs(frame.debuffs or {}) do
        auraFrame:SetAlpha(0)
    end
    for _, holder in ipairs({ frame.nativeBuffs, frame.nativeDebuffs, frame.nativeMaintenance }) do
        if holder and holder.container and holder.container.prettyFramesEnabled then
            holder.container:SetEnabled(false)
            holder.container.prettyFramesEnabled = false
        end
    end

    if frame.isRaidFrame then
        self:UpdateRaidPresentation(frame, false, tonumber(frame.unit and frame.unit:match("%d+")) or 1, false, false)
    elseif frame.isPartyFrame and self.UpdatePartyPresentation then
        self:UpdatePartyPresentation(frame, false, tonumber(frame.unit and frame.unit:match("%d+")) or 1)
    end
end

function PF:UpdateUnitFrame(frame, updateModel)
    if frame.isBossFrame and self.db and self.db.replaceBossFrames ~= true then
        self:ClearUnitFrameData(frame)
        return
    end
    local unit = frame.unit
    local exists = UnitExists(unit)
    local previewIndex = tonumber(unit:match("%d+")) or 1
    local previewLimit = unit:find("raid") and 22 or (unit:find("^boss") and 5 or 4)
    local testPreview = self.testMode
        and (unit == "player" or unit == "target" or unit == "focus" or previewIndex <= previewLimit)
    if not exists and not testPreview then
        self:ClearUnitFrameData(frame)
        return
    end

    local name, surname, health, healthMax, powerType, power, powerMax
    if exists then
        -- Forever uses UnitName's second return for a character surname.  On
        -- clients without surnames this remains nil (or is the remote realm).
        name, surname = UnitName(unit)
        health = UnitHealth(unit)
        healthMax = UnitHealthMax(unit)
        powerType = UnitPowerType(unit)
        power = UnitPower(unit, powerType)
        powerMax = UnitPowerMax(unit, powerType)
    else
        if unit:find("raid") then
            name = raidTestNames[previewIndex] or "Raid Member " .. previewIndex
        elseif unit:find("^boss") then
            local bossTestNames = { "The Verdant Warden", "Ashmaw", "High Sage Lyris", "The Hollow King", "Dreadwing" }
            name = bossTestNames[previewIndex] or "Boss " .. previewIndex
        else
            name = unit:gsub("^%l", string.upper)
        end
        health = 78 - previewIndex * 3
        healthMax = 100
        powerType = 0
        power = 67
        powerMax = 100
    end
    local r, g, b
    if exists then
        r, g, b = UnitColor(unit)
    else
        if unit:find("^boss") then
            r, g, b = 0.72, 0.12, 0.10
        else
            r, g, b = 0.24, 0.64, 0.12
        end
    end

    SetBarValue(frame.health, health, healthMax)
    frame.health:SetStatusBarColor(r, g, b)
    SetUnitNameToFit(frame, name, surname)

    if frame.classIndicator then
        local classFile
        if exists then
            local isPlayer = UnitIsPlayer(unit)
            if self:IsDisplaySafe(isPlayer) and isPlayer == true then
                _, classFile = UnitClass(unit)
            end
        elseif testPreview then
            _, classFile = UnitClass("player")
        end
        if not self:IsDisplaySafe(classFile) then
            classFile = nil
        end
        local coordinates = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
        if coordinates then
            frame.classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            frame.classIcon:SetTexCoord(coordinates[1], coordinates[2], coordinates[3], coordinates[4])
            frame.classIndicator:SetAlpha(1)
        elseif frame.isBossFrame then
            local classification = exists and UnitClassification and UnitClassification(unit)
            if testPreview or (self:IsDisplaySafe(classification)
                and (classification == "worldboss" or classification == "elite"
                    or classification == "rareelite")) then
                frame.classIcon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
                frame.classIcon:SetTexCoord(0, 1, 0, 1)
                frame.classIndicator:SetAlpha(1)
            else
                frame.classIndicator:SetAlpha(0)
            end
        else
            frame.classIndicator:SetAlpha(0)
        end
    end

    if frame.roleIndicator then
        frame.roleIndicator:SetAlpha(1)
        local role = "NONE"
        if exists and UnitGroupRolesAssigned then
            role = UnitGroupRolesAssigned(unit)
        elseif testPreview then
            local previewRoles = { "TANK", "HEALER", "DAMAGER", "DAMAGER" }
            role = previewRoles[previewIndex] or "DAMAGER"
        end
        if not self:IsDisplaySafe(role) then
            role = "NONE"
        end
        SetPartyRole(frame.roleIndicator, role)
    end

    if frame.power then
        SetBarValue(frame.power, power, powerMax)
        local color = PF.colors.power
        if self:IsDisplaySafe(powerType) then
            color = powerColors[powerType] or color
        end
        frame.power:SetStatusBarColor(color[1], color[2], color[3])

        -- A plain maximum is definitive. Forever protects many NPC maxima,
        -- including a literal 0, from addon comparisons. UnitHasPowerType can
        -- still report Mana for those 0/0 NPCs, so protected NPCs default to
        -- the one-bar artwork while protected player targets retain two bars.
        if frame.oneBarSkinTexture then
            local setting = frame.settingKey and self:GetFrameSetting(frame.settingKey)
            local showPower = not (setting and setting.forceOneBar)
            if showPower and self:IsDisplaySafe(powerMax) then
                showPower = powerMax > 0
            elseif showPower and UnitHasPowerType and self:IsDisplaySafe(powerType) then
                local hasPower = UnitHasPowerType(unit, powerType)
                if self:IsDisplaySafe(hasPower) then
                    if not hasPower then
                        showPower = false
                    else
                        local isPlayer = UnitIsPlayer(unit)
                        showPower = not self:IsDisplaySafe(isPlayer) or isPlayer == true
                    end
                end
            end
            frame.skin:SetAlpha(showPower and 1 or 0)
            frame.oneBarSkin:SetAlpha(showPower and 0 or 1)
            frame.power:SetShown(showPower)
            frame.power.background:SetShown(showPower)
            frame.powerText:SetShown(showPower)
            frame.power:SetAlpha(1)
            frame.power.background:SetAlpha(1)
            frame.powerText:SetAlpha(1)
            if frame.ApplyPowerLayout then
                frame:ApplyPowerLayout(showPower)
            end
        end
    end

    local connected = exists and UnitIsConnected(unit)
    local dead = exists and UnitIsDeadOrGhost(unit)
    local afk = exists and UnitIsAFK and UnitIsAFK(unit)
    local disconnected = self:IsDisplaySafe(connected) and connected == false
    dead = self:IsDisplaySafe(dead) and dead == true
    afk = self:IsDisplaySafe(afk) and afk == true
    local function SetStatusText(text)
        if frame.isRaidFrame and self.SetRaidStatusText then
            self:SetRaidStatusText(frame, text)
        else
            frame.statusText:SetText(text)
        end
    end
    if disconnected then
        SetStatusText("OFFLINE")
    elseif dead then
        local ghost = UnitIsGhost(unit)
        SetStatusText(self:IsDisplaySafe(ghost) and ghost and "GHOST" or "DEAD")
        frame.health:SetStatusBarColor(unpack(self.colors.dead))
    elseif afk then
        SetStatusText("AFK")
    else
        SetStatusText("")
    end

    if frame.levelText then
        local level = exists and UnitLevel(unit)
        if not exists then
            level = 60
        end
        if self:IsDisplaySafe(level) then
            frame.levelText:SetText(level > 0 and level or "??")
        else
            frame.levelText:SetText("")
        end
    end

    if frame.healthText then
        if frame.isRaidFrame and self.UpdateRaidHealthText then
            self:UpdateRaidHealthText(frame, health, healthMax)
        else
            local currentText = self:FormatNumber(health)
            local maxText = self:FormatNumber(healthMax)
            if currentText and maxText then
                frame.healthText:SetText(currentText .. " / " .. maxText)
            else
                -- FontString's native formatter accepts Forever's protected values;
                -- Lua string.format/tostring and arithmetic intentionally do not.
                frame.healthText:SetFormattedText("%s / %s", health, healthMax)
            end
        end
    end
    if frame.powerText then
        local currentText = self:FormatNumber(power)
        local maxText = self:FormatNumber(powerMax)
        if currentText and maxText then
            frame.powerText:SetText(currentText .. " / " .. maxText)
        else
            frame.powerText:SetFormattedText("%s / %s", power, powerMax)
        end
    end

    if frame.unitMarker and not frame.isRaidFrame then
        local markerIndex = exists and GetRaidTargetIndex and GetRaidTargetIndex(unit)
        local markerIsSecret = issecretvalue and issecretvalue(markerIndex)
        if not markerIsSecret and not markerIndex and testPreview then
            if unit == "target" then
                markerIndex = 8
            elseif unit == "focus" then
                markerIndex = 1
            elseif unit:find("^boss") and previewIndex == 1 then
                markerIndex = 8
            elseif unit:find("^party") and previewIndex == 1 then
                markerIndex = 6
            end
        end
        SetRaidMarkerTexture(frame.unitMarker, markerIndex)
    end

    if frame.isRaidFrame then
        self:UpdateRaidPresentation(frame, exists, previewIndex, disconnected, dead)
    elseif frame.isPartyFrame and self.UpdatePartyPresentation then
        self:UpdatePartyPresentation(frame, exists, previewIndex)
    end
    if frame.hasThreatDisplay then
        self:UpdateTargetThreat(frame, exists, testPreview)
    end

    if frame.portrait and updateModel then
        if exists then
            SetPortraitTexture(frame.portrait.fallback, unit)
            local visible = UnitIsVisible(unit)
            if self:IsDisplaySafe(visible) and visible then
                RequestPortraitModel(frame.portrait, unit)
            else
                ShowPortraitFallback(frame.portrait)
            end
        elseif testPreview and unit:find("^boss") then
            frame.portrait.fallback:SetTexture("Interface\\Icons\\INV_Misc_Head_Dragon_01")
            ShowPortraitFallback(frame.portrait)
        elseif testPreview and unit:find("^party") then
            SetPortraitTexture(frame.portrait.fallback, "player")
            RequestPortraitModel(frame.portrait, "player")
        elseif unit ~= "player" then
            ShowPortraitFallback(frame.portrait)
        end
    end

    self:UpdateAuras(frame)
end
