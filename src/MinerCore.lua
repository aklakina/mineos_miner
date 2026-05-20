---
--- MinerCore - single-threaded mining controller with FSM, persistence,
--- telemetry, HUD, distance-based fuel safety, vein-following, pluggable
--- mining patterns and remote control.
---

require('Logger')
require('coordinate')
require('betterTurtle')
require('environment')
require('fsm')
require('persistence')
require('hud')
require('telemetry')

MinerCore = {}

-- Module-level (deliberately not local) so unit tests can introspect.
local logger
local betterTurtle
local environment
local config = {}
local fsm
local hud
local telemetry
local stopTime          = nil  -- os.clock() deadline, or nil
local lastDumpClock     = 0
local lastTickYield     = 0
local lastPersistClock  = 0
local lastTelemetryClock = 0
local lastPruneClock    = 0
local gpsOffset         = nil  -- {x,y,z}: add to local pos to get world pos
local gotoTarget        = nil  -- Coordinate or nil
local pausedFromState   = nil  -- Stored when PAUSED entered
local oreCount          = 0    -- session statistic

minerStates = {
    MINING     = { name = "MINING" },
    FUELING    = { name = "FUELING" },
    NEEDS_FUEL = { name = "NEEDS_FUEL" },
    SEARCHING  = { name = "SEARCHING" },
    RETURNING  = { name = "RETURNING" },
    PAUSED     = { name = "PAUSED" },
    STOPPING   = { name = "STOPPING" },
}

local function allowedTransitions()
    local s = minerStates
    -- Every state can transition to STOPPING, PAUSED and (from PAUSED back to)
    -- SEARCHING.
    return {
        [s.SEARCHING]  = { [s.MINING]=true, [s.NEEDS_FUEL]=true, [s.RETURNING]=true, [s.FUELING]=true, [s.PAUSED]=true, [s.STOPPING]=true, [s.SEARCHING]=true },
        [s.MINING]     = { [s.SEARCHING]=true, [s.NEEDS_FUEL]=true, [s.RETURNING]=true, [s.PAUSED]=true, [s.STOPPING]=true },
        [s.FUELING]    = { [s.SEARCHING]=true, [s.RETURNING]=true, [s.STOPPING]=true, [s.PAUSED]=true },
        [s.NEEDS_FUEL] = { [s.SEARCHING]=true, [s.FUELING]=true, [s.RETURNING]=true, [s.STOPPING]=true, [s.PAUSED]=true },
        [s.RETURNING]  = { [s.SEARCHING]=true, [s.STOPPING]=true, [s.PAUSED]=true },
        [s.PAUSED]     = { [s.SEARCHING]=true, [s.STOPPING]=true },
        [s.STOPPING]   = { [s.STOPPING]=true },
    }
end

-- ---------------------------------------------------------------------------
-- Config
-- ---------------------------------------------------------------------------

local function loadConfig()
    local cfg = {}
    local file = io.open("config.ini", "r")
    if not file then
        return cfg
    end
    for line in file:lines() do
        local key, value = string.match(line, "([%w_]+)%s*=%s*([%w_.%-]+)")
        if key and value then
            cfg[key] = tonumber(value) or value
        end
    end
    file:close()
    return cfg
end

local function applyLoggerConfig(cfg)
    -- Honor entries like  log_MinerCore = DEBUG  in config.ini.
    local levels = {}
    for k, v in pairs(cfg) do
        if type(k) == "string" and k:sub(1, 4) == "log_" then
            levels[k:sub(5)] = v
        end
    end
    if next(levels) then Logger.setLevels(levels) end
    if cfg.log_default then Logger.setDefaultLevel(cfg.log_default) end
end

-- ---------------------------------------------------------------------------
-- Inventory & fuel helpers
-- ---------------------------------------------------------------------------

local ENDER_CHEST_NAMES = {
    ["enderstorage:ender_chest"]      = true,
    ["minecraft:ender_chest"]         = true,
    ["enderchests:ender_chest"]       = true,
    ["enderstorage:ender_storage"]    = true,
    ["minecraft:ender chest"]         = true,
}

-- Find the slot holding an ender chest (or nil). Allows fast drop-offs
-- without travelling all the way home.
local function findEnderChestSlot()
    for i = 1, 14 do
        if betterTurtle.getItemCount(i) > 0 then
            local d = betterTurtle.getItemDetail(i)
            if d and d.name and ENDER_CHEST_NAMES[d.name] then
                return i
            end
        end
    end
    return nil
end

