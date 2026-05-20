---
--- FSM - a tiny finite-state-machine helper.
---
--- Lets you define legal transitions up front and crashes loudly when code
--- attempts an illegal one. Catches the class of bugs where a coroutine
--- silently leaves the FSM in an unexpected state (e.g. RETURNING -> SEARCHING
--- without dumping inventory).
---
--- Usage:
---   local fsm = FSM:new(states.SEARCHING, {
---       [states.SEARCHING] = { [states.MINING]=true, [states.RETURNING]=true, ... },
---       [states.MINING]    = { [states.SEARCHING]=true, ... },
---       ...
---   })
---   fsm:set(states.MINING)
---   if fsm:is(states.MINING) then ... end
---   fsm:onChange(function(prev, next) ... end)
---

require('Logger')
local logger = Logger:new(Logger.levels.INFO, "FSM")

FSM = {}
FSM.__index = FSM

function FSM:new(initial, transitions)
    local o = {
        state       = initial,
        transitions = transitions or {},
        listeners   = {},
        strict      = true,
    }
    setmetatable(o, self)
    return o
end

local function stateName(s)
    if s == nil then return "<nil>" end
    if type(s) == "table" and s.name then return s.name end
    return tostring(s)
end

function FSM:can(target)
    local row = self.transitions[self.state]
    return row ~= nil and row[target] == true
end

function FSM:set(target)
    if target == self.state then return end
    if not self:can(target) then
        local msg = "Illegal transition " .. stateName(self.state)
            .. " -> " .. stateName(target)
        if self.strict then
            logger:error(msg)
            error(msg, 2)
        else
            logger:warn(msg .. " (forced)")
        end
    end
    local prev = self.state
    self.state = target
    logger:debug("FSM: " .. stateName(prev) .. " -> " .. stateName(target))
    for _, l in ipairs(self.listeners) do
        pcall(l, prev, target)
    end
end

-- Like :set, but degrade illegal transitions to a warning instead of error.
function FSM:force(target)
    local s = self.strict
    self.strict = false
    self:set(target)
    self.strict = s
end

function FSM:is(state)   return self.state == state end
function FSM:isAny(...)
    for i = 1, select("#", ...) do
        if self.state == select(i, ...) then return true end
    end
    return false
end

function FSM:onChange(fn) table.insert(self.listeners, fn) end

function FSM:name() return stateName(self.state) end

