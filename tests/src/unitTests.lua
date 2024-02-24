---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by levi.
--- DateTime: 2/18/2024 7:37 PM
---
-- Importing the necessary libraries for testing
local lu = require('luaunit')

require('coordinate')

TestCoordinate = {}

function TestCoordinate:testNewCoordinate()
    local coordinate = Coordinate:new(1, 2, 3, directions.forward)
    lu.assertEquals(coordinate.x, 1)
    lu.assertEquals(coordinate.y, 2)
    lu.assertEquals(coordinate.z, 3)
    lu.assertEquals(coordinate.direction, directions.forward)
end

function TestCoordinate:testAddCoordinates()
    local coordinate1 = Coordinate:new(1, 2, 3, directions.forward)
    local coordinate2 = Coordinate:new(4, 5, 6, directions.right)
    local result = coordinate1 + coordinate2
    lu.assertEquals(result.x, 5)
    lu.assertEquals(result.y, 7)
    lu.assertEquals(result.z, 9)
end

function TestCoordinate:testMultiplyCoordinates()
    local coordinate = Coordinate:new(1, 2, 3, directions.forward)
    local result = coordinate * 2
    lu.assertEquals(result.x, 2)
    lu.assertEquals(result.y, 4)
    lu.assertEquals(result.z, 6)
end

function TestCoordinate:testEquality()
    local coordinate1 = Coordinate:new(1, 2, 3, directions.any)
    local coordinate2 = Coordinate:new(1, 2, 3, directions.forward)
    lu.assertEquals(coordinate1, coordinate2)
end

TestDirection = {}

function TestDirection:testNewDirection()
    local direction = Direction:new("test", 4, {1, 2, 3})
    lu.assertEquals(direction.name, "test")
    lu.assertEquals(direction.num, 4)
    lu.assertEquals(direction.vector, {1, 2, 3})
end

function TestDirection:testConvertToForward()
    local direction = directions.convertToForward(directions.right)
    lu.assertEquals(direction, directions.forward)
end

function TestDirection:testGetInverseMovementVector()
    local inverse = directions.getInverseMovementVector("right")
    lu.assertEquals(tostring(inverse), "[-1, -0, -0]")
end

TestDistance = {}

function TestDistance:testNewDistance()
    local coordinate1 = Coordinate:new(1, 2, 3, directions.forward)
    local coordinate2 = Coordinate:new(4, 5, 6, directions.right)
    local distance = Distance:new(coordinate2, coordinate1)
    lu.assertEquals(distance.x.distance, -3)
    lu.assertEquals(distance.y.distance, -3)
    lu.assertEquals(distance.z.distance, -3)
end

function TestDistance:testGetDistance()
    local coordinate1 = Coordinate:new(1, 2, 3, directions.forward)
    local coordinate2 = Coordinate:new(4, 5, 6, directions.right)
    local distance = Distance:new(coordinate1, coordinate2)
    lu.assertEquals(distance:getAbsolute(), math.sqrt(27))
end

require('binaryHeap')

TestBinaryHeap = {}

function TestBinaryHeap:setUp()
    self.binaryHeap = BinaryHeap:new()
end

function TestBinaryHeap:testInsert()
    self.binaryHeap:insert(Coordinate:new(1, 2, 3), 1)
    lu.assertEquals(self.binaryHeap.heap[1].coordinate.x, 1)
    lu.assertEquals(self.binaryHeap.heap[1].coordinate.y, 2)
    lu.assertEquals(self.binaryHeap.heap[1].coordinate.z, 3)
    lu.assertEquals(self.binaryHeap.heap[1].priority, 1)
end

function TestBinaryHeap:testPop()
    self.binaryHeap:insert(Coordinate:new(1, 2, 3), 1)
    self.binaryHeap:insert(Coordinate:new(4, 5, 6), 2)
    local coordinate = self.binaryHeap:pop()
    lu.assertEquals(coordinate.x, 1)
    lu.assertEquals(coordinate.y, 2)
    lu.assertEquals(coordinate.z, 3)
end

