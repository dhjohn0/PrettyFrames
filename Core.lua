local addonName, PF = ...

PF.name = addonName
PF.frames = {}
PF.unitFrames = {}
PF.contextFrames = {}
PF.configurableFrames = {}
PF.suppressedFrames = setmetatable({}, { __mode = "k" })
PF.MAX_AURAS = 40
PF.MIN_SCALE = 0.6
PF.MAX_SCALE = 1.6
-- Raid frames use very compact source dimensions. Treat this larger physical
-- size as their 100% baseline while keeping the saved Raid scale intuitive.
PF.RAID_BASE_SCALE = 1.25

PF.colors = {
    bronze = { 0.72, 0.42, 0.16, 1 },
    bronzeBright = { 0.95, 0.69, 0.30, 1 },
    leather = { 0.105, 0.065, 0.035, 0.96 },
    leatherLight = { 0.19, 0.105, 0.045, 0.96 },
    health = { 0.24, 0.64, 0.12, 1 },
    power = { 0.06, 0.34, 0.70, 1 },
    dead = { 0.28, 0.28, 0.28, 1 },
}
function PF:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd99a43PrettyFrames:|r " .. tostring(message))
end

function PF:IsDisplaySafe(value)
    if issecretvalue and issecretvalue(value) then
        return false
    end
    return value ~= nil
end

function PF:IsValidScale(scale)
    return type(scale) == "number" and scale >= self.MIN_SCALE and scale <= self.MAX_SCALE
end

function PF:FormatNumber(value)
    if not self:IsDisplaySafe(value) then
        return nil
    end
    if value >= 1000000 then
        return string.format("%.1fm", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fk", value / 1000)
    end
    return tostring(value)
end

-- Use Blizzard's dedicated number face for every numeric readout. Keeping this
-- here makes the treatment consistent without making fonts part of the theme.
function PF:ApplyBoldNumberFont(fontString, size)
    if not fontString then return end

    local _, currentSize = fontString:GetFont()
    local font, defaultSize, flags = NumberFontNormal:GetFont()
    fontString:SetFont(font, size or currentSize or defaultSize, flags)
end