local function dumpWaste()
    local dumped = 0
    for i = 1, 14 do
        local count = betterTurtle.getItemCount(i)
        local detail = betterTurtle.getItemDetail(i)
        if detail and environment:checkBlockType(detail.name) == blockType.WASTE then
            betterTurtle.select(i)
            betterTurtle.drop(count)
            dumped = dumped + count
        end
    end
    betterTurtle.select(1)
    if dumped > 0 then
        logger:debug("Dumped " .. dumped .. " waste items")
    end
    return dumped
end

-- Dump everything in slots 1..14 either into an ender chest (placed in front
-- of the turtle) or downwards (over the home base).
local function dumpAllItems(viaEnderChest)
    if viaEnderChest then
        local slot = findEnderChestSlot()
        if slot then
            -- Try to place the ender chest in front. If something is there,
            -- try up.
            local placed
            betterTurtle.select(slot)
            if not betterTurtle:actionInDirection("detect", directions.up) then
                placed = "up"
                betterTurtle:actionInDirection("place", directions.up)
            elseif not turtle.detect() then
                placed = "forward"
                turtle.place()
            elseif not betterTurtle:actionInDirection("detect", directions.down) then
                placed = "down"
                betterTurtle:actionInDirection("place", directions.down)
            end
            if placed then
                for i = 1, 14 do
                    if i ~= slot then
                        betterTurtle.select(i)
                        if placed == "up"      then turtle.dropUp()
                        elseif placed == "down" then turtle.dropDown()
                        else                         turtle.drop() end
                    end
                end
                -- Reclaim the chest.
                betterTurtle.select(slot)
                if placed == "up"      then turtle.digUp()
                elseif placed == "down" then turtle.digDown()
                else                         turtle.dig() end
                betterTurtle.select(1)
                return true
            end
        end
    end
    -- Fallback: drop everything below (base configuration).
    for i = 1, 14 do
        betterTurtle.select(i)
        betterTurtle.dropDown()
    end
    betterTurtle.select(1)
    return false
end

-- Stack-aware inventory check (delegates to BetterTurtle).
local function hasInventorySpace()
    return betterTurtle:hasInventoryCapacity()
end

local function tryRefuel(minLevel)
    local startLevel = betterTurtle.getFuelLevel()
    minLevel = minLevel or 1000
    if startLevel >= minLevel then return true end
    if betterTurtle.getItemCount(16) > 0 then
        betterTurtle.select(16)
        betterTurtle.refuel()
    end
    for i = 1, 14 do
        if betterTurtle.getFuelLevel() >= minLevel then break end
        if betterTurtle.getItemCount(i) > 0 then
            betterTurtle.select(i)
            pcall(betterTurtle.refuel)
        end
    end
    betterTurtle.select(1)
    return betterTurtle.getFuelLevel() > startLevel
end

-- Distance-based fuel safety margin: enough to get home plus 100 reserve.
local function fuelNeededToReturn()
    local p = betterTurtle.position
    return 2 * (math.abs(p.x) + math.abs(p.y) + math.abs(p.z)) + 100
end

-- ---------------------------------------------------------------------------
-- GPS calibration
-- ---------------------------------------------------------------------------

local function calibrateGPS()
    if type(gps) ~= "table" or type(gps.locate) ~= "function" then
        return false
    end
    local x, y, z = gps.locate(2)
    if not x then
        logger:debug("GPS unavailable; using relative coordinates.")
        return false
    end
    -- Local pos is (0,0,0) on startup if no state file; offset = world - local.
    local lp = betterTurtle.position
    gpsOffset = { x = x - lp.x, y = y - lp.y, z = z - lp.z }
    logger:info(("GPS locked: world=(%d,%d,%d) offset=(%d,%d,%d)"):format(
        x, y, z, gpsOffset.x, gpsOffset.y, gpsOffset.z))
    return true
end

local function worldPosition()
    local p = betterTurtle.position
    if gpsOffset then
        return { x = p.x + gpsOffset.x, y = p.y + gpsOffset.y, z = p.z + gpsOffset.z }
    end
    return { x = p.x, y = p.y, z = p.z }
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

local STATE_FILE = "state.dat"

local function saveState()
    if not betterTurtle or not environment then return end
    local p   = betterTurtle.position
    local d   = betterTurtle.direction
    Persistence.save(STATE_FILE, {
        position    = { p.x, p.y, p.z },
        direction   = d and d.name or "forward",
        minerState  = fsm and fsm:name() or "SEARCHING",
        gpsOffset   = gpsOffset,
        oreCount    = oreCount,
        env         = environment:toState(),
    })
end

