local _, PF = ...

-- Theme API. Theme files are ordinary Lua and are loaded by PrettyFrames.toc.
-- Add another Theme.lua to the TOC and register it here to make it selectable.
PF.themes = {}
PF.themeOrder = {}
PF.defaultTheme = "verdant"
PF.themeLayoutProxies = {}
PF.themeDefinitions = {}

local function IsArray(value)
    if type(value) ~= "table" then return false end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
        count = math.max(count, key)
    end
    return count > 0
end

local function Copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do
        result[Copy(key, seen)] = Copy(child, seen)
    end
    return result
end

-- Dictionaries merge recursively; arrays are replaced as complete authored
-- values. This keeps point, size, crop, and color tuples predictable.
local function Merge(target, source)
    if type(source) ~= "table" then return Copy(source) end
    if IsArray(source) then return Copy(source) end
    if type(target) ~= "table" or IsArray(target) then target = {} end
    for key, value in pairs(source) do
        if type(value) == "table" and not IsArray(value) then
            target[key] = Merge(target[key], value)
        else
            target[key] = Copy(value)
        end
    end
    return target
end

local function ResolvePreset(theme, kind, selection, frameName)
    if selection == nil then return nil end
    local presetName
    local overrides
    if type(selection) == "string" then
        presetName = selection
    elseif type(selection) == "table" and selection.use then
        presetName = selection.use
        overrides = selection.overrides
    elseif type(selection) == "table" then
        return Copy(selection)
    else
        error("PrettyFrames " .. kind .. " selection for " .. frameName .. " must be a name or table")
    end

    local presets = theme.globals and theme.globals[kind]
    local preset = presets and presets[presetName]
    assert(preset, "PrettyFrames frame " .. frameName .. " references missing "
        .. kind .. " preset: " .. tostring(presetName))
    return Merge(Copy(preset), overrides)
end

local function CompileTheme(id, definition)
    local theme = Copy(definition)
    theme.id = id
    theme.assets = theme.assets or {}
    theme.layout = theme.layout or {}
    theme.globals = theme.globals or {}
    theme.globals.art = theme.globals.art or {}
    theme.globals.layout = theme.globals.layout or {}
    local legacySections = {
        screen = true, widgets = true, classResources = true, castBar = true,
        nameplate = true, party = true, player = true, bossFrames = true,
        unitFrames = true, raid = true,
    }
    -- Named presets matching the established runtime sections automatically
    -- feed that compatibility surface. Theme authors can therefore store the
    -- source of truth under globals.layout without duplicating it.
    for section, value in pairs(theme.globals.layout) do
        if legacySections[section] and theme.layout[section] == nil then
            theme.layout[section] = Copy(value)
        end
    end
    -- Conversely, old layout sections become named presets. This makes a
    -- single-file third-party theme immediately composable and gives it an
    -- incremental migration path instead of requiring a flag day rewrite.
    for section, value in pairs(theme.layout) do
        if theme.globals.layout[section] == nil then
            theme.globals.layout[section] = Copy(value)
        end
    end
    theme.resolvedFrames = {}

    -- Old themes described frame families through global layout sections.
    -- Synthesize frame-level views so runtime code can use the new API before
    -- every third-party theme has migrated its authoring files.
    local legacyLayoutSections = {
        player = "player",
        pet = "player",
        target = "unitFrames",
        focus = "unitFrames",
        targettarget = "unitFrames",
        boss = "unitFrames",
        party = "party",
        raid = "raid",
        nameplate = "nameplate",
        castBar = "castBar",
        classResources = "classResources",
        screen = "screen",
        widgets = "widgets",
    }
    for frameName, section in pairs(legacyLayoutSections) do
        if theme.layout[section] then
            theme.resolvedFrames[frameName] = {
                art = Copy(theme.assets),
                layout = Copy(theme.layout[section]),
            }
        end
    end

    for frameName, frame in pairs(theme.frames or {}) do
        assert(type(frame) == "table", "PrettyFrames frame definition must be a table: " .. frameName)
        local resolved = {
            art = ResolvePreset(theme, "art", frame.art, frameName),
            layout = ResolvePreset(theme, "layout", frame.layout, frameName),
        }
        local legacy = theme.resolvedFrames[frameName]
        theme.resolvedFrames[frameName] = {
            art = resolved.art or (legacy and legacy.art),
            layout = resolved.layout or (legacy and legacy.layout),
        }

        -- A frame family may continue feeding the legacy runtime layout while
        -- modules migrate to frame-specific lookups. Explicit layoutSection
        -- avoids making author-facing frame names depend on old section names.
        if resolved.layout and frame.layoutSection then
            theme.layout[frame.layoutSection] = Copy(resolved.layout)
        end
        -- Art presets use runtime-neutral role names. legacyAssets is an
        -- optional bridge for modules that still request the old global key.
        for role, legacyRole in pairs(frame.legacyAssets or {}) do
            local fileName = resolved.art and resolved.art[role]
            if fileName then theme.assets[legacyRole] = fileName end
        end
    end

    assert(type(theme.name) == "string", "PrettyFrames theme needs a display name")
    assert(type(theme.path) == "string", "PrettyFrames theme needs an asset path")
    assert(next(theme.assets) ~= nil or next(theme.globals.art) ~= nil,
        "PrettyFrames theme needs assets or frame art presets")
    assert(next(theme.layout) ~= nil or next(theme.globals.layout) ~= nil,
        "PrettyFrames theme needs layout data or frame layout presets")
    return theme
