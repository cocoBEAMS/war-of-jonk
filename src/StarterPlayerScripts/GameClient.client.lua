--[[
    GameClient.client.lua
    Main client-side UI and game controller for War of Jonk
    Sleek dark glassmorphism UI with missions, shop, splash screen
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UnitDefs = require(Modules:WaitForChild("UnitDefs"))
local MapDefs = require(Modules:WaitForChild("MapDefs"))
local GameConfig = require(Modules:WaitForChild("GameConfig"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

------------------------------------------------------
-- State
------------------------------------------------------
local CurrentScreen = "splash"
local GameState = nil
local SelectedUnit = nil
local SelectedAction = nil
local MyPlayerId = tostring(Player.UserId)
local MyPlayerData = nil
local LogMessages = {}
local BoardFrames = {}

------------------------------------------------------
-- UI Helpers
------------------------------------------------------
local function create(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then inst[k] = v end
    end
    if children then
        for _, child in ipairs(children) do child.Parent = inst end
    end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

local function addCorner(parent, radius)
    return create("UICorner", {CornerRadius = UDim.new(0, radius or 8), Parent = parent})
end

local function addStroke(parent, color, thickness)
    return create("UIStroke", {Color = color or GameConfig.Colors.GlassBorder, Thickness = thickness or 1, Parent = parent})
end

local function addPadding(parent, t, r, b, l)
    return create("UIPadding", {
        PaddingTop = UDim.new(0, t or 8), PaddingRight = UDim.new(0, r or 8),
        PaddingBottom = UDim.new(0, b or 8), PaddingLeft = UDim.new(0, l or 8),
        Parent = parent
    })
end

local function addGradient(parent, c1, c2, rot)
    return create("UIGradient", {
        Color = ColorSequence.new(c1 or Color3.fromRGB(25,25,30), c2 or Color3.fromRGB(10,10,12)),
        Rotation = rot or 90, Parent = parent
    })
end

local function glassFrame(props)
    local f = create("Frame", props)
    f.BackgroundColor3 = props.BackgroundColor3 or GameConfig.Colors.Glass
    f.BackgroundTransparency = props.BackgroundTransparency or 0.15
    f.BorderSizePixel = 0
    addCorner(f, props.CornerRadius or 12)
    addStroke(f, props.StrokeColor or GameConfig.Colors.GlassBorder, 1)
    return f
end

local function sleekButton(props)
    local b = create("TextButton", {
        Size = props.Size or UDim2.new(0, 200, 0, 48),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
        BackgroundColor3 = props.Color or GameConfig.Colors.Accent,
        BackgroundTransparency = 0.1,
        Text = props.Text or "Button",
        TextColor3 = props.TextColor or GameConfig.Colors.White,
        TextSize = props.TextSize or 16,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        BorderSizePixel = 0,
        Parent = props.Parent,
        LayoutOrder = props.LayoutOrder,
        AutoButtonColor = false,
    })
    addCorner(b, props.CornerRadius or 10)
    addStroke(b, props.StrokeColor or Color3.fromRGB(255,255,255), 1)
    b.UIStroke.Transparency = 0.85
    if props.Gradient ~= false then
        addGradient(b, props.Color or GameConfig.Colors.Accent, props.GradientTo or Color3.fromRGB(60,60,180))
    end
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.2), {BackgroundTransparency = 0.1}):Play()
    end)
    if props.OnClick then b.MouseButton1Click:Connect(props.OnClick) end
    return b
end

local function iconBadge(parent, char, color, size)
    size = size or 32
    local badge = create("Frame", {
        Size = UDim2.new(0, size, 0, size),
        BackgroundColor3 = color or Color3.fromRGB(99,102,241),
        BackgroundTransparency = 0.15,
        Parent = parent,
    })
    addCorner(badge, size / 2)
    addStroke(badge, Color3.fromRGB(255,255,255), 1)
    badge.UIStroke.Transparency = 0.7
    create("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = char or "?",
        TextColor3 = Color3.fromRGB(255,255,255),
        TextSize = math.floor(size * 0.55),
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = badge,
    })
    return badge
end

------------------------------------------------------
-- Main ScreenGui
------------------------------------------------------
local ScreenGui = create("ScreenGui", {
    Name = "WarOfJonkUI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = PlayerGui,
})

-- Full-screen dark background
local BgFrame = create("Frame", {
    Name = "Background",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = GameConfig.Colors.Background,
    BorderSizePixel = 0,
    Parent = ScreenGui,
})

-- Subtle animated gradient overlay
local bgGrad = create("Frame", {
    Name = "GradientOverlay",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.fromRGB(99, 102, 241),
    BackgroundTransparency = 0.96,
    BorderSizePixel = 0,
    Parent = BgFrame,
})

------------------------------------------------------
-- SCREENS container
------------------------------------------------------
local Screens = {}


------------------------------------------------------
-- SPLASH SCREEN
------------------------------------------------------
local function buildSplashScreen()
    local screen = create("Frame", {
        Name = "SplashScreen", Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1, Parent = BgFrame, Visible = false,
    })
    local center = create("Frame", {
        Size = UDim2.new(0,500,0,350), Position = UDim2.new(0.5,0,0.5,0),
        AnchorPoint = Vector2.new(0.5,0.5), BackgroundTransparency = 1, Parent = screen,
    })
    local title = create("TextLabel", {
        Size = UDim2.new(1,0,0,60), Position = UDim2.new(0,0,0,40),
        BackgroundTransparency = 1, Text = "WAR OF JONK",
        TextColor3 = GameConfig.Colors.White, TextSize = 48,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
        Parent = center,
    })
    local subtitle = create("TextLabel", {
        Size = UDim2.new(1,0,0,24), Position = UDim2.new(0,0,0,110),
        BackgroundTransparency = 1, Text = "A Jonk Strategy Experience",
        TextColor3 = GameConfig.Colors.WhiteDim, TextSize = 16,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular),
        Parent = center,
    })
    -- Splash text
    local splashText = create("TextLabel", {
        Name = "SplashText",
        Size = UDim2.new(1,0,0,24), Position = UDim2.new(0,0,0,160),
        BackgroundTransparency = 1,
        Text = GameConfig.SplashTexts[math.random(1, #GameConfig.SplashTexts)],
        TextColor3 = GameConfig.Colors.Gold, TextSize = 14,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
        TextTransparency = 0, Parent = center,
    })
    -- Animate splash text
    task.spawn(function()
        while screen.Parent do
            local txt = splashText
            if txt and txt.Parent then
                TweenService:Create(txt, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
                task.wait(0.6)
                if txt.Parent then
                    txt.Text = GameConfig.SplashTexts[math.random(1, #GameConfig.SplashTexts)]
                    TweenService:Create(txt, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
                end
                task.wait(3)
            else
                break
            end
        end
    end)
    -- Loading bar
    local barBg = create("Frame", {
        Size = UDim2.new(0.6,0,0,6), Position = UDim2.new(0.2,0,0,210),
        BackgroundColor3 = GameConfig.Colors.WhiteDimmest, Parent = center,
    })
    addCorner(barBg, 3)
    local barFill = create("Frame", {
        Name = "Fill", Size = UDim2.new(0,0,1,0),
        BackgroundColor3 = GameConfig.Colors.Accent, Parent = barBg,
    })
    addCorner(barFill, 3)
    -- Animate loading bar
    task.spawn(function()
        task.wait(0.5)
        TweenService:Create(barFill, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(1,0,1,0)
        }):Play()
        task.wait(2.5)
        -- Load player data
        pcall(function()
            MyPlayerData = Remotes.GetPlayerData:InvokeServer()
        end)
        task.wait(0.5)
        showScreen("home")
    end)
    return screen
end

------------------------------------------------------
-- HOME SCREEN
------------------------------------------------------
local function buildHomeScreen()
    local screen = create("Frame", {
        Name = "HomeScreen", Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1, Parent = BgFrame, Visible = false,
    })
    -- Header
    local header = create("Frame", {
        Size = UDim2.new(1,0,0,60), BackgroundTransparency = 1, Parent = screen,
    })
    create("TextLabel", {
        Size = UDim2.new(0,300,1,0), Position = UDim2.new(0,20,0,0),
        BackgroundTransparency = 1, Text = "WAR OF JONK",
        TextColor3 = GameConfig.Colors.White, TextSize = 28,
        TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
        Parent = header,
    })
    -- Coins display
    local coinsLabel = create("TextLabel", {
        Name = "CoinsLabel",
        Size = UDim2.new(0,150,0,36), Position = UDim2.new(1,-170,0,12),
        BackgroundColor3 = GameConfig.Colors.GoldDim, BackgroundTransparency = 0.3,
        Text = "0 Coins", TextColor3 = GameConfig.Colors.Gold, TextSize = 14,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        Parent = header,
    })
    addCorner(coinsLabel, 8)
    addStroke(coinsLabel, GameConfig.Colors.Gold, 1)
    coinsLabel.UIStroke.Transparency = 0.6

    -- Center content
    local centerBox = glassFrame({
        Size = UDim2.new(0,460,0,420), Position = UDim2.new(0.5,0,0.5,10),
        AnchorPoint = Vector2.new(0.5,0.5), Parent = screen,
    })
    addPadding(centerBox, 24, 24, 24, 24)

    create("TextLabel", {
        Size = UDim2.new(1,0,0,36), BackgroundTransparency = 1,
        Text = "Choose Your Battle", TextColor3 = GameConfig.Colors.White, TextSize = 24,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        Parent = centerBox,
    })

    local btnLayout = create("Frame", {
        Size = UDim2.new(1,0,0,260), Position = UDim2.new(0,0,0,60),
        BackgroundTransparency = 1, Parent = centerBox,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12),
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = btnLayout,
    })

    sleekButton({
        Text = "VS CPU", Size = UDim2.new(1,0,0,52), Parent = btnLayout,
        Color = GameConfig.Colors.Accent, GradientTo = Color3.fromRGB(70,72,200),
        LayoutOrder = 1,
        OnClick = function() showScreen("create", "cpu") end,
    })
    sleekButton({
        Text = "CREATE ROOM", Size = UDim2.new(1,0,0,52), Parent = btnLayout,
        Color = Color3.fromRGB(52,211,153), GradientTo = Color3.fromRGB(30,130,90),
        LayoutOrder = 2,
        OnClick = function() showScreen("create", "player") end,
    })
    sleekButton({
        Text = "JOIN ROOM", Size = UDim2.new(1,0,0,52), Parent = btnLayout,
        Color = Color3.fromRGB(56,189,248), GradientTo = Color3.fromRGB(30,100,150),
        LayoutOrder = 3,
        OnClick = function() showScreen("join") end,
    })

    -- Bottom nav
    local bottomNav = create("Frame", {
        Size = UDim2.new(1,-48,0,44), Position = UDim2.new(0,24,1,-68),
        BackgroundTransparency = 1, Parent = screen,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12),
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = bottomNav,
    })
    sleekButton({
        Text = "MISSIONS", Size = UDim2.new(0,140,0,44), Parent = bottomNav,
        Color = Color3.fromRGB(251,146,60), GradientTo = Color3.fromRGB(150,80,20),
        LayoutOrder = 1, TextSize = 14,
        OnClick = function() showScreen("missions") end,
    })
    sleekButton({
        Text = "SHOP", Size = UDim2.new(0,140,0,44), Parent = bottomNav,
        Color = Color3.fromRGB(251,191,36), GradientTo = Color3.fromRGB(150,110,10),
        LayoutOrder = 2, TextSize = 14,
        OnClick = function() showScreen("shop") end,
    })
    sleekButton({
        Text = "UPGRADES", Size = UDim2.new(0,140,0,44), Parent = bottomNav,
        Color = Color3.fromRGB(167,139,250), GradientTo = Color3.fromRGB(90,70,160),
        LayoutOrder = 3, TextSize = 14,
        OnClick = function() showScreen("upgrades") end,
    })

    return screen
end

------------------------------------------------------
-- CREATE SCREEN
------------------------------------------------------
local createMode = "cpu"
local function buildCreateScreen()
    local screen = create("Frame", {
        Name = "CreateScreen", Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1, Parent = BgFrame, Visible = false,
    })
    local box = glassFrame({
        Size = UDim2.new(0,400,0,280), Position = UDim2.new(0.5,0,0.5,0),
        AnchorPoint = Vector2.new(0.5,0.5), Parent = screen,
    })
    addPadding(box, 24, 24, 24, 24)
    create("TextLabel", {
        Size = UDim2.new(1,0,0,30), BackgroundTransparency = 1,
        Text = "Enter Your Name", TextColor3 = GameConfig.Colors.White, TextSize = 22,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        Parent = box,
    })
    local nameInput = create("TextBox", {
        Name = "NameInput",
        Size = UDim2.new(1,0,0,44), Position = UDim2.new(0,0,0,50),
        BackgroundColor3 = GameConfig.Colors.BackgroundLight, BackgroundTransparency = 0.3,
        Text = "", PlaceholderText = "Commander",
        TextColor3 = GameConfig.Colors.White, PlaceholderColor3 = GameConfig.Colors.WhiteDim,
        TextSize = 16, ClearTextOnFocus = false,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
        Parent = box, BorderSizePixel = 0,
    })
    addCorner(nameInput, 8)
    addStroke(nameInput, GameConfig.Colors.GlassBorder)
    addPadding(nameInput, 0, 12, 0, 12)

    sleekButton({
        Text = "START GAME", Size = UDim2.new(1,0,0,48), Position = UDim2.new(0,0,0,120),
        AnchorPoint = Vector2.new(0,0), Parent = box,
        Color = GameConfig.Colors.Success, GradientTo = Color3.fromRGB(30,140,90),
        OnClick = function()
            local name = nameInput.Text
            if name == "" then name = "Commander" end
            local result = Remotes.CreateGame:InvokeServer(name, createMode)
            if result and result.success then
                if createMode == "player" then
                    showScreen("lobby", result.roomCode)
                else
                    GameState = result.game
                    showScreen("game")
                end
            end
        end,
    })
    sleekButton({
        Text = "BACK", Size = UDim2.new(0,100,0,36), Position = UDim2.new(0,0,0,185),
        AnchorPoint = Vector2.new(0,0), Parent = box,
        Color = GameConfig.Colors.WhiteDimmest, GradientTo = Color3.fromRGB(30,30,30),
        TextSize = 13,
        OnClick = function() showScreen("home") end,
    })
    return screen
end

------------------------------------------------------
-- JOIN SCREEN
------------------------------------------------------
local function buildJoinScreen()
    local screen = create("Frame", {
        Name = "JoinScreen", Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1, Parent = BgFrame, Visible = false,
    })
    local box = glassFrame({
        Size = UDim2.new(0,400,0,280), Position = UDim2.new(0.5,0,0.5,0),
        AnchorPoint = Vector2.new(0.5,0.5), Parent = screen,
    })
    addPadding(box, 24, 24, 24, 24)
    create("TextLabel", {
        Size = UDim2.new(1,0,0,30), BackgroundTransparency = 1,
        Text = "Join Room", TextColor3 = GameConfig.Colors.White, TextSize = 22,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        Parent = box,
    })
    local nameInput = create("TextBox", {
        Size = UDim2.new(1,0,0,44), Position = UDim2.new(0,0,0,50),
        BackgroundColor3 = GameConfig.Colors.BackgroundLight, BackgroundTransparency = 0.3,
        Text = "", PlaceholderText = "Your Name",
        TextColor3 = GameConfig.Colors.White, PlaceholderColor3 = GameConfig.Colors.WhiteDim,
        TextSize = 16, ClearTextOnFocus = false,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
        Parent = box, BorderSizePixel = 0,
    })
    addCorner(nameInput, 8); addStroke(nameInput, GameConfig.Colors.GlassBorder)
    addPadding(nameInput, 0, 12, 0, 12)
    local codeInput = create("TextBox", {
        Size = UDim2.new(1,0,0,44), Position = UDim2.new(0,0,0,108),
        BackgroundColor3 = GameConfig.Colors.BackgroundLight, BackgroundTransparency = 0.3,
        Text = "", PlaceholderText = "Room Code",
        TextColor3 = GameConfig.Colors.White, PlaceholderColor3 = GameConfig.Colors.WhiteDim,
        TextSize = 16, ClearTextOnFocus = false,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
        Parent = box, BorderSizePixel = 0,
    })
    addCorner(codeInput, 8); addStroke(codeInput, GameConfig.Colors.GlassBorder)
    addPadding(codeInput, 0, 12, 0, 12)
    sleekButton({
        Text = "JOIN", Size = UDim2.new(1,0,0,48), Position = UDim2.new(0,0,0,170),
        AnchorPoint = Vector2.new(0,0), Parent = box,
        Color = GameConfig.Colors.Player1, GradientTo = Color3.fromRGB(30,100,150),
        OnClick = function()
            local name = nameInput.Text; if name == "" then name = "Commander" end
            local code = codeInput.Text
            local result = Remotes.JoinGame:InvokeServer(name, code)
            if result and result.success then
                GameState = result.game; showScreen("game")
            end
        end,
    })
    sleekButton({
        Text = "BACK", Size = UDim2.new(0,100,0,36), Position = UDim2.new(0,0,0,228),
        AnchorPoint = Vector2.new(0,0), Parent = box,
        Color = GameConfig.Colors.WhiteDimmest, GradientTo = Color3.fromRGB(30,30,30),
        TextSize = 13, OnClick = function() showScreen("home") end,
    })
    return screen
end

------------------------------------------------------
-- LOBBY SCREEN
------------------------------------------------------
local function buildLobbyScreen()
    local screen = create("Frame", {
        Name = "LobbyScreen", Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1, Parent = BgFrame, Visible = false,
    })
    local box = glassFrame({
        Size = UDim2.new(0,400,0,200), Position = UDim2.new(0.5,0,0.5,0),
        AnchorPoint = Vector2.new(0.5,0.5), Parent = screen,
    })
    addPadding(box, 24, 24, 24, 24)
    create("TextLabel", {
        Size = UDim2.new(1,0,0,30), BackgroundTransparency = 1,
        Text = "Waiting for opponent...", TextColor3 = GameConfig.Colors.White, TextSize = 20,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        Parent = box,
    })
    local codeLabel = create("TextLabel", {
        Name = "RoomCode",
        Size = UDim2.new(1,0,0,50), Position = UDim2.new(0,0,0,50),
        BackgroundTransparency = 1, Text = "CODE: ------",
        TextColor3 = GameConfig.Colors.Gold, TextSize = 32,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
        Parent = box,
    })
    create("TextLabel", {
        Size = UDim2.new(1,0,0,20), Position = UDim2.new(0,0,0,110),
        BackgroundTransparency = 1, Text = "Share this code with your friend!",
        TextColor3 = GameConfig.Colors.WhiteDim, TextSize = 13,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular),
        Parent = box,
    })
    return screen
end


------------------------------------------------------
-- MISSIONS SCREEN (actual progress tracking!)
------------------------------------------------------
local function buildMissionsScreen()
    local screen = create("Frame", {
        Name = "MissionsScreen", Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1, Parent = BgFrame, Visible = false,
    })
    -- Header
    create("TextLabel", {
        Size = UDim2.new(1,0,0,50), Position = UDim2.new(0,0,0,10),
        BackgroundTransparency = 1, Text = "MISSIONS",
        TextColor3 = GameConfig.Colors.White, TextSize = 28,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
        Parent = screen,
    })
    sleekButton({
        Text = "BACK", Size = UDim2.new(0,80,0,32), Position = UDim2.new(0,20,0,16),
        AnchorPoint = Vector2.new(0,0), Parent = screen,
        Color = GameConfig.Colors.WhiteDimmest, GradientTo = Color3.fromRGB(30,30,30),
        TextSize = 12, OnClick = function() showScreen("home") end,
    })

    local scrollFrame = create("ScrollingFrame", {
        Name = "MissionsList",
        Size = UDim2.new(1,-60,1,-80), Position = UDim2.new(0,30,0,70),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 4, ScrollBarImageColor3 = GameConfig.Colors.WhiteDim,
        CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = screen,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12),
        HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = scrollFrame,
    })

    -- Build mission cards
    for i, mission in ipairs(GameConfig.Missions) do
        local card = glassFrame({
            Name = "Mission_" .. mission.id,
            Size = UDim2.new(1,-20,0,100), LayoutOrder = i, Parent = scrollFrame,
        })
        addPadding(card, 12, 16, 12, 16)

        -- Icon badge
        local badge = iconBadge(card, mission.iconChar, mission.iconColor, 40)
        badge.Position = UDim2.new(0,0,0.5,0)
        badge.AnchorPoint = Vector2.new(0,0.5)

        -- Mission name
        create("TextLabel", {
            Size = UDim2.new(0,300,0,22), Position = UDim2.new(0,52,0,0),
            BackgroundTransparency = 1, Text = mission.name,
            TextColor3 = GameConfig.Colors.White, TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
            Parent = card,
        })
        -- Mission desc
        create("TextLabel", {
            Size = UDim2.new(0,300,0,18), Position = UDim2.new(0,52,0,22),
            BackgroundTransparency = 1, Text = mission.desc,
            TextColor3 = GameConfig.Colors.WhiteDim, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular),
            Parent = card,
        })
        -- Reward label
        create("TextLabel", {
            Size = UDim2.new(0,200,0,16), Position = UDim2.new(0,52,0,40),
            BackgroundTransparency = 1,
            Text = "Reward: " .. mission.rewardDisplay,
            TextColor3 = GameConfig.Colors.Gold, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
            Parent = card,
        })
        -- Progress bar bg
        local progBg = create("Frame", {
            Size = UDim2.new(1,-60,0,8), Position = UDim2.new(0,52,0,62),
            BackgroundColor3 = GameConfig.Colors.WhiteDimmest, Parent = card,
        })
        addCorner(progBg, 4)
        -- Progress bar fill
        local progFill = create("Frame", {
            Name = "ProgressFill",
            Size = UDim2.new(0,0,1,0),
            BackgroundColor3 = mission.iconColor, Parent = progBg,
        })
        addCorner(progFill, 4)
        -- Progress text
        create("TextLabel", {
            Name = "ProgressText",
            Size = UDim2.new(0,120,0,14), Position = UDim2.new(1,-120,0,60),
            BackgroundTransparency = 1, Text = "0 / " .. mission.target,
            TextColor3 = GameConfig.Colors.WhiteDim, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Right,
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
            Parent = card,
        })
        -- Completion badge
        create("TextLabel", {
            Name = "CompleteBadge",
            Size = UDim2.new(0,80,0,24), Position = UDim2.new(1,-80,0,8),
            BackgroundColor3 = GameConfig.Colors.Success, BackgroundTransparency = 0.2,
            Text = "COMPLETE", TextColor3 = GameConfig.Colors.White, TextSize = 10,
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
            Visible = false, Parent = card,
        })
        addCorner(card:FindFirstChild("CompleteBadge"), 6)
    end

    return screen