function TestBinaryHeap:testDecreaseKeys()
    local coordinate1 = Coordinate:new(1, 2, 3)
    local coordinate2 = Coordinate:new(4, 5, 6)
    self.binaryHeap:insert(coordinate1, 2)
    self.binaryHeap:insert(coordinate2, 2)
    self.binaryHeap:decreaseKey(coordinate2, 1)
    local poppedCoordinate = self.binaryHeap:pop()
    lu.assertEquals(poppedCoordinate.x, 4)
    lu.assertEquals(poppedCoordinate.y, 5)
    lu.assertEquals(poppedCoordinate.z, 6)
end

function TestBinaryHeap:testIsEmpty()
    lu.assertTrue(self.binaryHeap:isEmpty())
    self.binaryHeap:insert(Coordinate:new(1, 2, 3), 1)
    lu.assertFalse(self.binaryHeap:isEmpty())
end

require('environment')

TestEnvironment = {}

function TestEnvironment:testIsBlockCheckedWithCheckedBlock()
    local environment = Environment:new()
    local coordinate = Coordinate:new(1, 2, 3, directions.forward)
    environment:insertCoordToCheckedBlocks(coordinate)
    lu.assertNotEquals(environment:isBlockChecked(coordinate), nil)
end

function TestEnvironment:testIsBlockCheckedWithUncheckedBlock()
    local environment = Environment:new()
    local coordinate = Coordinate:new(1, 2, 3, directions.forward)
    lu.assertFalse(environment:isBlockChecked(coordinate))
end

function TestEnvironment:testCheckBlockTypeWithWasteBlock()
    local environment = Environment:new()
    lu.assertEquals(environment:checkBlockType("waste"), blockType.WASTE)
end

function TestEnvironment:testCheckBlockTypeWithFuelBlock()
    local environment = Environment:new()
    lu.assertEquals(environment:checkBlockType("fuel"), blockType.FUEL)
end

function TestEnvironment:testCheckBlockTypeWithOtherBlock()
    local environment = Environment:new()
    lu.assertEquals(environment:checkBlockType("other"), blockType.OTHER)
end

function TestEnvironment:testCheckBlockWithCheckedBlock()
    local environment = Environment:new()
    local coordinate = Coordinate:new(1, 2, 3, directions.forward)
    environment:insertCoordToCheckedBlocks(coordinate)
    lu.assertEquals(environment:checkBlock(coordinate, "waste"), blockType.WASTE)
end

function TestEnvironment:testCheckBlockWithUncheckedBlock()
    local environment = Environment:new()
    local coordinate = Coordinate:new(1, 2, 3, directions.forward)
    lu.assertEquals(environment:checkBlock(coordinate, "fuel"), blockType.FUEL)
end

function TestEnvironment:testStoreFuelLocation()
    local environment = Environment:new()
    local coordinate = Coordinate:new(1, 2, 3, directions.forward)
    environment:storeFuelLocation(coordinate)
    lu.assertTrue(environment.fuelLocations[coordinate.y][coordinate.x][coordinate.z])
end

require('minecraftAPI') -- Assuming a mock turtle module is available

-- Importing the BetterTurtle module
require('betterTurtle')
local logger = Logger:new(Logger.levels.TRACE, "unitTests")

TestBetterTurtleUtils = {}

function TestBetterTurtleUtils:testIsDirectionValid()
    logger:info("Starting test: testIsDirectionValid")
    lu.assertTrue(isDirectionValid("forward"))
    lu.assertTrue(isDirectionValid("right"))
    lu.assertTrue(isDirectionValid("back"))
    lu.assertTrue(isDirectionValid("left"))
    lu.assertTrue(isDirectionValid("up"))
    lu.assertTrue(isDirectionValid("down"))
    lu.assertErrorMsgContains("Invalid direction", isDirectionValid, "north")
    logger:info("Finished test: testIsDirectionValid")
end

function TestBetterTurtleUtils:testGetMethodNameForDirection()
    logger:info("Starting test: testGetMethodNameForDirection")
    lu.assertEquals(getMethodNameForDirection("dig", "up"), "digUp")
    lu.assertEquals(getMethodNameForDirection("dig", "down"), "digDown")
    lu.assertEquals(getMethodNameForDirection("dig", "forward"), "dig")
    logger:info("Finished test: testGetMethodNameForDirection")
end

