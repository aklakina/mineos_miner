---
--- HUD - top-of-screen status display.
---
--- Splits the terminal into two CC `window`s:
---   - the top N rows are the HUD (refreshed on demand),
---   - the rest is the regular scrolling area for print()/logs.
---
--- Falls back to a no-op when `term` / `window` aren't available (e.g. in
--- unit tests).
---

HUD = {}
HUD.__index = HUD

local function hasTerm()
    return type(term) == "table" and type(window) == "table"
end

function HUD:new(numLines)
    local o = {
        numLines = numLines or 3,
        fields   = {},
        order    = {},
        enabled  = false,
        hudWin   = nil,
        logWin   = nil,
    }
    setmetatable(o, self)
    if hasTerm() then
        local w, h = term.getSize()
        if h > o.numLines + 1 then
            o.hudWin = window.create(term.current(), 1, 1, w, o.numLines, true)
            o.logWin = window.create(term.current(), 1, o.numLines + 1, w, h - o.numLines, true)
            term.redirect(o.logWin)
            o.enabled = true
        end
    end
    return o
end

function HUD:set(name, value)
    if self.fields[name] == nil then table.insert(self.order, name) end
    self.fields[name] = value
end

function HUD:setAll(tbl)
    for k, v in pairs(tbl) do self:set(k, v) end
end

function HUD:render()
    if not self.enabled then return end
    local w, _ = self.hudWin.getSize()
    if self.hudWin.setBackgroundColor and colors then
        pcall(self.hudWin.setBackgroundColor, colors.gray)
    end
    self.hudWin.clear()
    -- Pack fields into rows: "key:val  key:val  ..." wrapping at width.
    local row = 1
    local col = 1
    for _, k in ipairs(self.order) do
        if row > self.numLines then break end
        local s = tostring(k) .. ":" .. tostring(self.fields[k])
        if col > 1 and col + #s + 2 > w then
            row = row + 1
            col = 1
            if row > self.numLines then break end
        end
        self.hudWin.setCursorPos(col, row)
        if #s > w - col + 1 then s = s:sub(1, w - col + 1) end
        self.hudWin.write(s)
        col = col + #s + 2
    end
    if self.logWin and self.logWin.restoreCursor then
        self.logWin.restoreCursor()
    end
end

function HUD:shutdown()
    if not self.enabled then return end
    if term and term.redirect then
        local native = term.native and term.native() or self.logWin
        pcall(term.redirect, native)
    end
    self.enabled = false
end

