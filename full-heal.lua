-- Attempts to fully heal the selected unit
--author Kurik Amudnil, Urist DaVinci
--edited by expwnent and AtomicChicken

--[====[

full-heal
=========
Attempts to fully heal the selected unit from anything, optionally
including death.  Usage:

:full-heal:
    Completely heal the currently selected unit.
:full-heal -unit [unitId]:
    Apply command to the unit with the given ID, instead of selected unit.
:full-heal -r [-keep_corpse]:
    Heal the unit, raising from the dead if needed.
    Add ``-keep_corpse`` to avoid removing their corpse.

For example, ``full-heal -r -keep_corpse -unit ID_NUM`` will fully heal
unit ID_NUM.  If this unit was dead, it will be resurrected without deleting
the corpse - creepy!

]====]

local utils = require('utils')

local validArgs = utils.invert({
    'r',
    'help',
    'unit',
    'keep_corpse',
})

local args = utils.processArgs({...}, validArgs)

if args.help then
    print(dfhack.script_help())
    return
end

local item = dfhack.gui.getSelectedItem(true)
local unit
if args.unit then
    unit = df.unit.find(tonumber(args.unit))
elseif df.item_corpsest:is_instance(item) then
    unit = df.unit.find(item.unit_id) --hint:df.item_corpsest
else
    unit = dfhack.gui.getSelectedUnit()
end

if not unit then
    qerror('Error: please select a unit or pass its ID as an argument.')
end