end

local function refreshMissions()
    if not MyPlayerData then return end
    local missionsScreen = Screens.missions
    if not missionsScreen then return end
    local list = missionsScreen:FindFirstChild("MissionsList")
    if not list then return end

    for _, mission in ipairs(GameConfig.Missions) do
        local card = list:FindFirstChild("Mission_" .. mission.id)
        if card then
            local current = MyPlayerData[mission.stat] or 0
            local target = mission.target
            local pct = math.clamp(current / target, 0, 1)
            local completed = MyPlayerData.completedMissions and MyPlayerData.completedMissions[mission.id]

            local fill = card:FindFirstChild("ProgressFill", true)
            if fill then
                TweenService:Create(fill, TweenInfo.new(0.5), {
                    Size = UDim2.new(pct, 0, 1, 0)
                }):Play()
            end
            local progText = card:FindFirstChild("ProgressText", true)
            if progText then
                progText.Text = tostring(current) .. " / " .. tostring(target)
            end
            local badge = card:FindFirstChild("CompleteBadge")
            if badge then badge.Visible = (completed == true) end
        end
    end
end

------------------------------------------------------
-- SHOP SCREEN
------------------------------------------------------
local function buildShopScreen()
    local screen = create("Frame", {
        Name = "ShopScreen", Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1, Parent = BgFrame, Visible = false,
    })
    create("TextLabel", {
        Size = UDim2.new(1,0,0,50), Position = UDim2.new(0,0,0,10),
        BackgroundTransparency = 1, Text = "SHOP",
        TextColor3 = GameConfig.Colors.Gold, TextSize = 28,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
        Parent = screen,
    })
    sleekButton({
        Text = "BACK", Size = UDim2.new(0,80,0,32), Position = UDim2.new(0,20,0,16),
        AnchorPoint = Vector2.new(0,0), Parent = screen,
        Color = GameConfig.Colors.WhiteDimmest, GradientTo = Color3.fromRGB(30,30,30),
        TextSize = 12, OnClick = function() showScreen("home") end,
    })

    -- Coin packs section
    create("TextLabel", {
        Size = UDim2.new(1,0,0,24), Position = UDim2.new(0,30,0,70),
        BackgroundTransparency = 1, Text = "COIN PACKS",
        TextColor3 = GameConfig.Colors.White, TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        Parent = screen,
    })
    local packsRow = create("Frame", {
        Size = UDim2.new(1,-60,0,140), Position = UDim2.new(0,30,0,100),
        BackgroundTransparency = 1, Parent = screen,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12),
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = packsRow,
    })
    for i, pack in ipairs(GameConfig.Shop.CoinPacks) do
        local card = glassFrame({
            Size = UDim2.new(0,140,0,140), LayoutOrder = i, Parent = packsRow,
        })
        addPadding(card, 12, 8, 12, 8)
        create("TextLabel", {
            Size = UDim2.new(1,0,0,24), BackgroundTransparency = 1,
            Text = pack.name, TextColor3 = pack.color, TextSize = 16,
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
            Parent = card,
        })
        create("TextLabel", {
            Size = UDim2.new(1,0,0,20), Position = UDim2.new(0,0,0,30),
            BackgroundTransparency = 1,
            Text = "R$ " .. pack.robux, TextColor3 = GameConfig.Colors.WhiteDim, TextSize = 13,
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
            Parent = card,
        })
        sleekButton({
            Text = "BUY", Size = UDim2.new(1,-8,0,34), Position = UDim2.new(0.5,0,1,-38),
            AnchorPoint = Vector2.new(0.5,0), Parent = card,
            Color = pack.color, GradientTo = Color3.fromRGB(30,30,30),
            TextSize = 13,
            OnClick = function()
                if pack.id and pack.id > 0 then
                    MarketplaceService:PromptProductPurchase(Player, pack.id)
                end
            end,
        })
    end

    -- Super King section
    create("TextLabel", {
        Size = UDim2.new(1,0,0,24), Position = UDim2.new(0,30,0,260),
        BackgroundTransparency = 1, Text = "PREMIUM",
        TextColor3 = GameConfig.Colors.White, TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        Parent = screen,
    })
    local skCard = glassFrame({
        Size = UDim2.new(0,400,0,120), Position = UDim2.new(0.5,0,0,290),
        AnchorPoint = Vector2.new(0.5,0), Parent = screen,
        StrokeColor = GameConfig.Colors.Gold,
    })
    addPadding(skCard, 16, 16, 16, 16)
    local skBadge = iconBadge(skCard, "SK", GameConfig.Colors.Gold, 48)
    skBadge.Position = UDim2.new(0,0,0.5,0)
    skBadge.AnchorPoint = Vector2.new(0,0.5)
    create("TextLabel", {
        Size = UDim2.new(0,250,0,22), Position = UDim2.new(0,60,0,4),
        BackgroundTransparency = 1, Text = "SUPER KING",
        TextColor3 = GameConfig.Colors.Gold, TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
        Parent = skCard,
    })
    create("TextLabel", {
        Size = UDim2.new(0,250,0,18), Position = UDim2.new(0,60,0,28),
        BackgroundTransparency = 1,
        Text = "+10% ATK buff to ALL your troops, forever!",
        TextColor3 = GameConfig.Colors.WhiteDim, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular),
        Parent = skCard,
    })
    local skStatus = create("TextLabel", {
        Name = "SKStatus",
        Size = UDim2.new(0,100,0,16), Position = UDim2.new(0,60,0,50),
        BackgroundTransparency = 1, Text = "",
        TextColor3 = GameConfig.Colors.Success, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        Parent = skCard,
    })
    sleekButton({
        Text = "R$ 500 - BUY", Size = UDim2.new(0,120,0,36),
        Position = UDim2.new(1,-4,0.5,0), AnchorPoint = Vector2.new(1,0.5),
        Parent = skCard,
        Color = GameConfig.Colors.Gold, GradientTo = Color3.fromRGB(150,110,10),
        TextSize = 13,
        OnClick = function()
            local gpId = GameConfig.Shop.SuperKingGamePassId
            if gpId and gpId > 0 then
                MarketplaceService:PromptGamePassPurchase(Player, gpId)
            end
        end,
    })
    return screen
