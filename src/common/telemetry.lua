---
--- Telemetry - rednet-based status broadcasts and remote-control command
--- intake.
---
--- Protocols:
---   "miner.telemetry"  -- outbound, broadcast, periodic
---   "miner.control"    -- inbound, point-to-point or broadcast
---
--- Recognised inbound commands (as strings or {cmd=..., args=...} tables):
---   "RET"     legacy alias for STOP
---   "STOP"    request a clean shutdown (state -> STOPPING)
---   "PAUSE"   suspend mining (state -> PAUSED)
---   "RESUME"  resume from PAUSED -> SEARCHING
---   "STATUS"  trigger an immediate telemetry broadcast
---   "GOTO"    travel to absolute coords (args = {x, y, z})
---

require('Logger')
local logger = Logger:new(Logger.levels.INFO, "Telemetry")

Telemetry = {}
Telemetry.__index = Telemetry

local function hasRednet()
    return type(rednet) == "table"
end

function Telemetry:new(modemSide)
    local o = {
        side          = modemSide or "left",
        lastBroadcast = 0,
        broadcastEverySec = 5,
        opened        = false,
    }
    setmetatable(o, self)
    if hasRednet() and not rednet.isOpen(o.side) then
        pcall(rednet.open, o.side)
    end
    o.opened = hasRednet() and rednet.isOpen and rednet.isOpen(o.side)
    return o
end

function Telemetry:isOpen()
    return self.opened and rednet.isOpen(self.side)
end

function Telemetry:broadcastStatus(status)
    if not self:isOpen() then return end
    pcall(rednet.broadcast, status, "miner.telemetry")
    self.lastBroadcast = os.clock()
end

function Telemetry:tick(status)
    -- Broadcast status no more than once per broadcastEverySec.
    if not self:isOpen() then return end
    local now = os.clock()
    if now - self.lastBroadcast >= self.broadcastEverySec then
        self:broadcastStatus(status)
    end
end

-- Non-blocking poll for a single control message. Returns:
--   nil                              when no message is pending
--   { cmd = "STOP" }                 for the legacy string commands
--   { cmd = "GOTO", args = {x,y,z} } for structured commands
function Telemetry:pollCommand()
    if not self:isOpen() then return nil end
    local ok, _, msg = pcall(rednet.receive, "miner.control", 0)
    if not ok or msg == nil then return nil end
    if type(msg) == "string" then
        local upper = msg:upper()
        if upper == "RET" then return { cmd = "STOP" } end
        return { cmd = upper }
    elseif type(msg) == "table" and msg.cmd then
        msg.cmd = tostring(msg.cmd):upper()
        return msg
    end
    return nil
end

function Telemetry:shutdown()
    if self.opened and rednet and rednet.close then
        pcall(rednet.close, self.side)
    end
    self.opened = false
end