end

function PF:RegisterTheme(id, theme)
    assert(type(id) == "string" and id ~= "", "PrettyFrames theme id must be a non-empty string")
    assert(type(theme) == "table", "PrettyFrames theme must be a table")
    if not self.themes[id] then
        table.insert(self.themeOrder, id)
    end
    local definition = Merge(self.themeDefinitions[id], theme)
    self.themeDefinitions[id] = definition
    self.themes[id] = CompileTheme(id, definition)
end

-- Lets a theme keep metadata, shared presets, and frame families in separate
-- small files. RegisterTheme must still be the final call so incomplete
-- authoring data is never visible to the rest of the addon.
function PF:ExtendTheme(id, fragment)
    assert(type(id) == "string" and id ~= "", "PrettyFrames theme id must be a non-empty string")
    assert(type(fragment) == "table", "PrettyFrames theme fragment must be a table")
    assert(not self.themes[id], "PrettyFrames theme fragments must load before RegisterTheme: " .. id)
    self.themeDefinitions[id] = Merge(self.themeDefinitions[id], fragment)
end

function PF:GetTheme(id)
    local savedTheme = self.db and self.db.theme
    return self.themes[id or savedTheme or self.defaultTheme]
        or self.themes[self.defaultTheme]
end

function PF:ThemeAsset(name)
    local theme = self:GetTheme()
    local fileName = theme and theme.assets[name]
    assert(fileName, "PrettyFrames theme is missing asset: " .. tostring(name))
    return theme.path .. fileName
end

function PF:ThemeFrame(frameName, id)
    local theme = self:GetTheme(id)
    local frame = theme and theme.resolvedFrames and theme.resolvedFrames[frameName]
    assert(frame, "PrettyFrames theme is missing frame definition: " .. tostring(frameName))
    return frame
end

function PF:ThemeFrameAsset(frameName, role, fallbackRole)
    local theme = self:GetTheme()
    local frame = theme and theme.resolvedFrames and theme.resolvedFrames[frameName]
    local fileName = frame and frame.art and frame.art[role]
    if not fileName and fallbackRole then fileName = theme.assets[fallbackRole] end
    assert(fileName, "PrettyFrames theme frame " .. tostring(frameName)
        .. " is missing art role: " .. tostring(role))
    return theme.path .. fileName
end

