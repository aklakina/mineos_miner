---@diagnostic disable: undefined-field, undefined-global
---
--[[
Use below List for defining waste blocks
Slot 15: Bucket
Slot 16: Fuel
]]--

require("betterbetterTurtle")

local betterTurtle = BetterbetterTurtle:new()

local thread_queue = {}

local function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

local stop, inventoryFull, maxRange, rangeReached, ok, tArgs, ignoredFuel, fuelAmount = false, false, 50, false, true, { ... }, 0, nil


print( "You have defined the following as waste blocks: " )
for i,v in ipairs(waste_blocks) do print("  - "..v) end
print("Is this correct? Y/N")
while true do
    local _, char = os.pullEvent( "char" )
    if char:lower() == "n" then
        error("Aborted.")
    elseif char:lower() == "y" then
        break
    end
end


if betterTurtle.getItemCount( 15 ) ~= 1 then
    error( "Place a single bucket in slot 15" )
end
if betterTurtle.getItemCount( 16 ) == 0 then
    print( "Are you sure you wish to continue with no fuel in slot 16? Y/N" )
    while true do
        local _, char = os.pullEvent( "char" )
        if char:lower() == "n" then
            error("Aborted.")
        elseif char:lower() == "y" then
            break
        end
    end
end

function notwaste( solid, value )
    if has_value(waste_blocks, value.name) then
        return false
    end

    return solid
end

local function checkLava(direction, nLevel)
    if betterTurtle.getFuelLevel() > 90000 then
        -- TODO implement a mapping and return mechanism for lava veins
        return
    end
    local success, data = betterTurtle.actionInDirection("inspect", direction)
    if success and data.name == "minecraft:lava" then
        table.insert(thread_queue, "checkLava")
        while thread_queue[1] ~= "checkLava" do
            os.sleep(1)
        end
        betterTurtle.select( 15 )
        if betterTurtle.actionInDirection("place", direction) then
            print( "[check]: Lava detected!" )
            if betterTurtle.refuel() then
                print( "[check]: Refueled using lava source!" )
                local lastDirection = betterTurtle.direction
                betterTurtle.move(direction, true)
                check( nLevel + 1, direction )
                betterTurtle.move(getInverseDirection(lastDirection), true)
                ignoredFuel = ignoredFuel + 2
            else
                print( "[check]: Liquid was not lava!" )
                betterTurtle.place()
            end
        end
    end
    betterTurtle.select( 1 )
    for i, v in ipairs(thread_queue) do
        if v == "checkLava" then
            table.remove(thread_queue, i)
            break
        end
    end
end

local function checkInventory(direction)
    if betterTurtle.actionInDirection("detect", direction) and betterTurtle.actionInDirection("inspect", direction) then
        while betterTurtle.actionInDirection("suck", direction) do end
    end
end

local function checkWaste(direction, nLevel)
    local solid, value = betterTurtle.actionInDirection("inspect", direction)
    if notwaste( solid, value ) then
        print( "[check]: Ore Detected! ("..value.name..")" )
        local lastDirection = betterTurtle.direction
        betterTurtle.move(direction, true)
        print( "[check]: Dug ore!" )
        check( nLevel + 1, direction )
        forceBack(getInverseDirection(lastDirection))
        ignoredFuel = ignoredFuel + 2
    end
end

function check( nLevel )
    if not nLevel then
        nLevel = 1
    elseif nLevel > 40 then
        return
    end
    local originalOrientation = betterTurtle.direction
    local lastDirection = getInverseDirection(originalOrientation)
    if not ok then return end
    for direction, _ in pairs(directions) do
        local blockPos = betterTurtle.offsetPosition(direction)
        if direction ~= lastDirection and not has_position(checked_blocks_relative_position, blockPos) then
            insert_position(checked_blocks_relative_position, blockPos)
            --print( "[check]: Checking block at relative position ["..pos[1]..", "..pos[2]..", "..pos[3].."]!" )
            --check for lava
            checkLava(direction, nLevel)
            --check for inventories
            checkInventory(direction)
            if not ok then return end
            --check for ore
            checkWaste(direction, nLevel)
            if not ok then return end
        else
            print( "[check]: Skipping block at relative position ["..blockPos[1]..", "..blockPos[2]..", "..blockPos[3].."]!" )
        end
    end
    betterTurtle.turn(originalOrientation)
end

function branch(mainPos)
    local gone = 0
    for i = 1, 25 do
        betterTurtle.move("forward", true, true)
        print( "[branch]: Dug branch at pos ["..mainPos.."] ["..gone.."]!" )
        gone = gone + 1
        if not ok then break end
        check()
        if not ok then break end
    end
    print( "[branch]: Returning to main!" )
    for i = 1, gone do
        betterTurtle.move("back", true, true)
    end
    print( "[branch]: Returned to main!" )
end

local function moveUntilWallOrMaxRange(gone, maxRange)
    print("[main]: Searching wall")
    repeat
        if betterTurtle.move("forward", true, true) then
            gone = gone + 1
            if gone >= maxRange then
                print("[main]: Exceeding 64 blocks range, returning")
                ok = false
                rangeReached = true
                break
            end
        end
    until betterTurtle.detect()
    print("[main]: Found wall")
    return gone
end