end

------------------------------------------------------
-- UPGRADES SCREEN
------------------------------------------------------
local function buildUpgradesScreen()
    local screen = create("Frame", {
        Name = "UpgradesScreen", Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1, Parent = BgFrame, Visible = false,
    })
    create("TextLabel", {
        Size = UDim2.new(1,0,0,50), Position = UDim2.new(0,0,0,10),
        BackgroundTransparency = 1, Text = "TROOP UPGRADES",
        TextColor3 = GameConfig.Colors.White, TextSize = 28,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
        Parent = screen,
    })
    -- Coins display
    local coinsLabel = create("TextLabel", {
        Name = "UpgradeCoins",
        Size = UDim2.new(0,150,0,32), Position = UDim2.new(1,-170,0,16),
        BackgroundColor3 = GameConfig.Colors.GoldDim, BackgroundTransparency = 0.3,
        Text = "0 Coins", TextColor3 = GameConfig.Colors.Gold, TextSize = 14,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        Parent = screen,
    })
    addCorner(coinsLabel, 8)
    sleekButton({
        Text = "BACK", Size = UDim2.new(0,80,0,32), Position = UDim2.new(0,20,0,16),
        AnchorPoint = Vector2.new(0,0), Parent = screen,
        Color = GameConfig.Colors.WhiteDimmest, GradientTo = Color3.fromRGB(30,30,30),
        TextSize = 12, OnClick = function() showScreen("home") end,
    })

    local scrollFrame = create("ScrollingFrame", {
        Name = "UpgradeList",
        Size = UDim2.new(1,-60,1,-80), Position = UDim2.new(0,30,0,70),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 4, ScrollBarImageColor3 = GameConfig.Colors.WhiteDim,
        CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = screen,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10),
        HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = scrollFrame,
    })

    -- Build upgrade cards for each unit
    local order = 0
    for _, unitKey in ipairs(UnitDefs.InfantryOrder) do
        if unitKey ~= "king" then
            order = order + 1
            local def = UnitDefs.Types[unitKey]
            local card = glassFrame({
                Name = "Upgrade_" .. unitKey,
                Size = UDim2.new(1,-20,0,64), LayoutOrder = order, Parent = scrollFrame,
            })
            addPadding(card, 8, 12, 8, 12)
            local badge = iconBadge(card, def.iconChar, def.iconColor, 36)
            badge.Position = UDim2.new(0,0,0.5,0); badge.AnchorPoint = Vector2.new(0,0.5)
            create("TextLabel", {
                Size = UDim2.new(0,150,0,18), Position = UDim2.new(0,44,0,4),
                BackgroundTransparency = 1, Text = def.name,
                TextColor3 = GameConfig.Colors.White, TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
                Parent = card,
            })
            create("TextLabel", {
                Name = "LevelText",
                Size = UDim2.new(0,100,0,14), Position = UDim2.new(0,44,0,24),
                BackgroundTransparency = 1, Text = "Lv. 0",
                TextColor3 = GameConfig.Colors.WhiteDim, TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
                Parent = card,
            })
            sleekButton({
                Text = "UPGRADE", Size = UDim2.new(0,100,0,32),
                Position = UDim2.new(1,-4,0.5,0), AnchorPoint = Vector2.new(1,0.5),
                Parent = card, Color = GameConfig.Colors.Accent,
                GradientTo = Color3.fromRGB(60,60,180), TextSize = 12,
                OnClick = function()
                    local result = Remotes.UpgradeTroop:InvokeServer(unitKey)
                    if result and result.success then
                        -- Data will be updated via PlayerDataUpdate event
                    end
                end,
            })
        end
    end
    for _, unitKey in ipairs(UnitDefs.NavalOrder) do
        order = order + 1
        local def = UnitDefs.Types[unitKey]
        local card = glassFrame({
            Name = "Upgrade_" .. unitKey,
            Size = UDim2.new(1,-20,0,64), LayoutOrder = order, Parent = scrollFrame,
        })
        addPadding(card, 8, 12, 8, 12)
        local badge = iconBadge(card, def.iconChar, def.iconColor, 36)
        badge.Position = UDim2.new(0,0,0.5,0); badge.AnchorPoint = Vector2.new(0,0.5)
        create("TextLabel", {
            Size = UDim2.new(0,150,0,18), Position = UDim2.new(0,44,0,4),
            BackgroundTransparency = 1, Text = def.name,
            TextColor3 = GameConfig.Colors.White, TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
            Parent = card,
        })
        create("TextLabel", {
            Name = "LevelText",
            Size = UDim2.new(0,100,0,14), Position = UDim2.new(0,44,0,24),
            BackgroundTransparency = 1, Text = "Lv. 0",
            TextColor3 = GameConfig.Colors.WhiteDim, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
            Parent = card,
        })
        sleekButton({
            Text = "UPGRADE", Size = UDim2.new(0,100,0,32),
            Position = UDim2.new(1,-4,0.5,0), AnchorPoint = Vector2.new(1,0.5),
            Parent = card, Color = GameConfig.Colors.Accent,
            GradientTo = Color3.fromRGB(60,60,180), TextSize = 12,
            OnClick = function()
                local result = Remotes.UpgradeTroop:InvokeServer(unitKey)
                if result and result.success then
                    -- Data will be updated via PlayerDataUpdate event
                end
            end,
        })
    end
    return screen
