--[[
    GameConfig.lua
    Global constants and configuration for War of Jonk
]]

local GameConfig = {}

-- Colors matching the browser UI (enhanced palette)
GameConfig.Colors = {
    Background      = Color3.fromRGB(5, 5, 5),
    BackgroundLight = Color3.fromRGB(10, 10, 10),
    Glass           = Color3.fromRGB(20, 20, 20),
    GlassBorder     = Color3.fromRGB(40, 40, 40),
    GlassHover      = Color3.fromRGB(30, 30, 30),
    White           = Color3.fromRGB(255, 255, 255),
    WhiteDim        = Color3.fromRGB(140, 140, 140),
    WhiteDimmer     = Color3.fromRGB(64, 64, 64),
    WhiteDimmest    = Color3.fromRGB(26, 26, 26),

    Player1         = Color3.fromRGB(125, 211, 252),
    Player1Dim      = Color3.fromRGB(19, 32, 38),
    Player1Border   = Color3.fromRGB(50, 84, 101),

    Player2         = Color3.fromRGB(249, 168, 212),
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

    Accent          = Color3.fromRGB(99, 102, 241),
    AccentDim       = Color3.fromRGB(30, 31, 60),
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
GameConfig.KING_AURA_DAMAGE = 0.10

-- Super King buff (10% ATK increase for all troops)
GameConfig.SUPER_KING_BUFF = 0.10

-- Splash texts for loading screen
GameConfig.SplashTexts = {
    "Preparing the battlefield...",
    "Sharpening the spears...",
    "Rallying the troops...",
    "The King awaits your command.",
    "Jonk or be Jonked.",
    "Loading cannons...",
    "Deploying naval fleet...",
    "Strategize. Deploy. Conquer.",
    "War... war never changes.",
    "All hail the Jonk King!",
    "Calculating optimal bean angles...",
    "Lubricating the Lubatron...",
    "Hiring more lawyers...",
    "Moles are digging tunnels...",
    "The Zumwalt is powered up!",
}

-- Mission definitions
GameConfig.Missions = {
    {
        id = "railgun_unlock",
        name = "Railgun Unlock",
        desc = "Play 100 games",
        stat = "gamesPlayed",
        target = 100,
        reward = "railgun",
        rewardDisplay = "Railgun Jonk",
        iconChar = "R",
        iconColor = Color3.fromRGB(248, 113, 113),
    },
    {
        id = "mole_daddy_unlock",
        name = "Mole Daddy Unlock",
        desc = "Play 500 games",
        stat = "gamesPlayed",
        target = 500,
        reward = "mole_daddy",
        rewardDisplay = "Mole Daddy",
        iconChar = "M",
        iconColor = Color3.fromRGB(167, 139, 250),
    },
    {
        id = "zumwalt_part1",
        name = "Zumwalt Commission",
        desc = "Kill 2000 units",
        stat = "unitsKilled",
        target = 2000,
        reward = "zumwalt_part1",
        rewardDisplay = "Zumwalt Part 1/3",
        iconChar = "Z",
        iconColor = Color3.fromRGB(56, 189, 248),
    },
    {
        id = "king_slayer",
        name = "King Slayer",
        desc = "Kill 1000 Kings",
        stat = "kingsKilled",
        target = 1000,
        reward = "zumwalt_part2",
        rewardDisplay = "Zumwalt Part 2/3",
        iconChar = "X",
        iconColor = Color3.fromRGB(251, 146, 60),
    },
    {
        id = "battle_hardened",
        name = "Battle Hardened",
        desc = "Lose 50 times",
        stat = "gamesLost",
        target = 50,
        reward = "zumwalt_part3",
        rewardDisplay = "Zumwalt Part 3/3",
        iconChar = "H",
        iconColor = Color3.fromRGB(251, 191, 36),
    },
}

-- Shop - Developer Product IDs
-- IMPORTANT: Replace 0 with actual product IDs from Roblox Creator Dashboard
GameConfig.Shop = {
    CoinPacks = {
        { id = 0, name = "100 Coins",  coins = 100,  robux = 49,  color = Color3.fromRGB(52, 211, 153) },
        { id = 0, name = "500 Coins",  coins = 500,  robux = 199, color = Color3.fromRGB(56, 189, 248) },
        { id = 0, name = "1500 Coins", coins = 1500, robux = 499, color = Color3.fromRGB(167, 139, 250) },
        { id = 0, name = "5000 Coins", coins = 5000, robux = 1499, color = Color3.fromRGB(251, 191, 36) },
    },
    SuperKingGamePassId = 0, -- Replace with actual GamePass ID (500 Robux)
}

-- Upgrade costs (coins per level)
GameConfig.UpgradeCost = {
    [1] = 50,
    [2] = 120,
    [3] = 250,
    [4] = 500,
    [5] = 1000,
}
GameConfig.MAX_UPGRADE_LEVEL = 5
GameConfig.UPGRADE_STAT_BONUS = 0.05 -- 5% per level

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
    "GetPlayerData",
    "UpgradeTroop",
    "PlayerDataUpdate",
}

return GameConfig
