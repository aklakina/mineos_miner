---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by levi.
--- DateTime: 2/19/2024 7:28 PM
---

require('Logger')
local logger = Logger:new(Logger.levels.INFO, "MinerCore")

require('coordinate')
require('betterTurtle')
local betterTurtle = BetterTurtle:new()
require('environment')
local environment = Environment:new()
require('mutex')

minerStates = {
    MINING = {},
    FUELING = {},
    SEARCHING = {},
    RETURNING = {}
}

minerState = minerStates.SEARCHING

for i=-1, 1 do
    for j=-1, 1 do
        environment:insertCoordToCheckedBlocks(Coordinate:new(i, 0, j), blockType.BLOCKER)
    end
end

function loadConfig()
    local file = io.open("config.ini", "r")
    local config = {}

    for line in file:lines() do
        local key, value = string.match(line, "(%w+)%s-=%s-(%w+)")
        if key and value then
            config[key] = value
        end
    end

    file:close()
    return config
end

local config = loadConfig()
for key, value in pairs(config) do
    print(key, value)
end

function dumpWaste()
    local num_dumped = 0
    print("[dumpWaste]: Will dump the following blocks:")
    for i = 1, 14 do
        local count = betterTurtle.getItemCount( i )
        local detail = betterTurtle.getItemDetail( i )
        if detail ~= nil and environment:checkBlockType(detail) == blockType.WASTE then
            betterTurtle.select( i )
            betterTurtle.drop( count )
            num_dumped = num_dumped + count
            print("[dumpWaste]: - "..detail.name.." (x"..count..")")
        end
    end
    if num_dumped == 0 then
        print("[dumpWaste]: No blocks")
    end
    print("[dumpWaste]: Dumped "..num_dumped.." blocks of waste!")
    num_dumped = 0
    betterTurtle.select( 1 )
end

function dumperLoop()
    while true do
        -- lock the mutex to prevent other threads from accessing the turtle
        Mutex:lock("dumperLoop")
        dumpWaste()
        -- unlock the mutex to allow other threads to access the turtle
        Mutex:unlock("dumperLoop")
        local id = os.startTimer( 20 )
        while true do
            local _, tid = os.pullEvent( "timer" )
            if tid == id then
                break
            end
        end
    end
end

function suckLava(direction, _blockType, blockPos)
    if _blockType == blockType.FUEL then
        if betterTurtle.getFuelLevel() > 90000 then
            environment:storeFuelLocation(blockPos)
            minerState = minerStates.SEARCHING
            return false
        end
        Mutex:lock("suckLava")
        betterTurtle.select( 15 )
        if betterTurtle:actionInDirection("place", direction) then
            print( "[check]: Lava detected!" )
            if betterTurtle.refuel() then
                print( "[check]: Refueled using lava source!" )
                local lastDirection = betterTurtle.direction
                betterTurtle:move(direction, true)
                environment:insertCoordToCheckedBlocks(betterTurtle.position, blockType.AIR)
                betterTurtle.select( 1 )
                Mutex:unlock("suckLava")
                minerState = minerStates.FUELING
                return true
            else
                print( "[check]: Liquid was not lava!" )
                betterTurtle.place()
                betterTurtle.select( 1 )
                Mutex:unlock("suckLava")
                minerState = minerStates.SEARCHING
                return false
            end
        end
    end
end

function mineVein(direction, _blockType)
    if _blockType == blockType.OTHER then
        betterTurtle:move(direction, true)
        environment:insertCoordToCheckedBlocks(betterTurtle.position, blockType.AIR)
        minerState = minerStates.MINING
        return true
    else
        minerState = minerStates.SEARCHING
        return false
    end
end

local function suckInventory(direction)
    if betterTurtle:actionInDirection("detect", direction) and betterTurtle:actionInDirection("inspect", direction) then
        while betterTurtle:actionInDirection("suck", direction) do end
        environment:insertCoordToCheckedBlocks(betterTurtle.offsetPosition(direction), blockType.BLOCKER)
        minerState = minerStates.SEARCHING
        return false
    end
end

function check()
    while true do
        for k, v in pairs(directions) do
            local blockExists, blockData = betterTurtle:actionInDirection("inspect", v)
            local blockType = environment:checkBlock(blockData)
            if blockExists then
                local blockPos = betterTurtle:offsetPosition(v)
                if not environment:isBlockChecked(blockPos) then
                    if suckLava(v, blockType, blockPos, nLevel) then break end
                    if mineVein(v, blockType, blockPos, nLevel) then break end
                    if suckInventory(v) then break end
                end
            end
        end
        if minerState == minerStates.SEARCHING then
            break
        end
    end
end

function main()
    while not stop do
        while minerState ~= minerStates.RETURNING do
            local directions = environment:getClosestMiningPositions(betterTurtle.position)
            for _, v in pairs(directions) do
                betterTurtle:moveDistance(v)
            end
        end
        --not ok, return to base
        print( "[main]: Returning to base!" )
        print ("[main]: At relative position: ".. tostring(betterTurtle.position))
        betterTurtle:moveToPosition({0, 0, 0}, true)
        print ("[main]: At relative position: ".. tostring(betterTurtle.position))
        print( "[main]: Returned to base!" )
        betterTurtle:turn(originalDirection)
        for i = 1, 14 do
            betterTurtle.select( i )
            betterTurtle.dropDown()
        end
        betterTurtle.select( 1 )
        if not inventoryFull and not rangeReached then
            stop = true
            print( "[main]: Inventory was not full, something else went wrong" )
        elseif inventoryFull then
            ok = true
            inventoryFull = false
            print( "[main]: Inventory was full, continuing operation" )
        end
    end
end

function isOk()
    while ok do
        local hasSpace = false
        for i = 14, 1, -1 do
            if betterTurtle.getItemCount( i ) == 0 then
                hasSpace = true
                break
            end
        end
        local manualInterrupt = false
        --Listen for RedNet manual interrupts
        if rednet.isOpen("left") then
            --Listen for RET
            local _, msg = rednet.receive(nil, 0.1)
            if msg == "RET" then
                manualInterrupt = true
            end
        end
        if not hasSpace then
            print( "[isOk]: Out of space!  Intiating return!" )
            ok = false
            inventoryFull = true
        end
        if manualInterrupt then
            print("[isOk]: Manual return requested!, Returning..")
            ok = false
        end
        if ok then
            print( "[isOk]: Everything is OK!" )
            local id = os.startTimer( 10 )
            while true do
                local _, tid = os.pullEvent( "timer" )
                if tid == id then
                    break
                end
            end
        end
    end
end

parallel.waitForAll( trackTime, isOk, dumpWaste, main )
for i = 1, 14 do
    betterTurtle.select( i )
    betterTurtle.dropDown()
end