end

local function refreshUpgrades()
    if not MyPlayerData then return end
    local screen = Screens.upgrades
    if not screen then return end
    local list = screen:FindFirstChild("UpgradeList")
    if not list then return end
    local coinsLabel = screen:FindFirstChild("UpgradeCoins")
    if coinsLabel then coinsLabel.Text = tostring(MyPlayerData.coins or 0) .. " Coins" end

    local allUnits = {}
    for _, k in ipairs(UnitDefs.InfantryOrder) do if k ~= "king" then table.insert(allUnits, k) end end
    for _, k in ipairs(UnitDefs.NavalOrder) do table.insert(allUnits, k) end

    for _, unitKey in ipairs(allUnits) do
        local card = list:FindFirstChild("Upgrade_" .. unitKey)
        if card then
            local lvl = (MyPlayerData.upgrades and MyPlayerData.upgrades[unitKey]) or 0
            local lvlText = card:FindFirstChild("LevelText", true)
            if lvlText then
                if lvl >= GameConfig.MAX_UPGRADE_LEVEL then
                    lvlText.Text = "Lv. " .. lvl .. " (MAX)"
                else
                    local nextCost = GameConfig.UpgradeCost[lvl + 1] or 0
                    lvlText.Text = "Lv. " .. lvl .. " | Next: " .. nextCost .. " coins"
                end
            end
        end
    end
