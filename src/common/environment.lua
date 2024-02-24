---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by levi.
--- DateTime: 2/19/2024 6:53 PM
---

require('Logger')

require('coordinate')

local logger = Logger:new(Logger.levels.DEBUG, "Environment")

require('binaryHeap')

blockType = {
    WASTE = {},
    FUEL = {},
    OTHER = {},
    BLOCKER = {},
    AIR = {},
    UNKNOWN = {},
    PATH = {}
}

Environment = {
    checkedBlocks = {},
    wasteBlocks = {},
    blockers = {},
    fuels = {},
    fuelLocations = {},
    miningMap = {},
    checkQueue = BinaryHeap:new()
}

function Environment:getBlockAtPosition(coordinate)
    if getmetatable(coordinate) ~= Coordinate then
        coordinate = Coordinate.parse(coordinate)
    end
    local path = self.miningMap[tostring(coordinate)]
    if self.checkedBlocks[coordinate.y] and self.checkedBlocks[coordinate.y][coordinate.x] and self.checkedBlocks[coordinate.y][coordinate.x][coordinate.z] then
        local blockType = self.checkedBlocks[coordinate.y][coordinate.x][coordinate.z]
        return blockType
    elseif path then
        return blockType.PATH
    else
        return blockType.UNKNOWN
    end
end

function Environment:getNeighbours(coordinate)
    local neighbours = {}
    for _, v in pairs(directions) do
        if getmetatable(v) == Direction and v.name ~= "any" then
            logger:trace("Checking neighbour in direction " .. tostring(v.name))
            local neighbour = coordinate + v.vector
            logger:trace("Neighbour in direction " .. tostring(v.name) .. " is at position " .. tostring(neighbour))
            local blockType = self:getBlockAtPosition(neighbour)
            neighbours[v] = {position = neighbour, type = blockType}
        end
    end
    return neighbours
end

-- load wasteBlocks from file
local function loadWasteBlocks()
    logger:trace("Starting to load waste blocks from file")
    local file = io.open("wasteBlocks", "r")
    local line = file:read()
    while line do
        table.insert(Environment.wasteBlocks, line)
        line = file:read()
    end
    file:close()
    logger:trace("Finished loading waste blocks from file")
end

-- load fuels from file
local function loadFuels()
    logger:trace("Starting to load fuels from file")
    local file = io.open("fuels", "r")
    local line = file:read()
    while line do
        table.insert(Environment.fuels, line)
        line = file:read()
    end
    file:close()
    logger:trace("Finished loading fuels from file")
end

local function loadBlockers()
    logger:debug("Starting to load blockers from file")
    local file = io.open("blockers", "r")
    local line = file:read()
    while line do
        table.insert(Environment.blockers, line)
        line = file:read()
    end
    file:close()
    logger:debug("Finished loading blockers from file")
end

local function generateMiningMap()
    -- The mining map should be a set of static coordinates at which the robot should check for valuables.
    -- For the mining operation to be efficient it is advised to use branch mining.
    -- for example:
    -- x||x||x||x||x
    -- xxxxxxxxxxxxx
    -- x||x||x||x||x
    -- Where x marks the coordinates at which the robot should check for valuables.
    -- and | marks the coordinates that should not be present in the mining map
    -- The robot should start at the first x and move to the next x in the same row.
    for x = -255, 255, 1 do
        for z = -255, 255, 1 do
            if x == 0 or z == 0 then
                Environment.miningMap[tostring(Coordinate:new(x, 0, z))] = blockType.UNKNOWN
            elseif x % 3 == 0 or z % 3 == 0 then
                Environment.miningMap[tostring(Coordinate:new(x, 0, z))] = blockType.UNKNOWN
            end
        end
    end
end

loadWasteBlocks()
loadFuels()
loadBlockers()
generateMiningMap()

function Environment:new()
    local o = {}
    for k, v in pairs(Environment) do
        if type(v) == "table" then
            o[k] = {}
        end
    end
    setmetatable(o, self)
    self.__index = self
    return o
end

