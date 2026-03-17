-- =============================================================================
-- BOILERPLATE (do not modify)
-- =============================================================================

local mods = rom.mods
mods['SGG_Modding-ENVY'].auto()

---@diagnostic disable: lowercase-global
rom = rom
_PLUGIN = _PLUGIN
game = rom.game
modutil = mods['SGG_Modding-ModUtil']
chalk = mods['SGG_Modding-Chalk']
reload = mods['SGG_Modding-ReLoad']

config = chalk.auto('config.lua')
public.config = config

local NIL = {}
local backups = {}

local function backup(tbl, key)
    if not backups[tbl] then backups[tbl] = {} end
    if backups[tbl][key] == nil then
        local v = tbl[key]
        backups[tbl][key] = v == nil and NIL or (type(v) == "table" and DeepCopyTable(v) or v)
    end
end

local function restore()
    for tbl, keys in pairs(backups) do
        for key, v in pairs(keys) do
            tbl[key] = v == NIL and nil or (type(v) == "table" and DeepCopyTable(v) or v)
        end
    end
end

local function isEnabled()
    return config.Enabled
end

-- =============================================================================
-- UTILITIES
-- =============================================================================

local function SafeArrayInsert(tbl, fieldName, value)
    if tbl[fieldName] then
        if not Contains(tbl[fieldName], value) then
            table.insert(tbl[fieldName], value)
        end
    end
end

-- =============================================================================
-- MODULE DEFINITION
-- =============================================================================

public.definition = {
    id       = "ETFix",
    name     = "ET Fixes",
    category = "BugFixes",
    group    = "Boons & Hammers",
    tooltip  = "Fixes ET working with Anubis by creating a 3rd OAtk field.\nFixes Anubis OAtk distance based on casting angle.",
    default  = true,
}

-- =============================================================================
-- MODULE LOGIC
-- =============================================================================

local function apply()
    if not TraitData.DoubleExManaBoon then return end
    backup(TraitData, "DoubleExManaBoon")

    for _, propertyChange in ipairs(TraitData.DoubleExManaBoon.PropertyChanges or {}) do
        if Contains(propertyChange.FalseTraitNames, "StaffOneWayAttackTrait") then
            SafeArrayInsert(propertyChange, "FalseTraitNames", "StaffRaiseDeadAspect")
            break
        end
    end
    TraitData.DoubleExManaBoon.OnWeaponFiredFunctions = {
        ValidWeapons = { "WeaponStaffSwing5" },
        FunctionName = "CreateSecondAnubisWall",
        FunctionArgs = { Distance = 340 },
        ExcludeLinked = true,
    }
end

local function disable()
    restore()
end

local function registerHooks()
    modutil.mod.Path.Wrap("CreateSecondAnubisWall", function(baseFunc, weaponData, args, triggerArgs)
        if not isEnabled() then return baseFunc(weaponData, args, triggerArgs) end

        local weaponName = "WeaponStaffSwing5"
        local projectileName = "ProjectileStaffWall"
        local derivedValues = GetDerivedPropertyChangeValues({
            ProjectileName = projectileName,
            WeaponName = weaponName,
            Type = "Projectile",
        })

        local angle = GetAngle({ Id = CurrentRun.Hero.ObjectId })
        local radAngle = math.rad(angle)

        local baseDistance = 520
        local gapDistance = args.Distance - 520
        local isoRatio = 0.7

        local baseX = math.cos(radAngle) * baseDistance
        local baseY = -math.sin(radAngle) * baseDistance * isoRatio

        local gapX = math.cos(radAngle) * gapDistance
        local gapY = -math.sin(radAngle) * gapDistance

        local fixedOffsetX = baseX + gapX
        local fixedOffsetY = baseY + gapY

        CreateProjectileFromUnit({
            WeaponName = weaponName,
            Name = projectileName,
            OffsetX = fixedOffsetX,
            OffsetY = fixedOffsetY,
            Angle = angle,
            Id = CurrentRun.Hero.ObjectId,
            DestinationId = MapState.FamiliarLocationId,
            FireFromTarget = true,
            DataProperties = derivedValues.PropertyChanges,
            ThingProperties = derivedValues.ThingPropertyChanges,
            ExcludeFromCap = true,
        })
    end)
end

-- =============================================================================
-- PUBLIC API (do not modify)
-- =============================================================================

public.definition.enable = function()
    apply()
end

public.definition.disable = function()
    disable()
end

-- =============================================================================
-- LIFECYCLE (do not modify)
-- =============================================================================

local loader = reload.auto_single()

modutil.once_loaded.game(function()
    loader.load(function()
        import_as_fallback(rom.game)
        registerHooks()
        if config.Enabled then apply() end
    end)
end)
-- =============================================================================
-- STANDALONE UI (do not modify)
-- =============================================================================
-- When adamant-core is NOT installed, renders a minimal ImGui toggle.
-- When adamant-core IS installed, the core handles UI — this is skipped.

rom.gui.add_to_menu_bar(function()
    if mods['adamant-Core'] then return end
    if rom.ImGui.BeginMenu("adamant") then
        local val, chg = rom.ImGui.Checkbox(public.definition.name, config.Enabled)
        if chg then
            config.Enabled = val
            if val then apply() else disable() end
        end
        if rom.ImGui.IsItemHovered() and public.definition.tooltip ~= "" then
            rom.ImGui.SetTooltip(public.definition.tooltip)
        end
        rom.ImGui.EndMenu()
    end
end)