end


------------------------------------------------------
-- GAME SCREEN (Board + HUD)
------------------------------------------------------
local function buildGameScreen()
    local screen = create("Frame", {
        Name = "GameScreen", Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1, Parent = BgFrame, Visible = false,
    })

    -- Top HUD bar
    local topBar = glassFrame({
        Name = "TopBar",
        Size = UDim2.new(1,-20,0,48), Position = UDim2.new(0,10,0,6),
        Parent = screen, BackgroundTransparency = 0.25,
    })
    addPadding(topBar, 6, 12, 6, 12)

    create("TextLabel", {
        Name = "PhaseLabel", Size = UDim2.new(0,140,1,0),
        BackgroundTransparency = 1, Text = "BUILD PHASE",
        TextColor3 = GameConfig.Colors.Gold, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
        Parent = topBar,
    })
    create("TextLabel", {
        Name = "TurnLabel", Size = UDim2.new(0,180,1,0), Position = UDim2.new(0.5,0,0,0),
        AnchorPoint = Vector2.new(0.5,0),
        BackgroundTransparency = 1, Text = "Your Turn",
        TextColor3 = GameConfig.Colors.White, TextSize = 14,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        Parent = topBar,
    })
    create("TextLabel", {
        Name = "GoldLabel", Size = UDim2.new(0,120,1,0), Position = UDim2.new(1,0,0,0),
        AnchorPoint = Vector2.new(1,0),
        BackgroundTransparency = 1, Text = "100 Gold",
        TextColor3 = GameConfig.Colors.Gold, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Right,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        Parent = topBar,
    })

    -- Board container
    local boardContainer = create("Frame", {
        Name = "BoardContainer",
        Size = UDim2.new(1,-20,1,-160), Position = UDim2.new(0,10,0,58),
        BackgroundTransparency = 1, ClipsDescendants = true, Parent = screen,
    })

    -- Board scroll frame
    local boardScroll = create("ScrollingFrame", {
        Name = "BoardScroll",
        Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 6, ScrollBarImageColor3 = GameConfig.Colors.WhiteDim,
        CanvasSize = UDim2.new(0,0,0,0),
        ScrollingDirection = Enum.ScrollingDirection.XY,
        Parent = boardContainer,
    })

    -- Bottom panel
    local bottomPanel = glassFrame({
        Name = "BottomPanel",
        Size = UDim2.new(1,-20,0,90), Position = UDim2.new(0,10,1,-96),
        Parent = screen, BackgroundTransparency = 0.2,
    })
    addPadding(bottomPanel, 8, 12, 8, 12)

    -- Unit info area
    create("TextLabel", {
        Name = "UnitInfoLabel",
        Size = UDim2.new(0,300,0,20), Position = UDim2.new(0,0,0,0),
        BackgroundTransparency = 1, Text = "Select a unit",
        TextColor3 = GameConfig.Colors.White, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        Parent = bottomPanel,
    })
    create("TextLabel", {
        Name = "UnitStatsLabel",
        Size = UDim2.new(0,300,0,16), Position = UDim2.new(0,0,0,22),
        BackgroundTransparency = 1, Text = "",
        TextColor3 = GameConfig.Colors.WhiteDim, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
        Parent = bottomPanel,
    })

    -- Action buttons row
    local actionRow = create("Frame", {
        Name = "ActionRow",
        Size = UDim2.new(0,400,0,36), Position = UDim2.new(0,0,1,-40),
        BackgroundTransparency = 1, Parent = bottomPanel,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8),
        FillDirection = Enum.FillDirection.Horizontal, Parent = actionRow,
    })
    sleekButton({
        Text = "MOVE", Size = UDim2.new(0,80,0,34), Parent = actionRow,
        Color = Color3.fromRGB(56,189,248), GradientTo = Color3.fromRGB(30,100,150),
        LayoutOrder = 1, TextSize = 12,
        OnClick = function() SelectedAction = "move" end,
    })
    sleekButton({
        Text = "ATTACK", Size = UDim2.new(0,80,0,34), Parent = actionRow,
        Color = GameConfig.Colors.Danger, GradientTo = Color3.fromRGB(150,40,40),
        LayoutOrder = 2, TextSize = 12,
        OnClick = function() SelectedAction = "attack" end,
    })
    sleekButton({
        Text = "ABILITY", Size = UDim2.new(0,80,0,34), Parent = actionRow,
        Color = Color3.fromRGB(167,139,250), GradientTo = Color3.fromRGB(90,70,160),
        LayoutOrder = 3, TextSize = 12,
        OnClick = function()
            if SelectedUnit then
                Remotes.UseAbility:FireServer(SelectedUnit)
            end
        end,
    })
    sleekButton({
        Text = "END TURN", Size = UDim2.new(0,100,0,34), Parent = actionRow,
        Color = GameConfig.Colors.Warning, GradientTo = Color3.fromRGB(150,80,20),
        LayoutOrder = 4, TextSize = 12,
        OnClick = function()
            Remotes.EndTurn:FireServer()
            SelectedUnit = nil; SelectedAction = nil
        end,
    })

    -- Deploy panel (right side)
    local deployPanel = glassFrame({
        Name = "DeployPanel",
        Size = UDim2.new(0,160,0,400), Position = UDim2.new(1,-170,0,58),
        Parent = screen, BackgroundTransparency = 0.2,
    })
    addPadding(deployPanel, 8, 8, 8, 8)
    create("TextLabel", {
        Size = UDim2.new(1,0,0,20), BackgroundTransparency = 1,
        Text = "DEPLOY", TextColor3 = GameConfig.Colors.White, TextSize = 13,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
        Parent = deployPanel,
    })
    local deployScroll = create("ScrollingFrame", {
        Name = "DeployScroll",
        Size = UDim2.new(1,0,1,-26), Position = UDim2.new(0,0,0,26),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = deployPanel,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4),
        Parent = deployScroll,
    })

    -- Populate deploy buttons
    local dOrder = 0
    local function addDeployBtn(unitKey)
        local def = UnitDefs.Types[unitKey]
        if not def or not def.deployable then return end
        dOrder = dOrder + 1
        local btn = create("TextButton", {
            Name = "Deploy_" .. unitKey,
            Size = UDim2.new(1,-4,0,36), LayoutOrder = dOrder,
            BackgroundColor3 = GameConfig.Colors.Glass, BackgroundTransparency = 0.3,
            Text = "", AutoButtonColor = false, BorderSizePixel = 0,
            Parent = deployScroll,
        })
        addCorner(btn, 6)
        addStroke(btn, def.iconColor, 1)
        btn.UIStroke.Transparency = 0.7

        local badge = iconBadge(btn, def.iconChar, def.iconColor, 24)
        badge.Position = UDim2.new(0,4,0.5,0); badge.AnchorPoint = Vector2.new(0,0.5)

        create("TextLabel", {
            Size = UDim2.new(1,-64,1,0), Position = UDim2.new(0,32,0,0),
            BackgroundTransparency = 1, Text = def.name,
            TextColor3 = GameConfig.Colors.White, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
            Parent = btn,
        })
        create("TextLabel", {
            Size = UDim2.new(0,30,1,0), Position = UDim2.new(1,-34,0,0),
            BackgroundTransparency = 1, Text = tostring(def.cost),
            TextColor3 = GameConfig.Colors.Gold, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Right,
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
            Parent = btn,
        })

        btn.MouseButton1Click:Connect(function()
            SelectedAction = "deploy"
            SelectedUnit = unitKey
        end)
    end
    -- Infantry
    for _, k in ipairs(UnitDefs.InfantryOrder) do addDeployBtn(k) end
    -- Separator
    create("TextLabel", {
        Size = UDim2.new(1,0,0,20), LayoutOrder = 100,
        BackgroundTransparency = 1, Text = "-- NAVAL --",
        TextColor3 = GameConfig.Colors.RiverBorder, TextSize = 10,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        Parent = deployScroll,
    })
    dOrder = 100
    for _, k in ipairs(UnitDefs.NavalOrder) do addDeployBtn(k) end

    -- Log panel
    local logPanel = glassFrame({
        Name = "LogPanel",
        Size = UDim2.new(0,220,0,200), Position = UDim2.new(0,10,1,-300),
        Parent = screen, BackgroundTransparency = 0.35,
    })
    addPadding(logPanel, 6, 8, 6, 8)
    create("TextLabel", {
        Size = UDim2.new(1,0,0,16), BackgroundTransparency = 1,
        Text = "BATTLE LOG", TextColor3 = GameConfig.Colors.WhiteDim, TextSize = 10,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
        Parent = logPanel,
    })
    local logScroll = create("ScrollingFrame", {
        Name = "LogScroll",
        Size = UDim2.new(1,0,1,-20), Position = UDim2.new(0,0,0,20),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = logPanel,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2),
        Parent = logScroll,
    })

    return screen