local function loadState()
    local data = Persistence.load(STATE_FILE)
    if not data then return false end
    if data.position then
        betterTurtle.position = Coordinate:new(
            data.position[1], data.position[2], data.position[3],
            directions.forward)
    end
    if data.direction and directions[data.direction] then
        betterTurtle.direction = directions[data.direction]
    end
    gpsOffset = data.gpsOffset
    oreCount  = data.oreCount or 0
    if data.env then environment:loadState(data.env) end
    if data.minerState and minerStates[data.minerState] then
        fsm:force(minerStates[data.minerState])
    end
    logger:info("Restored state from " .. STATE_FILE
        .. " at position " .. tostring(betterTurtle.position)
        .. " in state " .. (fsm and fsm:name() or "?"))
    return true
end

-- ---------------------------------------------------------------------------
-- HUD & telemetry helpers
-- ---------------------------------------------------------------------------

local function updateHud()
    if not hud then return end
    local w = worldPosition()
    hud:setAll({
        state = fsm:name(),
        fuel  = betterTurtle.getFuelLevel(),
        pos   = ("[%d,%d,%d]"):format(w.x, w.y, w.z),
        ores  = oreCount,
    })
    hud:render()
end

local function buildStatus()
    return {
        state    = fsm:name(),
        fuel     = betterTurtle.getFuelLevel(),
        position = worldPosition(),
        ores     = oreCount,
        time     = os.clock(),
        id       = (os.getComputerID and os.getComputerID()) or 0,
        label    = (os.getComputerLabel and os.getComputerLabel()) or nil,
    }
end

local function handleControl(cmd)
    if not cmd or not cmd.cmd then return end
    logger:info("Remote command: " .. cmd.cmd)
    if cmd.cmd == "STOP" then
        fsm:force(minerStates.STOPPING)
    elseif cmd.cmd == "PAUSE" then
        if not fsm:is(minerStates.PAUSED) then
            pausedFromState = fsm.state
            fsm:force(minerStates.PAUSED)
        end
    elseif cmd.cmd == "RESUME" then
        if fsm:is(minerStates.PAUSED) then
            fsm:force(minerStates.SEARCHING)
            pausedFromState = nil
        end
    elseif cmd.cmd == "STATUS" then
        telemetry:broadcastStatus(buildStatus())
    elseif cmd.cmd == "GOTO" and cmd.args and #cmd.args >= 3 then
        local tx, ty, tz = cmd.args[1], cmd.args[2], cmd.args[3]
        if gpsOffset then
            tx, ty, tz = tx - gpsOffset.x, ty - gpsOffset.y, tz - gpsOffset.z
        end
        gotoTarget = Coordinate:new(tx, ty, tz, directions.forward)
        logger:info("GOTO target set: " .. tostring(gotoTarget))
    end
end

-- ---------------------------------------------------------------------------
-- tick() - the heartbeat
-- ---------------------------------------------------------------------------

local function tick()
    local now = os.clock()
    if now - lastTickYield > 1 then
        os.sleep(0)
        lastTickYield = now
    end

    if stopTime and now >= stopTime then
        if not fsm:is(minerStates.STOPPING) then
            logger:info("Session time elapsed; stopping.")
            fsm:force(minerStates.STOPPING)
        end
        return
    end

    if now - lastDumpClock > 20 then
        dumpWaste()
        lastDumpClock = now
    end

    if not hasInventorySpace() then
        dumpWaste()
        if not hasInventorySpace() and not fsm:is(minerStates.RETURNING) then
            -- Prefer ender chest if available.
            if findEnderChestSlot() then
                dumpAllItems(true)
            else
                logger:info("Inventory full; returning to base.")
                fsm:set(minerStates.RETURNING)
            end
        end
    end

    -- Fuel: distance-based threshold OR absolute floor.
    local fuelMin = math.max(config.fuelReturnThreshold or 100, fuelNeededToReturn())
    if betterTurtle.getFuelLevel() < fuelMin then
        if not tryRefuel(fuelMin)
           and not fsm:isAny(minerStates.NEEDS_FUEL, minerStates.RETURNING, minerStates.STOPPING) then
            logger:info("Low fuel ("..betterTurtle.getFuelLevel().." < "..fuelMin.."); switching to NEEDS_FUEL.")
            fsm:set(minerStates.NEEDS_FUEL)
        end
    end

    -- Remote control
    if telemetry then
        local cmd = telemetry:pollCommand()
        if cmd then handleControl(cmd) end
        if now - lastTelemetryClock > 5 then
            telemetry:tick(buildStatus())
            lastTelemetryClock = now
        end
    end

    -- Persistence: save every 5s.
    if now - lastPersistClock > 5 then
        saveState()
        lastPersistClock = now
    end

    -- Periodic prune of the explored-block cache to keep memory bounded.
    if now - lastPruneClock > 60 then
        environment:prune(betterTurtle.position, config.pruneRadius or 100)
        lastPruneClock = now
    end

    updateHud()
