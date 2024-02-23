---@diagnostic disable: undefined-field, undefined-global
---
--[[
Use below List for defining waste blocks
Slot 15: Bucket
Slot 16: Fuel
]]--

require("betterbetterTurtle")

local betterTurtle = BetterbetterTurtle:new()

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