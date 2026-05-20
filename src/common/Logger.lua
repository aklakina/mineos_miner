---
--- Logger - leveled component logger with batched disk writes and a
--- configurable per-component level table.
---
--- The previous implementation opened/wrote/closed `latest.log` on every
--- single log line. That works but throws away the OS's file buffer and
--- triggers tens of syscalls per second under TRACE. This version holds
--- the file handle open and flushes periodically (and on shutdown).
---
--- Per-component level configuration:
---   Logger.setLevels({ MinerCore = "DEBUG", BetterTurtle = "WARN" })
--- or pass a level explicitly when constructing.
---

if rednet == nil and type(require) == "function" then
    pcall(require, 'rednet')  -- harmless in real CC; only used by tests
end

local function safe_exists(path)
    return type(fs) == "table" and fs.exists and fs.exists(path)
end

local function safe_date(fmt)
    if os and os.date then return os.date(fmt) end
    return tostring(os and os.time and os.time() or 0)
end

-- Log rotation on startup (only when fs is available - skip under unit tests).
if type(fs) == "table" then
    if safe_exists("latest.log") then
        local date = safe_date("%Y-%m-%d_%H-%M-%S")
        if not safe_exists("logs") then
            pcall(fs.makeDir, "logs")
        end
        pcall(fs.move, "latest.log", "logs/" .. date .. ".log")
        local ok, logs = pcall(fs.list, "logs")
        if ok and #logs > 5 then
            table.sort(logs)
            pcall(fs.delete, "logs/" .. logs[1])
        end
    end
end

Logger = {}
Logger.__index = Logger

Logger.levels = {
    FATAL = 1,
    ERROR = 2,
    WARN  = 3,
    INFO  = 4,
    DEBUG = 5,
    TRACE = 6,
}

-- Per-component overrides; key = component name, value = numeric level.
-- Populated via Logger.setLevels({...}) at startup.
Logger.componentLevels = {}
Logger.defaultLevel = Logger.levels.INFO

-- Shared log file handle and last-flush time. Held open between writes.
local _logHandle = nil
local _lastFlush = 0
local _logLinesSinceFlush = 0
local _logBytesWritten = 0
local _MAX_LOG_BYTES = 256 * 1024 -- 256 KB before mid-session rotation

local function openLogHandle()
    if type(fs) ~= "table" then return nil end
    if _logHandle then return _logHandle end
    local f = fs.open("latest.log", "a")
    _logHandle = f
    _logBytesWritten = (safe_exists("latest.log") and fs.getSize and fs.getSize("latest.log")) or 0
    return f
end

local function rotateIfNeeded()
    if _logBytesWritten < _MAX_LOG_BYTES then return end
    if _logHandle then _logHandle.close(); _logHandle = nil end
    local date = safe_date("%Y-%m-%d_%H-%M-%S")
    if not safe_exists("logs") then pcall(fs.makeDir, "logs") end
    pcall(fs.move, "latest.log", "logs/" .. date .. ".log")
    _logBytesWritten = 0
end

local function flush()
    if _logHandle and _logHandle.flush then
        pcall(_logHandle.flush)
    end
    _lastFlush = os.clock and os.clock() or 0
    _logLinesSinceFlush = 0
end

-- Open rednet on startup (best-effort). Same behaviour as before but with
-- pcall-guarded paths so this module no longer crashes when run in a unit
-- test where peripheral.getType is mocked.
if type(peripheral) == "table" then
    if peripheral.getType and peripheral.getType("left") == "modem" then
        if rednet and not rednet.isOpen("left") then
            pcall(rednet.open, "left")
        end
    end
end

-- Constructor.
function Logger:new(level, component)
    local logger = setmetatable({}, Logger)
    logger.component = component or "General"
    -- Resolve level: explicit > config override > default.
    if Logger.componentLevels[logger.component] then
        logger.level = Logger.componentLevels[logger.component]
    elseif level then
        logger.level = level
    else
        logger.level = Logger.defaultLevel
    end
    return logger
end

-- Apply a table of per-component levels, e.g.:
--   Logger.setLevels({ MinerCore = "DEBUG", BetterTurtle = "WARN" })
-- Affects loggers constructed AFTER this call (and re-applies to known ones).
function Logger.setLevels(t)
    for component, level in pairs(t) do
        if type(level) == "string" then
            level = Logger.levels[level:upper()]
        end
        if level then
            Logger.componentLevels[component] = level
        end
    end
end

function Logger.setDefaultLevel(level)
    if type(level) == "string" then level = Logger.levels[level:upper()] end
    if level then Logger.defaultLevel = level end
end

function Logger:log(level, message)
    local threshold = self.level or Logger.defaultLevel
    if threshold < (Logger.levels[level] or 0) then return end

    local stamp = safe_date()
    local msg = stamp .. " [" .. level .. "][" .. self.component .. "] " .. tostring(message)
    print(msg)

    -- File I/O: append to persistent handle, flush periodically.
    local f = openLogHandle()
    if f then
        f.writeLine(msg)
        _logBytesWritten = _logBytesWritten + #msg + 1
        _logLinesSinceFlush = _logLinesSinceFlush + 1
        local now = os.clock and os.clock() or 0
        if _logLinesSinceFlush >= 20 or (now - _lastFlush) > 2 then
            flush()
        end
        rotateIfNeeded()
    end

    -- Wireless broadcast (FATAL/ERROR/WARN only, to avoid saturating).
    if rednet and rednet.isOpen and rednet.isOpen("left") then
        if Logger.levels[level] and Logger.levels[level] <= Logger.levels.WARN then
            pcall(rednet.broadcast, msg, "miner.log")
        end
    end
end

function Logger:trace(m) self:log("TRACE", m) end
function Logger:debug(m) self:log("DEBUG", m) end
function Logger:info(m)  self:log("INFO",  m) end
function Logger:warn(m)  self:log("WARN",  m) end
function Logger:error(m) self:log("ERROR", m) end
function Logger:fatal(m) self:log("FATAL", m) end

function Logger.flush() flush() end
function Logger.shutdown()
    flush()
    if _logHandle then _logHandle.close(); _logHandle = nil end
end