function PF:ThemeFrameLayout(frameName, fallbackSection)
    local theme = self:GetTheme()
    local frame = theme and theme.resolvedFrames and theme.resolvedFrames[frameName]
    local layout = frame and frame.layout
    if not layout and fallbackSection then layout = theme.layout[fallbackSection] end
    assert(layout, "PrettyFrames theme frame " .. tostring(frameName) .. " is missing layout")
    return layout
end

-- Frame modules are loaded before ADDON_LOADED initializes PF.db. Returning a
-- concrete layout table here would permanently cache the fallback theme in
-- file-local variables, even though assets later resolve from the selected
-- theme. Keep one stable proxy per section and resolve its fields lazily.
function PF:ThemeLayout(section)
    local proxy = self.themeLayoutProxies[section]
    if proxy then return proxy end

    local function CurrentLayout()
        local theme = PF:GetTheme()
        local frame = theme and theme.resolvedFrames and theme.resolvedFrames[section]
        local layout = (frame and frame.layout) or (theme and theme.layout[section])
        assert(layout, "PrettyFrames theme is missing layout: " .. tostring(section))
        return layout
    end

    proxy = setmetatable({}, {
        __index = function(_, key)
            return CurrentLayout()[key]
        end,
        -- ResolveThemePoints stores mirrored-point caches on the supplied
        -- layout. Forward those writes to the selected theme rather than
        -- trapping them on the proxy itself.
        __newindex = function(_, key, value)
            CurrentLayout()[key] = value
        end,
    })
    self.themeLayoutProxies[section] = proxy
    return proxy
end

-- Keeps Theme.lua tables compact and gives every point the same readable shape.
function PF:SetThemePoint(region, relativeTo, point)
    region:SetPoint(point[1], relativeTo, point[2], point[3], point[4])
end

local mirroredAnchors = {
    LEFT = "RIGHT",
    RIGHT = "LEFT",
    TOPLEFT = "TOPRIGHT",
    TOPRIGHT = "TOPLEFT",
    BOTTOMLEFT = "BOTTOMRIGHT",
    BOTTOMRIGHT = "BOTTOMLEFT",
}

-- Reflects one anchor tuple across its relative region's vertical center.
-- CENTER, TOP, and BOTTOM pass through unchanged.
function PF:MirrorThemePoint(point)
    return {
        mirroredAnchors[point[1]] or point[1],
        mirroredAnchors[point[2]] or point[2],
        -point[3],
        point[4],
    }
end

-- Theme layouts store one canonical (portrait-left) point set. Mirrored points
-- are derived once and cached; sparse overrides are reserved for optical fixes.
function PF:ResolveThemePoints(layout, mirrored, pointsKey, overridesKey, cacheKey)
    pointsKey = pointsKey or "points"
    overridesKey = overridesKey or "mirrorOverrides"
    cacheKey = cacheKey or "_resolvedMirrorPoints"
    local points = layout[pointsKey]
    assert(type(points) == "table", "PrettyFrames layout needs a points table")
    if not mirrored then return points end
    if layout[cacheKey] then return layout[cacheKey] end

    local resolved = {}
    for key, point in pairs(points) do
        resolved[key] = self:MirrorThemePoint(point)
    end
    for key, point in pairs(layout[overridesKey] or {}) do
        assert(points[key], "PrettyFrames mirror override has no canonical point: " .. tostring(key))
        resolved[key] = point
    end
    layout[cacheKey] = resolved
    return resolved
end

-- Applies sparse numeric corrections to a canonical array. This is used for
-- aura layout values whose mirrored algorithm already changes growth direction.
function PF:ResolveThemeValues(values, mirrored, mirrorCorrections)
    if not mirrored or not mirrorCorrections then return values end
    local resolved = {}
    local count = math.max(#values, #mirrorCorrections)
    for index = 1, count do
        resolved[index] = (values[index] or 0) + (mirrorCorrections[index] or 0)
    end
    return resolved
end