--[[
    Checks if a block has been checked and if it is a waste block
    If the block is a waste block, if it is then return true
    If the block is not a waste block, then return false

    @param x - the x coordinate of the block
    @param y - the y coordinate of the block
    @param z - the z coordinate of the block
    @param blockType - the metadata of block on position (x, y, z)
]]--
function Environment:isBlockChecked(coordinate)
    logger:debug("Checking if block at coordinate " .. tostring(coordinate) .. " has been checked")
    if getmetatable(coordinate) ~= Coordinate then
        coordinate = Coordinate.parse(coordinate)
    end
    local result = (self.checkedBlocks[coordinate.y] and self.checkedBlocks[coordinate.y][coordinate.x] and self.checkedBlocks[coordinate.y][coordinate.x][coordinate.z]) or false
    logger:debug("Block at coordinate " .. tostring(coordinate) .. " has been checked: " .. tostring(result))
    return result
end

function Environment:insertCoordToCheckedBlocks(coordinate, blockType)
    logger:debug("Inserting coordinate " .. tostring(coordinate) .. " to checked blocks")
    if getmetatable(coordinate) ~= Coordinate then
        coordinate = Coordinate.parse(coordinate)
    end
    self.checkedBlocks[coordinate.y] = self.checkedBlocks[coordinate.y] or {}
    self.checkedBlocks[coordinate.y][coordinate.x] = self.checkedBlocks[coordinate.y][coordinate.x] or {}
    self.checkedBlocks[coordinate.y][coordinate.x][coordinate.z] = blockType
    logger:debug("Finished inserting coordinate " .. tostring(coordinate) .. " to checked blocks")
end

Environment:insertCoordToCheckedBlocks(Coordinate:new(0, 0, 0), blockType.AIR)

function Environment:checkBlockType(block_type)
    if not block_type then
        return blockType.AIR
    end
    logger:debug("Checking block type for " .. tostring(block_type))
    if self.wasteBlocks[block_type] then
        logger:debug("Block type for " .. tostring(block_type) .. " is WASTE")
        return blockType.WASTE
    end
    if self.fuels[block_type] then
        logger:debug("Block type for " .. tostring(block_type) .. " is FUEL")
        return blockType.FUEL
    end
    logger:debug("Block type for " .. tostring(block_type) .. " is OTHER")
    return blockType.OTHER
end

function Environment:checkBlock(coordinate, block_type)
    logger:debug("Checking block at coordinate " .. tostring(coordinate) .. " with block type " .. tostring(block_type))
    if getmetatable(coordinate) ~= Coordinate then
        coordinate = Coordinate.parse(coordinate)
    end
    if self:isBlockChecked(coordinate) then
        logger:debug("Block at coordinate " .. tostring(coordinate) .. " is a waste block")
        return blockType.WASTE
    end
    local blockType = self:checkBlockType(block_type)
    self:insertCoordToCheckedBlocks(coordinate, blockType)
    if block_type then
        logger:debug("Block at coordinate " .. tostring(coordinate) .. " is of type " .. tostring(blockType))
        return blockType
    end
    logger:debug("Block at coordinate " .. tostring(coordinate) .. " is of unknown type")
    return blockType.UNKNOWN
end

function Environment:storeFuelLocation(coordinate)
    logger:debug("Storing fuel location at coordinate " .. tostring(coordinate))
    if getmetatable(coordinate) ~= Coordinate then
        coordinate = Coordinate.parse(coordinate)
    end
    self.fuelLocations[coordinate.y] = self.fuelLocations[coordinate.y] or {}
    self.fuelLocations[coordinate.y][coordinate.x] = self.fuelLocations[coordinate.y][coordinate.x] or {}
    self.fuelLocations[coordinate.y][coordinate.x][coordinate.z] = true
    logger:debug("Finished storing fuel location at coordinate " .. tostring(coordinate))
end

function Environment:addPositionToCheckQueue(coordinate)
    if getmetatable(coordinate) ~= Coordinate then
        coordinate = Coordinate.parse(coordinate)
    end
    local blockType = self:getBlockAtPosition(coordinate)
    local priority = self:getCost(blockType)
    logger:debug("Adding position " .. tostring(coordinate) .. " to check queue with priority " .. tostring(priority))
    self.checkQueue:insert(coordinate, priority)
