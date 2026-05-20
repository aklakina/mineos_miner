---
--- Persistence - atomic save/load helper backed by `textutils.serialize`.
---
--- Writes go through a `<file>.tmp` then atomic rename, so a crash mid-write
--- never leaves a half-serialised file on disk.
---

require('Logger')
local logger = Logger:new(Logger.levels.INFO, "Persistence")

Persistence = {}

local function hasFs()
    return type(fs) == "table" and type(textutils) == "table"
end

function Persistence.save(filename, data)
    if not hasFs() then
        logger:warn("Persistence.save: fs/textutils unavailable")
        return false
    end
    local tmp = filename .. ".tmp"
    local f = fs.open(tmp, "w")
    if not f then return false end
    local ok, encoded = pcall(textutils.serialize, data)
    if not ok then f.close(); return false end
    f.write(encoded)
    f.close()
    if fs.exists(filename) then fs.delete(filename) end
    fs.move(tmp, filename)
    return true
end

function Persistence.load(filename)
    if not hasFs() or not fs.exists(filename) then return nil end
    local f = fs.open(filename, "r")
    if not f then return nil end
    local content = f.readAll()
    f.close()
    if not content or content == "" then return nil end
    local ok, data = pcall(textutils.unserialize, content)
    if not ok then
        logger:warn("Persistence.load: corrupt file " .. filename)
        return nil
    end
    return data
end

function Persistence.delete(filename)
    if hasFs() and fs.exists(filename) then fs.delete(filename) end
end

function Persistence.exists(filename)
    return hasFs() and fs.exists(filename)
end