end


------------------------------------------------------
-- WIN MODAL
------------------------------------------------------
local function buildWinModal()
    local modal = create("Frame", {
        Name = "WinModal", Size = UDim2.new(1,0,1,0),
        BackgroundColor3 = Color3.fromRGB(0,0,0), BackgroundTransparency = 0.5,
        BorderSizePixel = 0, Visible = false, Parent = BgFrame, ZIndex = 10,
    })
    local box = glassFrame({
        Size = UDim2.new(0,380,0,240), Position = UDim2.new(0.5,0,0.5,0),
        AnchorPoint = Vector2.new(0.5,0.5), Parent = modal,
    })
    box.ZIndex = 11
    addPadding(box, 24, 24, 24, 24)
    create("TextLabel", {
        Name = "WinTitle", Size = UDim2.new(1,0,0,40),
        BackgroundTransparency = 1, Text = "VICTORY!",
        TextColor3 = GameConfig.Colors.Gold, TextSize = 32,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
        Parent = box, ZIndex = 12,
    })
    create("TextLabel", {
        Name = "WinSubtitle", Size = UDim2.new(1,0,0,24), Position = UDim2.new(0,0,0,48),
        BackgroundTransparency = 1, Text = "The enemy King has fallen!",
        TextColor3 = GameConfig.Colors.WhiteDim, TextSize = 14,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
        Parent = box, ZIndex = 12,
    })
    sleekButton({
        Text = "RETURN HOME", Size = UDim2.new(1,0,0,48), Position = UDim2.new(0,0,0,120),
        AnchorPoint = Vector2.new(0,0), Parent = box,
        Color = GameConfig.Colors.Accent, GradientTo = Color3.fromRGB(60,60,180),
        OnClick = function()
            modal.Visible = false
            GameState = nil; SelectedUnit = nil; SelectedAction = nil
            LogMessages = {}
            showScreen("home")
        end,
    })
    return modal
