--[[
    GameConfig.lua
    Global constants and configuration for War of Jonk
]]

local GameConfig = {}

-- Colors matching the browser UI
GameConfig.Colors = {
    Background      = Color3.fromRGB(5, 5, 5),
    Glass           = Color3.fromRGB(20, 20, 20),
    GlassBorder     = Color3.fromRGB(40, 40, 40),
    White           = Color3.fromRGB(255, 255, 255),
    WhiteDim        = Color3.fromRGB(140, 140, 140),
    WhiteDimmer     = Color3.fromRGB(64, 64, 64),
    WhiteDimmest    = Color3.fromRGB(26, 26, 26),

    Player1         = Color3.fromRGB(125, 211, 252),  -- sky blue
    Player1Dim      = Color3.fromRGB(19, 32, 38),
    Player1Border   = Color3.fromRGB(50, 84, 101),

    Player2         = Color3.fromRGB(249, 168, 212),  -- pink
    Player2Dim      = Color3.fromRGB(38, 26, 32),
    Player2Border   = Color3.fromRGB(100, 67, 85),

    Gold            = Color3.fromRGB(251, 191, 36),
    GoldDim         = Color3.fromRGB(38, 29, 5),

    Danger          = Color3.fromRGB(248, 113, 113),
    Success         = Color3.fromRGB(52, 211, 153),
    Warning         = Color3.fromRGB(251, 146, 60),

    River           = Color3.fromRGB(14, 47, 62),
    RiverBorder     = Color3.fromRGB(56, 189, 248),

    HealthHigh      = Color3.fromRGB(52, 211, 153),
    HealthMid       = Color3.fromRGB(251, 191, 36),
    HealthLow       = Color3.fromRGB(248, 113, 113),
}

-- Game phases
GameConfig.Phase = {
    BUILD  = "build",
    DEPLOY = "deploy",
    BATTLE = "turn",
}

-- Tile size in studs for the 3D board
GameConfig.TILE_SIZE = 4

-- Gold settings
GameConfig.STARTING_GOLD = 100
GameConfig.GOLD_PER_TURN = 35
GameConfig.MAX_GOLD = 300

-- Turn timer (seconds)
GameConfig.TURN_TIME = 90

-- King HP
GameConfig.KING_MAX_HP = 100

-- King aura damage multiplier when king is hit
GameConfig.KING_AURA_DAMAGE = 0.10 -- 10% HP loss

-- Remotes
GameConfig.Remotes = {
    "CreateGame",
    "JoinGame",
    "DeployUnit",
    "MoveUnit",
    "AttackUnit",
    "UseAbility",
    "EndTurn",
    "GameStateUpdate",
    "GameOver",
    "LogMessage",
    "ToastMessage",
}

return GameConfig
