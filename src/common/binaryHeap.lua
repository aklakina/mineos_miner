---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by levi.
--- DateTime: 2/23/2024 10:26 PM
---

require('Logger')

local logger = Logger:new(Logger.levels.DEBUG, "BinaryHeap")

require('coordinate')

BinaryHeap = {}
BinaryHeap.__index = BinaryHeap

function BinaryHeap:__tostring()
    local str = "BinaryHeap: {"
    for i, v in ipairs(self.heap) do
        str = str .. "\n\t" .. tostring(v.coordinate) .. " : " .. v.priority
    end
    str = str .. "\n}"
    return str
end

function BinaryHeap:new()
    local newHeap = {}
    setmetatable(newHeap, self)
    self.__index = self
    newHeap.heap = {}
    return newHeap
end

function BinaryHeap:parent(i)
    return math.floor(i / 2)
end

function BinaryHeap:left(i)
    return 2 * i
end

function BinaryHeap:right(i)
    return 2 * i + 1
end

function BinaryHeap:insert(coordinate, priority)
    if getmetatable(coordinate) ~= Coordinate then
        coordinate = Coordinate.parse(coordinate)
    end
    local i = #self.heap + 1
    self.heap[i] = {coordinate = coordinate, priority = priority}
    while i > 1 and self.heap[self:parent(i)].priority > self.heap[i].priority do
        self.heap[i], self.heap[self:parent(i)] = self.heap[self:parent(i)], self.heap[i]
        i = self:parent(i)
    end
    self:minHeapify(#self.heap + 1)
end

function BinaryHeap:minHeapify(i)
    local smallest = i
    local l = self:left(i)
    local r = self:right(i)
    if l <= #self.heap and self.heap[l].priority < self.heap[smallest].priority then
        smallest = l
    end
    if r <= #self.heap and self.heap[r].priority < self.heap[smallest].priority then
        smallest = r
    end
    if smallest ~= i then
        self.heap[i], self.heap[smallest] = self.heap[smallest], self.heap[i]
        self:minHeapify(smallest)
    end
end

function BinaryHeap:pop()
    if #self.heap < 1 then
        return nil
    end
    local min = self.heap[1]
    self.heap[1] = self.heap[#self.heap]
    table.remove(self.heap)
    self:minHeapify(1)
    return min.coordinate, min.priority
end

function BinaryHeap:isEmpty()
    return #self.heap == 0
end

function BinaryHeap:decreaseKey(coordinate, newPriority)
    if getmetatable(coordinate) ~= Coordinate then
        coordinate = Coordinate.parse(coordinate)
    end
    for i, v in ipairs(self.heap) do
        if v.coordinate:isEqual(coordinate) then
            self.heap[i].priority = newPriority
            while i > 1 and self.heap[self:parent(i)].priority > self.heap[i].priority do
                self.heap[i], self.heap[self:parent(i)] = self.heap[self:parent(i)], self.heap[i]
                i = self:parent(i)
            end
            break
        end
    end
end