end

function Environment:getClosestMiningPositions(position)
    if getmetatable(position) ~= Coordinate then
        position = Coordinate.parse(position)
    end
    logger:debug("Getting closest mining positions to " .. tostring(position))
    local coordinates = {}
    local heapObjects = {}
    if self.checkQueue:isEmpty() then
        -- It is not needed to get every position from the mining map.
        for x = -2, 2, 1 do
            for z = -2, 2, 1 do
                local coordinate = Coordinate:new(position.x + x, 0, position.z + z)
                if self.miningMap[tostring(coordinate)] then
                    table.insert(coordinates, coordinate)
                end
            end
        end
    else
        for i = 1, 5 do
            table.insert(heapObjects, self.checkQueue:pop())
            table.insert(coordinates, heapObjects[i].coordinate)
        end
    end
    local path, target = self:dijkstra(position, coordinates)
    for i, v in heapObjects do
        if not v.coordinate:isEqual(target) then
            self.checkQueue:insert(v.coordinate, v.priority - 1)
        end
    end
end

function Environment:dijkstra(source, targets)
    if getmetatable(source) ~= Coordinate then
        source = Coordinate.parse(source)
    end
    if getmetatable(targets) ~= Coordinate then
        if pcall(Coordinate.parse(targets)) then
            targets = {Coordinate.parse(targets)}
        else
            for i, target in ipairs(targets) do
                if getmetatable(target) ~= Coordinate then
                    targets[i] = Coordinate.parse(target)
                end
            end
        end
    else
        targets = {targets}
    end
    logger:debug("Starting Dijkstra algorithm from " .. tostring(source) .. " to multiple targets")
    local distance = {}
    local previous = {}
    local queue = BinaryHeap:new()

    distance[tostring(source)] = 0
    queue:insert(source, 0)

    local targetReached = nil
    while not queue:isEmpty() do
        local current = queue:pop()
        for _, target in ipairs(targets) do
            if current:isEqual(target) then
                targetReached = target
                break
            end
        end
        if targetReached then
            break
        end
        for direction, data in pairs(self:getNeighbours(current)) do
            local alt = distance[tostring(current)] + self:getCost(data.type)
            if alt < (distance[tostring(data.position)] and distance[tostring(data.position)] or math.huge) then
                distance[tostring(data.position)] = alt
                previous[tostring(data.position)] = current
                queue:decreaseKey(data.position, alt + self:heuristic(data.position, targets))
            end
        end
    end

    local path = {}
    local u = targetReached
    local cost = distance[tostring(u)]
    if previous[tostring(u)] or source:isEqual(u) then
        while u do
            table.insert(path, 1, u)
            u = previous[tostring(u)]
        end
    end
    logger:debug("Finished Dijkstra algorithm from " .. tostring(source) .. " to multiple targets")
    logger:debug("Path length: " .. #path)
    for i, v in pairs(path) do
        logger:debug("Path[" .. i .. "]: " .. tostring(v))
    end
    logger:debug("Cost: " .. tostring(cost))

    return Distance.fromPath(path), targetReached, cost
end

function Environment:getCost(_blockType)
    if not _blockType then
        _blockType = blockType.UNKNOWN
    end
    if _blockType == blockType.FUEL or _blockType == blockType.AIR then
        return 1
    elseif _blockType == blockType.WASTE or _blockType == blockType.OTHER then
        return 10
    elseif _blockType == blockType.PATH then
        return 5
    else
        return 1000
    end
end

-- Add a heuristic function to estimate the cost from the current node to the target
function Environment:heuristic(current, targets)
    local minDistance = math.huge
    for _, target in ipairs(targets) do
        local dx = math.abs(current.x - target.x)
        local dy = math.abs(current.y - target.y)
        local dz = math.abs(current.z - target.z)
        local distance = dx + dy + dz -- Manhattan distance
        if distance < minDistance then
            minDistance = distance
        end
    end
    return minDistance
end