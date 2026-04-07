--[[
    MapDefs.lua
    Map definitions for War of Jonk
    Each map defines grid dimensions, river columns, and visual theme colors
]]

local MapDefs = {}

MapDefs.Maps = {
    grasslands = {
        name = "Grasslands",
        cols = 28,
        rows = 18,
        riverCols = {12, 13, 14}, -- 0-indexed columns that are river
        desc = "Wide open fields",
        theme = {
            land1       = Color3.fromRGB(30, 50, 25),
            land2       = Color3.fromRGB(25, 42, 20),
            river       = Color3.fromRGB(15, 60, 100),
            riverBorder = Color3.fromRGB(56, 189, 248),
            grid        = Color3.fromRGB(20, 20, 20),
            p1zone      = Color3.fromRGB(12, 20, 24),
            p2zone      = Color3.fromRGB(24, 16, 20),
        },
    },
    arctic = {
        name = "Arctic Wastes",
        cols = 24,
        rows = 20,
        riverCols = {10, 11},
        desc = "Narrow frozen terrain",
        theme = {
            land1       = Color3.fromRGB(35, 38, 45),
            land2       = Color3.fromRGB(30, 33, 40),
            river       = Color3.fromRGB(25, 65, 100),
            riverBorder = Color3.fromRGB(150, 220, 255),
            grid        = Color3.fromRGB(25, 25, 30),
            p1zone      = Color3.fromRGB(14, 22, 28),
            p2zone      = Color3.fromRGB(28, 18, 24),
        },
    },
    desert = {
        name = "Desert Storm",
        cols = 32,
        rows = 16,
        riverCols = {14, 15, 16},
        desc = "Massive sandy battlefield",
        theme = {
            land1       = Color3.fromRGB(60, 40, 10),
            land2       = Color3.fromRGB(50, 33, 8),
            river       = Color3.fromRGB(80, 60, 20),
            riverBorder = Color3.fromRGB(200, 160, 60),
            grid        = Color3.fromRGB(20, 18, 12),
            p1zone      = Color3.fromRGB(16, 22, 28),
            p2zone      = Color3.fromRGB(28, 18, 22),
        },
    },
}

-- Check if a column index is a river column for the given map
function MapDefs.isRiver(mapKey, col)
    local mapDef = MapDefs.Maps[mapKey]
    if not mapDef then return false end
    for _, rc in ipairs(mapDef.riverCols) do
        if rc == col then return true end
    end
    return false
end

-- Get spawn zone boundaries: P1 is left of river, P2 is right
function MapDefs.getP1MaxCol(mapKey)
    local mapDef = MapDefs.Maps[mapKey]
    if not mapDef then return 0 end
    return mapDef.riverCols[1] - 1
end

function MapDefs.getP2MinCol(mapKey)
    local mapDef = MapDefs.Maps[mapKey]
    if not mapDef then return 0 end
    return mapDef.riverCols[#mapDef.riverCols] + 1
end

return MapDefs