function TestBetterTurtleUtils:testGetRelativeDirection()
    logger:info("Starting test: testGetRelativeDirection")
    lu.assertEquals(directions.convertToForward("forward"), directions.forward)
    lu.assertEquals(directions.convertToForward("right"), directions.forward)
    lu.assertEquals(directions.convertToForward("back"), directions.forward)
    lu.assertEquals(directions.convertToForward("left"), directions.forward)
    lu.assertEquals(directions.convertToForward("up"), directions.up)
    lu.assertEquals(directions.convertToForward("down"), directions.down)
    logger:info("Finished test: testGetRelativeDirection")
end

-- Test suite for BetterTurtle
TestBetterTurtle = {}

function TestBetterTurtle:setUp()
    self.betterTurtle = BetterTurtle:new()
    turtle.reset()
    self.itemFuelValue = 100
    self.selectedSlot = 1
    self.betterTurtle.select = function(slot)
        self.selectedSlot = slot
        if slot == 15 then
            self.itemFuelValue = 1000
        else
            self.itemFuelValue = 100
        end
    end
    self.betterTurtle.refuel = function()
        local itemCount = self.betterTurtle.getItemCount(self.selectedSlot)
        if itemCount == 0 then
            return false
        end
        local fuelLevel = self.betterTurtle.getFuelLevel()
        self.betterTurtle.getFuelLevel = function() return fuelLevel + self.itemFuelValue end
        self.betterTurtle.getItemCount = function() return itemCount - 1 end
    end
    logger:info("Setup completed for a new test")
end

function TestBetterTurtle:testTurtleActions()
    self.betterTurtle:turn("right")
    lu.assertEquals(self.betterTurtle.direction, directions.right)
    turtle.reset()

    lu.assertErrorMsgContains("Invalid direction", self.betterTurtle.turn, self.betterTurtle, "north")
    turtle.reset()

    self.betterTurtle:relativeTurn("right")
    lu.assertEquals(self.betterTurtle.direction, directions.back)
    lu.assertEquals(tostring(self.betterTurtle.position), "[0, 0, 0]")
    lu.assertEquals(minecraftAPI_callHistory, {"turtle.turnRight"})
    turtle.reset()

    self.betterTurtle:dig("forward")
    lu.assertEquals(minecraftAPI_callHistory, {"turtle.dig"})
    turtle.reset()

    turtle.blocks = 1
    turtle.entityHp = 1
    self.betterTurtle:forceDig("forward")
    lu.assertEquals(minecraftAPI_callHistory, {"turtle.turnRight", "turtle.turnRight", "turtle.dig", "turtle.dig", "turtle.attack"})
    turtle.reset()

    self.betterTurtle:move("forward")
    lu.assertEquals(tostring(self.betterTurtle.position), "[0, 0, 1]")
    turtle.reset()

    self.betterTurtle:moveToPosition({1, 1, 1})
    lu.assertEquals(tostring(self.betterTurtle.position), "[1, 1, 1]")
    turtle.reset()

    turtle.blocked = true
    self.betterTurtle:moveToPosition({1, 1, 1})
    lu.assertEquals(minecraftAPI_callHistory, {})
    lu.assertEquals(tostring(self.betterTurtle.position), "[1, 1, 1]")
end

TestBetterTurtleMove = {}

function TestBetterTurtleMove:setUp()
    self.betterTurtle = BetterTurtle:new()
    turtle.reset()
    logger:info("Setup completed for a new test")
end

function TestBetterTurtleMove:testMoveValidDirection()
    self.betterTurtle:move("forward")
    lu.assertEquals(minecraftAPI_callHistory, {"turtle.forward"})
    turtle.reset()

    turtle.blocked = true
    self.betterTurtle:move("forward", true)
    lu.assertEquals(minecraftAPI_callHistory, {"turtle.forward", "turtle.dig", "turtle.dig", "turtle.attack", "turtle.forward"})
    turtle.reset()

    self.betterTurtle:move("right", false, true)
    lu.assertEquals(minecraftAPI_callHistory, {"turtle.turnRight", "turtle.forward"})
    turtle.reset()

    turtle.blocked = true
    self.betterTurtle:move("right", true, true)
    lu.assertEquals(minecraftAPI_callHistory, {"turtle.turnRight", "turtle.forward", "turtle.dig", "turtle.dig", "turtle.attack", "turtle.forward"})
    turtle.reset()

    self.betterTurtle:move("right", false, true)
    lu.assertEquals(minecraftAPI_callHistory, {"turtle.turnRight", "turtle.forward"})
    turtle.reset()

    turtle.blocked = true
    self.betterTurtle:move("forward", true)
    lu.assertEquals(minecraftAPI_callHistory, {"turtle.turnRight", "turtle.forward", "turtle.dig", "turtle.dig", "turtle.attack", "turtle.forward"})
    turtle.reset()

    self.betterTurtle:move("forward")
    lu.assertEquals(minecraftAPI_callHistory, {"turtle.forward"})
