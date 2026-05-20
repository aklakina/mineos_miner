---@diagnostic disable: undefined-field, undefined-global
---
--- Entry point for the MineOS miner.
---
--- Slot layout:
---   Slot 15: Empty bucket (used to scoop lava for refueling).
---   Slot 16: Solid fuel (coal, charcoal, lava bucket, ...).
---   Slots 1-14: Mining output / general inventory.
---
--- Usage:
---   Main [<n> seconds] [<n> minutes] [<n> hours]
---
--- The duration argument is optional and may combine units, e.g.:
---   Main 1 hour 30 minutes
---

local tArgs = { ... }

require('MinerCore')

local function confirm(prompt)
    print(prompt .. " Y/N")
    while true do
        local _, char = os.pullEvent("char")
        char = char:lower()
        if char == "n" then error("Aborted.") end
        if char == "y" then return end
    end
end

MinerCore.init()
local t = turtle  -- raw API; MinerCore owns the BetterTurtle instance

print("=== MineOS Miner ===")

if t.getItemCount(15) ~= 1 then
    error("Place a single bucket in slot 15 (for lava refueling).")
end

if t.getItemCount(16) == 0 then
    confirm("Slot 16 has no fuel. Continue anyway?")
end

confirm("Ready to start mining?")

MinerCore.run(tArgs)