end

-- ---------------------------------------------------------------------------
-- Movement helpers
-- ---------------------------------------------------------------------------

local function walkPath(path)
    for _, d in ipairs(path or {}) do
        if fsm:isAny(minerStates.STOPPING, minerStates.RETURNING, minerStates.PAUSED) then
            return false
        end
        if not betterTurtle:moveDistance(d) then
            logger:warn("moveDistance failed; aborting current path.")
            return false
        end
        environment:insertCoordToCheckedBlocks(betterTurtle.position, blockType.AIR)
        -- 2-tall corridor: dig the ceiling block above the new position.
        if config.corridorTall ~= 0 and betterTurtle.position.y == 0 then
            betterTurtle:digCorridorCeiling()
            environment:insertCoordToCheckedBlocks(
                betterTurtle.position + directions.up.vector, blockType.AIR)
        end
        tick()
    end
    return true
end

local function returnToBase()
    if betterTurtle.position:isEqual(Coordinate:new(0, 0, 0)) then
        return true
    end
    logger:info("Returning to base from " .. tostring(betterTurtle.position))
    local ok = betterTurtle:moveToPosition(
        Coordinate:new(0, 0, 0), true, {"y", "z", "x"})
    if not ok then
        logger:error("Failed to return to base!")
    end
    return ok
end

-- ---------------------------------------------------------------------------
-- Per-block actions
-- ---------------------------------------------------------------------------

local function trySuckLava(direction, blockPos)
    if betterTurtle.getFuelLevel() > 90000 then
        environment:storeFuelLocation(blockPos)
        return false
    end
    betterTurtle.select(15)
    if betterTurtle:actionInDirection("place", direction) then
        logger:info("Lava detected at " .. tostring(blockPos))
        if betterTurtle.refuel() then
            logger:info("Refueled using lava source")
            environment:removeFuelLocation(blockPos)
            betterTurtle.select(1)
            return true
        else
            betterTurtle:actionInDirection("place", direction)
        end
    end
    betterTurtle.select(1)
    return false
end

local function trySuckInventory(direction)
    if betterTurtle:actionInDirection("detect", direction) then
        while betterTurtle:actionInDirection("suck", direction) do end
        environment:insertCoordToCheckedBlocks(
            betterTurtle:offsetPosition(direction), blockType.BLOCKER)
    end
end

local function checkSurroundings()
    for _, d in ipairs(directions.all) do
        local blockExists, blockData = betterTurtle:actionInDirection("inspect", d)
        local pos = betterTurtle:offsetPosition(d)
        local bType, alreadyChecked = environment:checkBlock(pos, blockData)
        if not alreadyChecked then
            if not blockExists then
                environment:insertCoordToCheckedBlocks(pos, blockType.AIR)
            elseif bType == blockType.FUEL then
                environment:storeFuelLocation(pos)
                trySuckLava(d, pos)
            elseif bType == blockType.OTHER then
                -- Ore. Dig it AND enqueue all its neighbours at high priority
                -- so the vein-following pass picks them up before continuing
                -- the regular branch-mining schedule.
                if betterTurtle:dig(d) then
                    oreCount = oreCount + 1
                    environment:insertCoordToCheckedBlocks(pos, blockType.AIR)
                    -- High-priority vein follow-up (negative priority floats
                    -- to the top of the heap).
                    environment.checkQueue:insert(pos, -1000)
                    for _, dn in ipairs(directions.all) do
                        local neighbour = pos + dn.vector
                        local known = environment:getBlockAtPosition(neighbour)
                        if known == blockType.UNKNOWN or known == blockType.OTHER then
                            environment.checkQueue:insert(neighbour, -500)
                        end
                    end
                end
            elseif bType == blockType.BLOCKER then
                trySuckInventory(d)
            end
        end
        tick()
        if fsm:isAny(minerStates.STOPPING, minerStates.PAUSED) then return end
    end
end

-- ---------------------------------------------------------------------------
-- CLI arg parsing
-- ---------------------------------------------------------------------------