end

function TestBetterTurtleMove:testMoveInvalidDirection()
    lu.assertErrorMsgContains("Invalid direction", self.betterTurtle.move, self.betterTurtle, "north")
    turtle.reset()

    lu.assertErrorMsgContains("Invalid direction", self.betterTurtle.move, self.betterTurtle, "north", true)
    turtle.reset()

    lu.assertErrorMsgContains("Invalid direction", self.betterTurtle.move, self.betterTurtle, "north", false, true)
    turtle.reset()

    lu.assertErrorMsgContains("Invalid direction", self.betterTurtle.move, self.betterTurtle, "north", true, true)
    turtle.reset()

    lu.assertErrorMsgContains("Invalid direction", self.betterTurtle.move, self.betterTurtle, "north", false, true)
    turtle.reset()

    lu.assertErrorMsgContains("Invalid direction", self.betterTurtle.move, self.betterTurtle, "north", true)
    turtle.reset()

    lu.assertErrorMsgContains("Invalid direction", self.betterTurtle.move, self.betterTurtle, "north")
end

function TestBetterTurtle:testFindMaxLevelWithFuelInSlot16()
    self.betterTurtle.getItemCount = function(slot) if slot == 16 then return 5 else return 0 end end
    self.betterTurtle.getFuelLevel = function() return 100 end
    local maxFuel = self.betterTurtle:findMaxLevel()
    lu.assertEquals(maxFuel, 600)
end

function TestBetterTurtle:testFindMaxLevelWithNoFuelInSlot16()
    self.betterTurtle.getItemCount = function(slot) if slot == 16 then return 0 else return 0 end end
    self.betterTurtle.getFuelLevel = function() return 100 end
    local maxFuel = self.betterTurtle:findMaxLevel()
    lu.assertEquals(maxFuel, 100)
end

function TestBetterTurtle:testFindMaxLevelWithNoLavaInSlot15()
    self.betterTurtle.getItemCount = function(slot) if slot == 15 then return 0 else return 0 end end
    self.betterTurtle.getFuelLevel = function() return 100 end
    local maxFuel = self.betterTurtle:findMaxLevel()
    lu.assertEquals(maxFuel, 100)
end

function TestEnvironment:testDijkstraWithPopulatedCheckedBlocks()
    local environment = Environment:new()
    local source = Coordinate:new(1, 2, 3)
    local target = Coordinate:new(4, 5, 6)
    for y = 0, 6 do
        environment.checkedBlocks[y] = {}
        for x = 0, 6 do
            environment.checkedBlocks[y][x] = {}
            for z = 0, 6 do
                environment.checkedBlocks[y][x][z] = blockType.WASTE
            end
        end
    end
    local path = environment:dijkstra(source, target)
    lu.assertEquals(#path, 3)
    lu.assertEquals(path[1].from.x, 1)
    lu.assertEquals(path[1].from.y, 2)
    lu.assertEquals(path[1].from.z, 3)
    lu.assertEquals(path[1].to.x, 2)
    lu.assertEquals(path[1].to.y, 2)
    lu.assertEquals(path[1].to.z, 3)
    lu.assertEquals(path[2].from.x, 2)
    lu.assertEquals(path[2].from.y, 2)
    lu.assertEquals(path[2].from.z, 3)
    lu.assertEquals(path[2].to.x, 3)
    lu.assertEquals(path[2].to.y, 2)
    lu.assertEquals(path[2].to.z, 3)
    lu.assertEquals(path[3].from.x, 3)
    lu.assertEquals(path[3].from.y, 2)
    lu.assertEquals(path[3].from.z, 3)
    lu.assertEquals(path[3].to.x, 4)
    lu.assertEquals(path[3].to.y, 2)
    lu.assertEquals(path[3].to.z, 3)
end

os.exit(lu.LuaUnit.run())