end

------------------------------------------------------
-- BOARD RENDERING
------------------------------------------------------
local function renderBoard()
    if not GameState then return end
    local gameScreen = Screens.game
    if not gameScreen then return end

    local boardScroll = gameScreen:FindFirstChild("BoardContainer")
    if boardScroll then boardScroll = boardScroll:FindFirstChild("BoardScroll") end
    if not boardScroll then return end

    -- Clear old board
    for _, child in ipairs(boardScroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then child:Destroy() end
    end
    BoardFrames = {}

    local mapDef = MapDefs.Maps[GameState.mapKey]
    if not mapDef then return end

    local tileSize = 42
    local gap = 2
    local totalW = mapDef.cols * (tileSize + gap)
    local totalH = mapDef.rows * (tileSize + gap)
    boardScroll.CanvasSize = UDim2.new(0, totalW + 20, 0, totalH + 20)

    for r = 0, mapDef.rows - 1 do
        for c = 0, mapDef.cols - 1 do
            local isRiver = MapDefs.isRiver(GameState.mapKey, c)
            local bgColor = isRiver and GameConfig.Colors.River or GameConfig.Colors.BackgroundLight
            local tile = create("TextButton", {
                Name = "tile_" .. r .. "_" .. c,
                Size = UDim2.new(0, tileSize, 0, tileSize),
                Position = UDim2.new(0, c * (tileSize + gap) + 10, 0, r * (tileSize + gap) + 10),
                BackgroundColor3 = bgColor, BackgroundTransparency = 0.2,
                Text = "", AutoButtonColor = false, BorderSizePixel = 0,
                Parent = boardScroll,
            })
            addCorner(tile, 4)
            if isRiver then
                addStroke(tile, GameConfig.Colors.RiverBorder, 1)
                tile.UIStroke.Transparency = 0.6
            else
                addStroke(tile, GameConfig.Colors.GlassBorder, 1)
                tile.UIStroke.Transparency = 0.8
            end

            BoardFrames[r .. "_" .. c] = tile

            tile.MouseButton1Click:Connect(function()
                if not GameState or GameState.winner then return end
                if GameState.currentTurn ~= MyPlayerId then return end

                if SelectedAction == "deploy" and SelectedUnit then
                    Remotes.DeployUnit:FireServer(SelectedUnit, r, c)
                    SelectedAction = nil; SelectedUnit = nil
                elseif SelectedAction == "move" and SelectedUnit then
                    Remotes.MoveUnit:FireServer(SelectedUnit, r, c)
                    SelectedAction = nil
                end
            end)
        end
    end

    -- Place units on board
    for uid, u in pairs(GameState.units) do
        if not u.dead then
            local key = u.row .. "_" .. u.col
            local tile = BoardFrames[key]
            if tile then
                local def = UnitDefs.Types[u.type]
                if def then
                    local isMe = (u.owner == MyPlayerId)
                    local unitColor = isMe and GameConfig.Colors.Player1 or GameConfig.Colors.Player2
                    local dimColor = isMe and GameConfig.Colors.Player1Dim or GameConfig.Colors.Player2Dim

                    -- Unit frame on tile
                    local unitFrame = create("Frame", {
                        Name = "unit_" .. uid,
                        Size = UDim2.new(1,-4,1,-4), Position = UDim2.new(0.5,0,0.5,0),
                        AnchorPoint = Vector2.new(0.5,0.5),
                        BackgroundColor3 = dimColor, BackgroundTransparency = 0.2,
                        BorderSizePixel = 0, Parent = tile,
                    })
                    addCorner(unitFrame, 4)
                    addStroke(unitFrame, unitColor, 1)
                    unitFrame.UIStroke.Transparency = 0.4

                    -- Icon badge
                    local badge = iconBadge(unitFrame, def.iconChar, def.iconColor, 22)
                    badge.Position = UDim2.new(0.5,0,0,2)
                    badge.AnchorPoint = Vector2.new(0.5,0)

                    -- HP bar
                    local hpPct = u.hp / u.maxHp
                    local hpColor = hpPct > 0.6 and GameConfig.Colors.HealthHigh
                        or hpPct > 0.3 and GameConfig.Colors.HealthMid
                        or GameConfig.Colors.HealthLow
                    local hpBg = create("Frame", {
                        Size = UDim2.new(0.8,0,0,3), Position = UDim2.new(0.1,0,1,-6),
                        BackgroundColor3 = Color3.fromRGB(30,30,30), Parent = unitFrame,
                    })
                    addCorner(hpBg, 2)
                    local hpFill = create("Frame", {
                        Size = UDim2.new(hpPct,0,1,0),
                        BackgroundColor3 = hpColor, Parent = hpBg,
                    })
                    addCorner(hpFill, 2)

                    -- Click handler for selecting unit
                    tile.MouseButton1Click:Connect(function()
                        if not GameState or GameState.winner then return end
                        if GameState.currentTurn ~= MyPlayerId then return end

                        if SelectedAction == "attack" and SelectedUnit and u.owner ~= MyPlayerId then
                            Remotes.AttackUnit:FireServer(SelectedUnit, uid)
                            SelectedAction = nil
                        elseif u.owner == MyPlayerId then
                            SelectedUnit = uid
                            SelectedAction = nil
                            -- Update unit info
                            local bp = Screens.game:FindFirstChild("BottomPanel")
                            if bp then
                                local infoLabel = bp:FindFirstChild("UnitInfoLabel")
                                local statsLabel = bp:FindFirstChild("UnitStatsLabel")
                                if infoLabel then
                                    infoLabel.Text = def.name .. " [" .. def.iconChar .. "]"
                                end
                                if statsLabel then
                                    statsLabel.Text = "HP:" .. u.hp .. "/" .. u.maxHp ..
                                        "  ATK:" .. def.atk .. "  DEF:" .. def.def ..
                                        "  MOV:" .. def.move .. "  RNG:" .. def.range
                                end
                            end
                        end
                    end)
                end
            end
        end
    end

    -- Update HUD
    local topBar = gameScreen:FindFirstChild("TopBar")
    if topBar then
        local phaseLabel = topBar:FindFirstChild("PhaseLabel")
        local turnLabel = topBar:FindFirstChild("TurnLabel")
        local goldLabel = topBar:FindFirstChild("GoldLabel")

        if phaseLabel then
            local phaseNames = {build = "BUILD PHASE", deploy = "DEPLOY PHASE", turn = "BATTLE"}
            phaseLabel.Text = phaseNames[GameState.phase] or GameState.phase
        end
        if turnLabel then
            local isMyTurn = (GameState.currentTurn == MyPlayerId)
            turnLabel.Text = isMyTurn and "YOUR TURN" or "OPPONENT TURN"
            turnLabel.TextColor3 = isMyTurn and GameConfig.Colors.Success or GameConfig.Colors.Danger
        end
        if goldLabel and GameState.players[MyPlayerId] then
            goldLabel.Text = tostring(GameState.players[MyPlayerId].gold or 0) .. " Gold"
        end
    end

    -- Show/hide deploy panel based on phase
    local deployPanel = gameScreen:FindFirstChild("DeployPanel")
    if deployPanel then
        local showDeploy = (GameState.phase == GameConfig.Phase.BUILD or GameState.phase == GameConfig.Phase.DEPLOY)
            and GameState.currentTurn == MyPlayerId
        deployPanel.Visible = showDeploy
    end
end

------------------------------------------------------
-- SCREEN MANAGEMENT
------------------------------------------------------
function showScreen(name, data)
    -- Hide all screens
    for _, screen in pairs(Screens) do
        if screen and screen.Parent then screen.Visible = false end
    end
    -- Also hide win modal
    local winModal = BgFrame:FindFirstChild("WinModal")
    if winModal then winModal.Visible = false end

    CurrentScreen = name

    if name == "splash" then
        Screens.splash.Visible = true
    elseif name == "home" then
        Screens.home.Visible = true
        -- Update coins
        if MyPlayerData then
            local coinsLabel = Screens.home:FindFirstChild("CoinsLabel", true)
            if coinsLabel then coinsLabel.Text = tostring(MyPlayerData.coins or 0) .. " Coins" end
        end
    elseif name == "create" then
        if data then createMode = data end
        Screens.create.Visible = true
    elseif name == "join" then
        Screens.join.Visible = true
    elseif name == "lobby" then
        Screens.lobby.Visible = true
        if data then
            local codeLabel = Screens.lobby:FindFirstChild("RoomCode", true)
            if codeLabel then codeLabel.Text = "CODE: " .. tostring(data) end
        end
    elseif name == "missions" then
        Screens.missions.Visible = true
        refreshMissions()
    elseif name == "shop" then
        Screens.shop.Visible = true
        -- Update Super King status
        if MyPlayerData then
            local skStatus = Screens.shop:FindFirstChild("SKStatus", true)
            if skStatus then
                if MyPlayerData.hasSuperKing then
                    skStatus.Text = "OWNED"
                    skStatus.TextColor3 = GameConfig.Colors.Success
                else
                    skStatus.Text = ""
                end
            end
        end
    elseif name == "upgrades" then
        Screens.upgrades.Visible = true
        refreshUpgrades()
    elseif name == "game" then
        Screens.game.Visible = true
        renderBoard()
    end
end

------------------------------------------------------
-- BUILD ALL SCREENS
------------------------------------------------------
Screens.splash = buildSplashScreen()
Screens.home = buildHomeScreen()
Screens.create = buildCreateScreen()
Screens.join = buildJoinScreen()
Screens.lobby = buildLobbyScreen()
Screens.missions = buildMissionsScreen()
Screens.shop = buildShopScreen()
Screens.upgrades = buildUpgradesScreen()
Screens.game = buildGameScreen()
local WinModal = buildWinModal()

-- Start with splash
showScreen("splash")

------------------------------------------------------
-- REMOTE EVENT HANDLERS
------------------------------------------------------
Remotes.GameStateUpdate.OnClientEvent:Connect(function(newState)
    GameState = newState
    if CurrentScreen == "lobby" then
        showScreen("game")
    elseif CurrentScreen == "game" then
        renderBoard()
    end
end)

Remotes.LogMessage.OnClientEvent:Connect(function(msg)
    table.insert(LogMessages, msg)
    if #LogMessages > 50 then table.remove(LogMessages, 1) end

    if Screens.game and Screens.game.Visible then
        local logPanel = Screens.game:FindFirstChild("LogPanel")
        if logPanel then
            local logScroll = logPanel:FindFirstChild("LogScroll")
            if logScroll then
                local count = 0
                for _, child in ipairs(logScroll:GetChildren()) do
                    if child:IsA("TextLabel") then count = count + 1 end
                end
                create("TextLabel", {
                    Size = UDim2.new(1,0,0,14), LayoutOrder = count + 1,
                    BackgroundTransparency = 1, Text = msg,
                    TextColor3 = GameConfig.Colors.WhiteDim, TextSize = 10,
                    TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular),
                    Parent = logScroll,
                })
                logScroll.CanvasPosition = Vector2.new(0, logScroll.AbsoluteCanvasSize.Y)
            end
        end
    end
end)

