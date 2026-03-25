local mods = rom.mods
mods['SGG_Modding-ENVY'].auto()

---@diagnostic disable: lowercase-global
rom = rom
_PLUGIN = _PLUGIN
game = rom.game
modutil = mods['SGG_Modding-ModUtil']
chalk = mods['SGG_Modding-Chalk']
reload = mods['SGG_Modding-ReLoad']
local lib = mods['adamant-Modpack_Lib']

config = chalk.auto('config.lua')
public.config = config

local backup, revert = lib.createBackupSystem()

-- =============================================================================
-- UTILITIES
-- =============================================================================


-- =============================================================================
-- MODULE DEFINITION
-- =============================================================================

public.definition = {
    id       = "ETFix",
    name     = "ET Fixes",
    category = "Bug Fixes",
    group    = "Boons & Hammers",
    tooltip  = "Fixes ET working with Anubis by creating a 3rd OAtk field.\nFixes Anubis OAtk distance based on casting angle.",
    default  = true,
    dataMutation = true,
    modpackModule = true,
}

-- =============================================================================
-- MODULE LOGIC
-- =============================================================================

local function apply()
    if not TraitData.DoubleExManaBoon then return end
    backup(TraitData, "DoubleExManaBoon")

    table.insert(TraitData.DoubleExManaBoon.PropertyChanges[1].FalseTraitNames, 
                    "StaffRaiseDeadAspect")
                    
    TraitData.DoubleExManaBoon.OnWeaponFiredFunctions = {
        ValidWeapons = { "WeaponStaffSwing5" },
        FunctionName = "CreateSecondAnubisWall",
        FunctionArgs = { Distance = 340 },
        ExcludeLinked = true,
    }
end

local function registerHooks()
    modutil.mod.Path.Wrap("CreateSecondAnubisWall", function(baseFunc, weaponData, args, triggerArgs)
        if not lib.isEnabled(config) then return baseFunc(weaponData, args, triggerArgs) end

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
-- Wiring
-- =============================================================================

public.definition.apply = apply
public.definition.revert = revert

local loader = reload.auto_single()

modutil.once_loaded.game(function()
    loader.load(function()
        import_as_fallback(rom.game)
        registerHooks()
        if lib.isEnabled(config) then apply() end
        if public.definition.dataMutation and not mods['adamant-Modpack_Core'] then
            SetupRunData()
        end
    end)
end)

local uiCallback = lib.standaloneUI(public.definition, config, apply, revert)
rom.gui.add_to_menu_bar(uiCallback)