local function digMainTunnel(gone, maxRange)
    print("Digging main at pos ["..gone.."]")
    for i = 1, 3 do
        betterTurtle.move("forward", true, true)
        print( "[main]: Digging main at pos ["..gone.."]!" )
        if gone >= maxRange then
            print("[main]: Exceeding 64 blocks range, returning")
            ok = false
            rangeReached = true
            break
        end
        gone = gone + 1
        check()
    end
    return gone
end

function main()
    local gone = 0
    while not stop do
        local originalDirection = betterTurtle.direction
        if rangeReached then
            print("[main]: Range reached, turning right")
            betterTurtle.relativeTurn("right")
            originalDirection = betterTurtle.direction
            ok = true
            rangeReached = false
        end
        gone = moveUntilWallOrMaxRange(gone, maxRange)
        while ok do
            gone = digMainTunnel(gone, maxRange)
            if not ok then break end
            betterTurtle.relativeTurn("right")
            print( "[main]: Initiating branch in right wing!" )
            branch(gone-1)
            if not ok then break end
            betterTurtle.relativeTurn("back")
            print( "[main]: Initiating branch in left wing!" )
            branch(gone-1)
            if not ok then break end
            betterTurtle.relativeTurn("right")
        end
        --not ok, return to base
        print( "[main]: Returning to base!" )
        print ("[main]: At relative position: ["..my_position[1]..", "..my_position[2]..", "..my_position[3].."]")
        betterTurtle.moveToPosition({0, 0, 0}, true)
        print ("[main]: At relative position: ["..my_position[1]..", "..my_position[2]..", "..my_position[3].."]")
        print( "[main]: Returned to base!" )
        betterTurtle.turn(originalDirection)
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


function findMaxLevel()
    local level = betterTurtle.getFuelLevel()
    local maxFuel = 0
    if betterTurtle.getItemCount( 16 ) > 1 then
        if not fuelAmount then
            betterTurtle.select( 16 )
            betterTurtle.refuel( 1 )
            fuelAmount = betterTurtle.getFuelLevel() - level
            print( "[findMaxLevel]: Found fuelAmount: "..fuelAmount)
        end
        print( "[findMaxLevel]: Found max level: " .. betterTurtle.getItemCount( 16 ) * fuelAmount + betterTurtle.getFuelLevel() .. "!")
        maxFuel = betterTurtle.getItemCount( 16 ) * fuelAmount + betterTurtle.getFuelLevel()
    else
        print( "[findMaxLevel]: Found max level: " .. betterTurtle.getFuelLevel() .. "!" )
        maxFuel = betterTurtle.getFuelLevel()
    end
    if betterTurtle.getItemCount( 15 ) > 0 then
        betterTurtle.select( 15 )
        if betterTurtle.refuel() then
            print( "[findMaxLevel]: Found lava, refueled by 1000!" )
            maxFuel = maxFuel + 1000
        end
    end
    return maxFuel
end

function isOk()
    local okLevel = findMaxLevel() / 2 + 10
    while ok do
        local currentLevel = betterTurtle.getFuelLevel()
        if currentLevel < 100 then --check fuel
            print( "[isOk]: Fuel Level Low!" )
            if betterTurtle.getItemCount( 16 ) > 0 then
                print( "[isOk]: Refueling!" )
                repeat
                    betterTurtle.select( 16 )
                until betterTurtle.refuel( 1 ) or betterTurtle.getSelectedSlot() == 16
                if betterTurtle.getFuelLevel() > currentLevel then
                    print( "[isOk]: Refuel Successful!" )
                else
                    print( "[isOk]: Refuel Unsuccessful, Initiating return!" )
                    ok = false
                end
            end
        elseif okLevel - ignoredFuel > findMaxLevel()  then
            print("[isOk]: Fuel Reserves Depleted!  Initiating return!")
            ok = false
        end
        --make sure betterTurtle can take new items
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
        for i, v in ipairs(thread_queue) do
            if v == "isOk" then
                table.remove(thread_queue, i)
                break
            end
        end
        if ok then
            print( "[isOk]: Everything is OK!" )
            local id = os.startTimer( 10 )
            while true do
                local _, tid = os.pullEvent( "timer" )
                if tid == id then
                    table.insert(thread_queue,"isOk")
                    while thread_queue[1] ~= "isOk" do
                        os.sleep(1)
                    end
                    break
                end
            end
        end
    end
end


function trackTime()
    local sTime = table.concat( tArgs, " " )
    local nSeconds = 0
    for i, period in sTime:gmatch( "(%d+)%s+(%a+)s?" ) do
        if period:lower() == "second" then
            nSeconds = nSeconds + i
        elseif period:lower() == "minute" then
            nSeconds = nSeconds + ( i * 60 )
        elseif period:lower() == "hour" then
            nSeconds = nSeconds + ( i * 3600 )
        end
    end
    print( "[trackTime]: Starting timer for "..nSeconds.." seconds!" )
    local id = os.startTimer( nSeconds )
    while ok do
        local _, tid = os.pullEvent( "timer" )
        if id == tid then
            print( "[trackTime]: End of session reached!  Returning to base!" )
            ok = false
        end
    end
end

parallel.waitForAll( trackTime, isOk, dumpWaste, main )
for i = 1, 14 do
    betterTurtle.select( i )
    betterTurtle.dropDown()
end