Remotes.ToastMessage.OnClientEvent:Connect(function(msg, toastType)
    -- Simple toast notification
    local toast = create("Frame", {
        Size = UDim2.new(0,300,0,40), Position = UDim2.new(0.5,0,0,80),
        AnchorPoint = Vector2.new(0.5,0),
        BackgroundColor3 = toastType == "warn" and GameConfig.Colors.Warning or GameConfig.Colors.Accent,
        BackgroundTransparency = 0.15, Parent = ScreenGui, ZIndex = 20,
    })
    addCorner(toast, 8)
    create("TextLabel", {
        Size = UDim2.new(1,-16,1,0), Position = UDim2.new(0,8,0,0),
        BackgroundTransparency = 1, Text = msg,
        TextColor3 = GameConfig.Colors.White, TextSize = 13,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        Parent = toast, ZIndex = 21,
    })
    task.delay(3, function()
        TweenService:Create(toast, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
        task.wait(0.6)
        if toast.Parent then toast:Destroy() end
    end)
end)

Remotes.GameOver.OnClientEvent:Connect(function(won, finalState)
    GameState = finalState
    renderBoard()
    local winModal = BgFrame:FindFirstChild("WinModal")
    if winModal then
        winModal.Visible = true
        local box = nil
        for _, child in ipairs(winModal:GetChildren()) do
            if child:IsA("Frame") then box = child; break end
        end
        if box then
            local title = box:FindFirstChild("WinTitle")
            local subtitle = box:FindFirstChild("WinSubtitle")
            if title then
                title.Text = won and "VICTORY!" or "DEFEAT"
                title.TextColor3 = won and GameConfig.Colors.Gold or GameConfig.Colors.Danger
            end
            if subtitle then
                subtitle.Text = won and "The enemy King has fallen!" or "Your King has been eliminated..."
            end
        end
    end
end)

Remotes.PlayerDataUpdate.OnClientEvent:Connect(function(data)
    MyPlayerData = data
    -- Refresh UI if on relevant screen
    if CurrentScreen == "missions" then refreshMissions() end
    if CurrentScreen == "upgrades" then refreshUpgrades() end
    if CurrentScreen == "home" then
        local coinsLabel = Screens.home:FindFirstChild("CoinsLabel", true)
        if coinsLabel then coinsLabel.Text = tostring(data.coins or 0) .. " Coins" end
    end
end)

print("[War of Jonk] GameClient loaded successfully")