if unit then
    if args.r then
        if unit.flags2.killed then
            --print("Resurrecting...")
            unit.flags2.slaughter = false
            unit.flags3.scuttle = false
        end
        unit.flags1.inactive = false
        unit.flags2.killed = false
        unit.flags3.ghostly = false
        if not args.keep_corpse then
            for _, corpse in ipairs(df.global.world.items.other.CORPSE) do --as:df.item_body_component
                if corpse.unit_id == unit.id then
                    corpse.flags.garbage_collect = true
                    corpse.flags.forbid = true
                    corpse.flags.hidden = true
                end
            end
        end
        --unit.unk_100 = 3
    end

    --print("Erasing wounds...")
    for _, wound in ipairs(unit.body.wounds) do
        wound:delete()
    end
    unit.body.wounds:resize(0)
    unit.body.wound_next_id = 1

    --print("Refilling blood...")
    unit.body.blood_count = unit.body.blood_max

    --print("Resetting grasp/stand/fly status...")
    unit.status2.limbs_stand_count = unit.status2.limbs_stand_max
    unit.status2.limbs_grasp_count = unit.status2.limbs_grasp_max
    unit.status2.limbs_fly_count = unit.status2.limbs_fly_max

    --print("Resetting status flags...")
    unit.flags2.has_breaks = false
    unit.flags2.gutted = false
    unit.flags2.circulatory_spray = false
    unit.flags2.vision_good = true
    unit.flags2.vision_damaged = false
    unit.flags2.vision_missing = false
    unit.flags2.breathing_good = true
    unit.flags2.breathing_problem = false

    unit.flags2.calculated_nerves = false
    unit.flags2.calculated_bodyparts = false
    unit.flags2.calculated_insulation = false
    unit.flags3.body_temp_in_range = false
    unit.flags3.compute_health = true
    unit.flags3.gelded = false

    --print("Resetting counters...")
    unit.counters.winded = 0
    unit.counters.stunned = 0
    unit.counters.unconscious = 0
    unit.counters.webbed = 0
    unit.counters.pain = 0
    unit.counters.nausea = 0
    unit.counters.dizziness = 0
    unit.counters.suffocation = 0
    unit.counters.guts_trail1.x = -30000
    unit.counters.guts_trail1.y = -30000
    unit.counters.guts_trail1.z = -30000
    unit.counters.guts_trail2.x = -30000
    unit.counters.guts_trail2.y = -30000
    unit.counters.guts_trail2.z = -30000

    unit.counters2.paralysis = 0
    unit.counters2.numbness = 0
    unit.counters2.fever = 0
    unit.counters2.exhaustion = 0
    unit.counters2.hunger_timer = 0
    unit.counters2.thirst_timer = 0
    unit.counters2.sleepiness_timer = 0
    unit.counters2.vomit_timeout = 0

    unit.animal.vanish_countdown = 0

    unit.body.infection_level = 0

    --print("Resetting body part status...")
    local comp = unit.body.components
    for i = 0, #comp.nonsolid_remaining - 1 do
        comp.nonsolid_remaining[i] = 100    -- percent remaining of fluid layers (Urist Da Vinci)
    end

    for i = 0, #comp.layer_wound_area - 1 do
        comp.layer_status[i].whole = 0        -- severed, leaking layers (Urist Da Vinci)
        comp.layer_wound_area[i] = 0        -- wound contact areas (Urist Da Vinci)
        comp.layer_cut_fraction[i] = 0        -- 100*surface percentage of cuts/fractures on the body part layer (Urist Da Vinci)
        comp.layer_dent_fraction[i] = 0        -- 100*surface percentage of dents on the body part layer (Urist Da Vinci)
        comp.layer_effect_fraction[i] = 0        -- 100*surface percentage of "effects" on the body part layer (Urist Da Vinci)
    end

    for _, status in ipairs(unit.body.components.body_part_status) do
        status.on_fire = false
        status.missing = false
        status.organ_loss = false
        status.organ_damage = false
        status.muscle_loss = false
        status.muscle_damage = false
        status.bone_loss = false
        status.bone_damage = false
        status.skin_damage = false
        status.motor_nerve_severed = false
        status.sensory_nerve_severed = false
        status.spilled_guts = false
        status.severed_or_jammed = false
    end

    for i = #unit.status2.body_part_temperature-1,0,-1 do
      unit.status2.body_part_temperature:erase(i) -- attempting to rewrite temperature was causing body parts to melt for some reason; forcing repopulation in this manner appears to be safer
    end

    for i = 0,#unit.enemy.body_part_8a8-1,1 do
      unit.enemy.body_part_8a8[i] = 1 -- not sure what this does, but values appear to change following injuries
    end
    for i = 0,#unit.enemy.body_part_8d8-1,1 do
      unit.enemy.body_part_8d8[i] = 0 -- same as above
    end
    for i = 0,#unit.enemy.body_part_878-1,1 do
      unit.enemy.body_part_878[i] = 3 -- as above
    end
    for i = 0,#unit.enemy.body_part_888-1,1 do
      unit.enemy.body_part_888[i] = 3 -- as above
    end

    local histFig = df.historical_figure.find(unit.hist_figure_id)
    if histFig and histFig.info and histFig.info.wounds then
      --print("Clearing historical wounds...")
      histFig.info.wounds = nil
    end

    local health = unit.health
    if health then
      for i = 0, #health.flags-1,1 do
        health.flags[i] = false
      end
      for _,bpFlags in ipairs(health.body_part_flags) do
        for i = 0, #bpFlags-1,1 do
          bpFlags[i] = false
        end
      end
      health.immobilize_cntdn = 0
      health.dressing_cntdn = 0
      health.suture_cntdn = 0
      health.crutch_cntdn = 0
      health.unk_18_cntdn = 0
    end

    local job = unit.job.current_job
    if job and job.job_type == df.job_type.Rest then
        --print("Wake from rest...")
        job.completion_timer = 0
        job.pos:assign(unit.pos)
    end

    local job_link = df.global.world.jobs.list.next
    while job_link do
      local doctor_job = job_link.item
      if doctor_job then
        local patientRef = dfhack.job.getGeneralRef(doctor_job, df.general_ref_type['UNIT_PATIENT']) --as:df.general_ref_unit_patientst
        if patientRef and patientRef.unit_id == unit.id then
          patientRef.unit_id = -1 -- causes active healthcare job to be cancelled, generating a job cancellation announcement indicating the lack of a patient
          break
        end
      end
      job_link = job_link.next
    end
end

