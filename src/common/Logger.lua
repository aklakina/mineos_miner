---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by levi.
--- DateTime: 2/18/2024 8:39 PM
---

require('rednet')

-- move latest.log file to logs/os.date().log
if fs.exists("latest.log") then
    local date = os.date("%Y-%m-%d_%H-%M-%S")
    -- check if logs directory exists
    if not fs.exists("logs") then
        fs.makeDir("logs")
    end
    fs.move("latest.log", "logs/"..date..".log")
    -- if there are more then 5 logs archived delete the oldest one
    local logs = fs.list("logs")
    if #logs > 5 then
        table.sort(logs, function(a, b) return a < b end)
        fs.delete("logs/"..logs[1])
    end
end

Logger = {}
Logger.__index = Logger

-- Define the logging levels
Logger.levels = {
    FATAL = 1,
    INFO = 2,
    ERROR = 3,
    WARN = 4,
    DEBUG = 5,
    TRACE = 6
}

if peripheral.getType("left") ~= "modem" then
    print( "There is no wireless modem attached! Do you wish to continue? Y/N" )
        while true do
            local _, char = os.pullEvent( "char" )
            if char:lower() == "n" then
                error("Aborted.")
            elseif char:lower() == "y" then
                break
            end
        end
else
    print("Found wireless modem on 'left' slot, trying to open it ...")
    if pcall(rednet.open, "left") then
        print("Successfully opened, now broadcasting on Channel "..rednet.CHANNEL_BROADCAST)
        print("-- START BROADCAST --")
    else
        print("Failed to open Channel, continue without modem? Y/N")
        while true do
            local _, char = os.pullEvent( "char" )
            if char:lower() == "n" then
                error("Aborted.")
            elseif char:lower() == "y" then
                break
            end
        end
    end
end

-- Constructor
function Logger:new(level, component)
    local logger = {}
    setmetatable(logger, Logger)
    logger.level = level or Logger.levels.DEBUG
    logger.component = component or "General"
    return logger
end

-- General log function
function Logger:log(level, message)
    if self.level >= self.levels[level] then
        local msg = os.date() .. " [" .. level .. "][" .. self.component .. "] " .. message
        print(msg)
        local file = fs.open( "latest.log", "a" )
        file.writeLine( text )
        file.close()
        if rednet.isOpen("left") then
            pcall(rednet.broadcast, text)
        end
    end
end

-- Log functions
function Logger:debug(message)
    self:log("DEBUG", message)
end

function Logger:info(message)
    self:log("INFO", message)
end

function Logger:warn(message)
    self:log("WARN", message)
end

function Logger:error(message)
    self:log("ERROR", message)
end

function Logger:fatal(message)
    self:log("FATAL", message)
end

function Logger:trace(message)
    self:log("TRACE", message)
end