local function parseDuration(args)
    if not args or #args == 0 then return nil end
    local s = table.concat(args, " ")
    local total = 0
    for n, period in s:gmatch("(%d+)%s*(%a+)") do
        n = tonumber(n)
        period = period:lower()
        if     period:find("^sec")  then total = total + n
        elseif period:find("^min")  then total = total + n * 60
        elseif period:find("^hour") then total = total + n * 3600
        end
    end
    if total > 0 then return os.clock() + total end
    return nil
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function MinerCore.init()
    config = loadConfig()
    applyLoggerConfig(config)
    logger = Logger:new(nil, "MinerCore")

    if config.pattern and Environment.patterns[config.pattern] then
        Environment.currentPattern = config.pattern
        logger:info("Mining pattern: " .. config.pattern)
    end

    betterTurtle = BetterTurtle:new()
    environment  = Environment:new()
    fsm          = FSM:new(minerStates.SEARCHING, allowedTransitions())
    fsm:onChange(function(prev, next) updateHud() end)

    hud       = HUD:new(1)
    telemetry = Telemetry:new(config.modemSide or "left")

    logger:info("=== MinerCore startup ===")
    for k, v in pairs(config) do
        logger:info("  cfg " .. k .. " = " .. tostring(v))
    end

    -- The 3x3 footprint around the start is reserved as the drop-off area.
    for i = -1, 1 do
        for j = -1, 1 do
            environment:insertCoordToCheckedBlocks(
                Coordinate:new(i, 0, j), blockType.BLOCKER)
        end
    end
    environment:insertCoordToCheckedBlocks(
        Coordinate:new(0, 0, 0), blockType.AIR)

    -- Attempt to restore from a previous session.
    if not loadState() then
        logger:info("No saved state; starting fresh.")
    end
    -- Lock in real-world coordinates if a GPS network is available.
    calibrateGPS()

    stopTime           = nil
    lastDumpClock      = os.clock()
    lastTickYield      = os.clock()
    lastPersistClock   = os.clock()
    lastTelemetryClock = os.clock()
    lastPruneClock     = os.clock()
end

function MinerCore.run(tArgs)
    if not betterTurtle then MinerCore.init() end
    stopTime = parseDuration(tArgs)

    while not fsm:is(minerStates.STOPPING) do
        tick()
        if fsm:is(minerStates.STOPPING) then break end

        if fsm:is(minerStates.PAUSED) then
            os.sleep(1)

        elseif gotoTarget then
            logger:info("Travelling to GOTO target " .. tostring(gotoTarget))
            betterTurtle:moveToPosition(gotoTarget, true, {"y", "z", "x"})
            gotoTarget = nil

        elseif fsm:is(minerStates.RETURNING) then
            returnToBase()
            dumpAllItems(findEnderChestSlot() ~= nil)
            if not fsm:is(minerStates.STOPPING) then
                fsm:set(minerStates.SEARCHING)
            end

        elseif fsm:is(minerStates.NEEDS_FUEL) then
            local path, hasFuel = environment:getNearestFuelLocation(betterTurtle.position)
            if not hasFuel then
                logger:error("No known fuel sources; stopping.")
                fsm:force(minerStates.STOPPING)
                break
            end
            walkPath(path)
            checkSurroundings()
            if fsm:is(minerStates.NEEDS_FUEL) then
                if not tryRefuel(fuelNeededToReturn()) then
                    fsm:force(minerStates.STOPPING)
                    break
                end
                fsm:set(minerStates.SEARCHING)
            end

        else
            -- SEARCHING / MINING / FUELING: pick next target and walk to it.
            local path = environment:getClosestMiningPositions(betterTurtle.position)
            if not path or #path == 0 then
                logger:info("No further mining targets; stopping.")
                fsm:force(minerStates.STOPPING)
                break
            end
            walkPath(path)
            if not fsm:isAny(minerStates.STOPPING, minerStates.PAUSED) then
                checkSurroundings()
            end
        end
    end

    logger:info("Shutting down: returning to base and dumping inventory.")
    returnToBase()
    dumpAllItems(findEnderChestSlot() ~= nil)
    saveState()
    if telemetry then telemetry:broadcastStatus(buildStatus()) end
    if hud then hud:shutdown() end
    Logger.shutdown()
    logger:info("Done.")
end

-- ---------------------------------------------------------------------------
-- Test helpers
-- ---------------------------------------------------------------------------

function MinerCore.setTurtle(t)      betterTurtle = t end
function MinerCore.setEnvironment(e) environment  = e end
function MinerCore.getFsm()          return fsm end
function MinerCore.getBetterTurtle() return betterTurtle end
function MinerCore.getEnvironment()  return environment end
