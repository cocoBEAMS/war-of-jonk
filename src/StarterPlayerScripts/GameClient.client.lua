--[[
    GameClient.client.lua
    Main client controller for War of Jonk
    Handles all UI interaction, board rendering, input, and game state display
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UnitDefs = require(Modules:WaitForChild("UnitDefs"))
local MapDefs = require(Modules:WaitForChild("MapDefs"))
local GameConfig = require(Modules:WaitForChild("GameConfig"))

-- Remotes
local RemoteFolder = ReplicatedStorage:WaitForChild("Remotes")
local Remotes = {}
for _, child in ipairs(RemoteFolder:GetChildren()) do
    Remotes[child.Name] = child
end

-- Disable default Roblox UI
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

------------------------------------------------------
-- State
------------------------------------------------------
local myId = tostring(player.UserId)
local myName = player.DisplayName or player.Name
local gameState = nil       -- current game state from server
local currentGameId = nil
local amHost = false
local isCpuGame = false

-- Interaction
local selectedUnitId = nil
local interactionMode = "idle"  -- idle, move, attack, deploy
local deployType = nil
local highlights = {}           -- {row, col, type}

-- Board rendering
local boardFolder = nil
local tileFolder = nil
local unitFolder = nil
local highlightFolder = nil

-- UI references (populated after UI creation)
local UI = {}

------------------------------------------------------
-- Colors helper
------------------------------------------------------
local C = GameConfig.Colors

------------------------------------------------------
-- UI BUILDER: Creates the entire ScreenGui programmatically
-- Matches the sleek dark glassmorphism style from the browser version
------------------------------------------------------

local function createUICorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 10)
    corner.Parent = parent
    return corner
end

local function createUIStroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or C.GlassBorder
    stroke.Thickness = thickness or 1
    stroke.Transparency = 0.5
    stroke.Parent = parent
    return stroke
end

local function createUIPadding(parent, t, b, l, r)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, t or 0)
    pad.PaddingBottom = UDim.new(0, b or 0)
    pad.PaddingLeft = UDim.new(0, l or 0)
    pad.PaddingRight = UDim.new(0, r or 0)
    pad.Parent = parent
    return pad
end

local function createButton(parent, text, size, position, bgColor, textColor, callback)
    local btn = Instance.new("TextButton")
    btn.Size = size or UDim2.new(0, 180, 0, 38)
    btn.Position = position or UDim2.new(0.5, -90, 0.5, -19)
    btn.AnchorPoint = Vector2.new(0, 0)
    btn.BackgroundColor3 = bgColor or C.White
    btn.BackgroundTransparency = 0
    btn.Text = text or "Button"
    btn.TextColor3 = textColor or C.Background
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.AutoButtonColor = true
    btn.Parent = parent
    createUICorner(btn, 10)
    if callback then
        btn.MouseButton1Click:Connect(callback)
    end
    return btn
end

local function createGlassFrame(parent, size, position, anchorPoint)
    local frame = Instance.new("Frame")
    frame.Size = size or UDim2.new(1, 0, 1, 0)
    frame.Position = position or UDim2.new(0, 0, 0, 0)
    frame.AnchorPoint = anchorPoint or Vector2.new(0, 0)
    frame.BackgroundColor3 = C.Glass
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = parent
    createUICorner(frame, 12)
    createUIStroke(frame, C.GlassBorder, 1)
    return frame
end

local function createLabel(parent, text, size, position, textColor, fontSize, font, xAlign)
    local label = Instance.new("TextLabel")
    label.Size = size or UDim2.new(1, 0, 0, 20)
    label.Position = position or UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text or ""
    label.TextColor3 = textColor or C.White
    label.Font = font or Enum.Font.GothamBold
    label.TextSize = fontSize or 14
    label.TextXAlignment = xAlign or Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Parent = parent
    return label
end

local function createMonoLabel(parent, text, size, position, textColor, fontSize)
    return createLabel(parent, text, size, position, textColor or C.WhiteDim, fontSize or 11, Enum.Font.RobotoMono)
end

------------------------------------------------------
-- BUILD SCREEN GUI
------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WarOfJonkUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Screens container
local screens = {}

local function showScreen(name)
    for sName, sFrame in pairs(screens) do
        sFrame.Visible = (sName == name)
    end
end

------------------------------------------------------
-- HOME SCREEN
------------------------------------------------------
local function buildHomeScreen()
    local home = Instance.new("Frame")
    home.Name = "HomeScreen"
    home.Size = UDim2.new(1, 0, 1, 0)
    home.BackgroundColor3 = C.Background
    home.BorderSizePixel = 0
    home.Parent = screenGui
    screens.home = home

    -- Top bar
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 56)
    topBar.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
    topBar.BackgroundTransparency = 0.1
    topBar.BorderSizePixel = 0
    topBar.Parent = home

    local topStroke = Instance.new("Frame")
    topStroke.Size = UDim2.new(1, 0, 0, 1)
    topStroke.Position = UDim2.new(0, 0, 1, -1)
    topStroke.BackgroundColor3 = C.GlassBorder
    topStroke.BackgroundTransparency = 0.5
    topStroke.BorderSizePixel = 0
    topStroke.Parent = topBar

    local logo = createLabel(topBar, "War of Jonk", UDim2.new(0, 200, 1, 0), UDim2.new(0, 32, 0, 0), C.White, 20, Enum.Font.GothamBlack)
    logo.TextXAlignment = Enum.TextXAlignment.Left

    -- Tab buttons
    local tabFrame = Instance.new("Frame")
    tabFrame.Size = UDim2.new(0, 300, 0, 36)
    tabFrame.Position = UDim2.new(0, 240, 0.5, -18)
    tabFrame.BackgroundTransparency = 1
    tabFrame.Parent = topBar

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 4)
    tabLayout.Parent = tabFrame

    local currentTab = "loadout"
    local tabButtons = {}
    local tabPanes = {}

    local function switchTab(name)
        currentTab = name
        for tName, tBtn in pairs(tabButtons) do
            if tName == name then
                tBtn.BackgroundTransparency = 0.3
                tBtn.BackgroundColor3 = C.Glass
                tBtn.TextColor3 = C.White
            else
                tBtn.BackgroundTransparency = 1
                tBtn.TextColor3 = C.WhiteDimmer
            end
        end
        for tName, tPane in pairs(tabPanes) do
            tPane.Visible = (tName == name)
        end
    end

    for _, tabInfo in ipairs({{"loadout", "Loadout"}, {"missions", "Missions"}, {"history", "History"}}) do
        local tabBtn = Instance.new("TextButton")
        tabBtn.Size = UDim2.new(0, 90, 1, 0)
        tabBtn.BackgroundColor3 = C.Glass
        tabBtn.BackgroundTransparency = 1
        tabBtn.Text = tabInfo[2]
        tabBtn.TextColor3 = C.WhiteDimmer
        tabBtn.Font = Enum.Font.GothamBold
        tabBtn.TextSize = 13
        tabBtn.Parent = tabFrame
        createUICorner(tabBtn, 8)
        tabBtn.MouseButton1Click:Connect(function() switchTab(tabInfo[1]) end)
        tabButtons[tabInfo[1]] = tabBtn
    end

    -- Action buttons (top right)
    local joinBtn = createButton(topBar, "Join game", UDim2.new(0, 100, 0, 32), UDim2.new(1, -230, 0.5, -16), C.Glass, C.White, function()
        showScreen("lobby")
    end)
    joinBtn.BackgroundTransparency = 0.3
    createUIStroke(joinBtn, C.GlassBorder, 1)

    local createBtn = createButton(topBar, "Create game", UDim2.new(0, 120, 0, 32), UDim2.new(1, -120, 0.5, -16), C.White, C.Background, function()
        showScreen("create")
    end)

    -- Body
    local body = Instance.new("ScrollingFrame")
    body.Size = UDim2.new(1, 0, 1, -56)
    body.Position = UDim2.new(0, 0, 0, 56)
    body.BackgroundTransparency = 1
    body.ScrollBarThickness = 4
    body.ScrollBarImageColor3 = C.WhiteDimmest
    body.CanvasSize = UDim2.new(0, 0, 0, 1200)
    body.BorderSizePixel = 0
    body.Parent = home
    createUIPadding(body, 28, 28, 32, 32)

    -- Loadout tab
    local loadoutPane = Instance.new("Frame")
    loadoutPane.Size = UDim2.new(1, 0, 0, 1100)
    loadoutPane.BackgroundTransparency = 1
    loadoutPane.Parent = body
    tabPanes.loadout = loadoutPane

    local sectionLabel = createMonoLabel(loadoutPane, "INFANTRY & ARTILLERY", UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 0, 0), Color3.fromRGB(72, 72, 72), 10)

    local infantryGrid = Instance.new("Frame")
    infantryGrid.Name = "InfantryGrid"
    infantryGrid.Size = UDim2.new(1, 0, 0, 400)
    infantryGrid.Position = UDim2.new(0, 0, 0, 24)
    infantryGrid.BackgroundTransparency = 1
    infantryGrid.Parent = loadoutPane
    UI.infantryGrid = infantryGrid

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 170, 0, 160)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = infantryGrid

    -- Build infantry cards
    for i, unitType in ipairs(UnitDefs.InfantryOrder) do
        local def = UnitDefs.Types[unitType]
        local card = createGlassFrame(infantryGrid, UDim2.new(0, 170, 0, 160))
        card.LayoutOrder = i
        createUIPadding(card, 12, 12, 14, 14)

        local iconLabel = createLabel(card, def.emoji or "?", UDim2.new(1, 0, 0, 32), UDim2.new(0, 0, 0, 0), C.White, 26, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
        local nameLabel = createLabel(card, def.name, UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 36), C.White, 13, Enum.Font.GothamBold)
        local typeLabel = createMonoLabel(card, string.upper(def.theatre), UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 54), C.WhiteDimmer, 10)

        local statsFrame = Instance.new("Frame")
        statsFrame.Size = UDim2.new(1, 0, 0, 40)
        statsFrame.Position = UDim2.new(0, 0, 0, 72)
        statsFrame.BackgroundTransparency = 1
        statsFrame.Parent = card

        local statsLayout = Instance.new("UIListLayout")
        statsLayout.FillDirection = Enum.FillDirection.Horizontal
        statsLayout.Padding = UDim.new(0, 6)
        statsLayout.Wraps = true
        statsLayout.Parent = statsFrame

        local function addStatChip(text, color)
            local chip = Instance.new("TextLabel")
            chip.Size = UDim2.new(0, 0, 0, 18)
            chip.AutomaticSize = Enum.AutomaticSize.X
            chip.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            chip.BackgroundTransparency = 0.3
            chip.Text = " " .. text .. " "
            chip.TextColor3 = color or C.WhiteDim
            chip.Font = Enum.Font.RobotoMono
            chip.TextSize = 10
            chip.Parent = statsFrame
            createUICorner(chip, 4)
        end

        addStatChip("HP " .. def.maxHp)
        addStatChip("ATK " .. def.atk)
        addStatChip("DEF " .. def.def)
        addStatChip("MOV " .. def.move)
        if def.cost > 0 then
            addStatChip("@ " .. def.cost, C.Gold)
        end

        if def.ability then
            local abilLabel = createMonoLabel(card, def.ability, UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 120), C.WhiteDim, 10)
        end
    end

    -- Naval divider
    local navalDivider = Instance.new("Frame")
    navalDivider.Size = UDim2.new(1, 0, 0, 20)
    navalDivider.Position = UDim2.new(0, 0, 0, 440)
    navalDivider.BackgroundTransparency = 1
    navalDivider.Parent = loadoutPane

    local divLine1 = Instance.new("Frame")
    divLine1.Size = UDim2.new(0.4, 0, 0, 1)
    divLine1.Position = UDim2.new(0, 0, 0.5, 0)
    divLine1.BackgroundColor3 = C.GlassBorder
    divLine1.BackgroundTransparency = 0.5
    divLine1.BorderSizePixel = 0
    divLine1.Parent = navalDivider

    local divText = createMonoLabel(navalDivider, "NAVAL THEATRE", UDim2.new(0.2, 0, 1, 0), UDim2.new(0.4, 0, 0, 0), Color3.fromRGB(56, 189, 248), 10)
    divText.TextXAlignment = Enum.TextXAlignment.Center
    divText.TextTransparency = 0.4

    local divLine2 = Instance.new("Frame")
    divLine2.Size = UDim2.new(0.4, 0, 0, 1)
    divLine2.Position = UDim2.new(0.6, 0, 0.5, 0)
    divLine2.BackgroundColor3 = C.GlassBorder
    divLine2.BackgroundTransparency = 0.5
    divLine2.BorderSizePixel = 0
    divLine2.Parent = navalDivider

    -- Naval grid
    local navalGrid = Instance.new("Frame")
    navalGrid.Name = "NavalGrid"
    navalGrid.Size = UDim2.new(1, 0, 0, 200)
    navalGrid.Position = UDim2.new(0, 0, 0, 470)
    navalGrid.BackgroundTransparency = 1
    navalGrid.Parent = loadoutPane

    local navalGridLayout = Instance.new("UIGridLayout")
    navalGridLayout.CellSize = UDim2.new(0, 170, 0, 160)
    navalGridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    navalGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    navalGridLayout.Parent = navalGrid

    for i, unitType in ipairs(UnitDefs.NavalOrder) do
        local def = UnitDefs.Types[unitType]
        local card = createGlassFrame(navalGrid, UDim2.new(0, 170, 0, 160))
        card.LayoutOrder = i
        createUIPadding(card, 12, 12, 14, 14)

        createLabel(card, def.emoji or "?", UDim2.new(1, 0, 0, 32), UDim2.new(0, 0, 0, 0), C.White, 26, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
        createLabel(card, def.name, UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 36), C.White, 13, Enum.Font.GothamBold)
        createMonoLabel(card, "NAVAL", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 54), C.WhiteDimmer, 10)

        local statsFrame = Instance.new("Frame")
        statsFrame.Size = UDim2.new(1, 0, 0, 40)
        statsFrame.Position = UDim2.new(0, 0, 0, 72)
        statsFrame.BackgroundTransparency = 1
        statsFrame.Parent = card

        local sl = Instance.new("UIListLayout")
        sl.FillDirection = Enum.FillDirection.Horizontal
        sl.Padding = UDim.new(0, 6)
        sl.Wraps = true
        sl.Parent = statsFrame

        local function addChip(text, color)
            local chip = Instance.new("TextLabel")
            chip.Size = UDim2.new(0, 0, 0, 18)
            chip.AutomaticSize = Enum.AutomaticSize.X
            chip.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            chip.BackgroundTransparency = 0.3
            chip.Text = " " .. text .. " "
            chip.TextColor3 = color or C.WhiteDim
            chip.Font = Enum.Font.RobotoMono
            chip.TextSize = 10
            chip.Parent = statsFrame
            createUICorner(chip, 4)
        end

        addChip("HP " .. def.maxHp)
        addChip("ATK " .. def.atk)
        addChip("MOV " .. def.move)
        if def.cost > 0 then addChip("@ " .. def.cost, C.Gold) end

        if def.ability then
            createMonoLabel(card, def.ability, UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 120), Color3.fromRGB(56, 189, 248), 10)
        end
    end

    -- Missions tab
    local missionsPane = Instance.new("Frame")
    missionsPane.Size = UDim2.new(1, 0, 0, 600)
    missionsPane.BackgroundTransparency = 1
    missionsPane.Visible = false
    missionsPane.Parent = body
    tabPanes.missions = missionsPane

    createMonoLabel(missionsPane, "UNLOCK MISSIONS", UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 0, 0), Color3.fromRGB(72, 72, 72), 10)

    local missionsLayout = Instance.new("UIListLayout")
    missionsLayout.Padding = UDim.new(0, 10)
    missionsLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local missionsContainer = Instance.new("Frame")
    missionsContainer.Size = UDim2.new(1, 0, 0, 500)
    missionsContainer.Position = UDim2.new(0, 0, 0, 24)
    missionsContainer.BackgroundTransparency = 1
    missionsContainer.Parent = missionsPane
    missionsLayout.Parent = missionsContainer

    local missionData = {
        {icon = "TARGET", name = "Railgun Unlock", desc = "Play 100 games", reward = "Railgun Jonk"},
        {icon = "MICROBE", name = "Mole Daddy Unlock", desc = "Play 500 games", reward = "Mole Daddy"},
        {icon = "ANCHOR", name = "Zumwalt Commission", desc = "Kill 2000 units", reward = "Zumwalt Jonk"},
        {icon = "SKULL", name = "King Slayer", desc = "Kill 1000 Kings", reward = "Zumwalt part"},
        {icon = "TROPHY", name = "Battle Hardened", desc = "Lose 50 times", reward = "Zumwalt part"},
    }

    for i, m in ipairs(missionData) do
        local mCard = createGlassFrame(missionsContainer, UDim2.new(1, 0, 0, 80))
        mCard.LayoutOrder = i
        createUIPadding(mCard, 12, 12, 16, 16)

        createLabel(mCard, m.icon, UDim2.new(0, 30, 0, 30), UDim2.new(0, 0, 0.5, -15), C.White, 20, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
        createLabel(mCard, m.name, UDim2.new(0.5, 0, 0, 18), UDim2.new(0, 44, 0, 4), C.White, 14, Enum.Font.GothamBold)
        createMonoLabel(mCard, m.desc, UDim2.new(0.5, 0, 0, 14), UDim2.new(0, 44, 0, 24), C.WhiteDim, 12)

        -- Progress bar
        local barBg = Instance.new("Frame")
        barBg.Size = UDim2.new(0.4, 0, 0, 4)
        barBg.Position = UDim2.new(0, 44, 0, 46)
        barBg.BackgroundColor3 = C.WhiteDimmest
        barBg.BorderSizePixel = 0
        barBg.Parent = mCard
        createUICorner(barBg, 2)

        local barFill = Instance.new("Frame")
        barFill.Size = UDim2.new(0, 0, 1, 0)
        barFill.BackgroundColor3 = C.Gold
        barFill.BorderSizePixel = 0
        barFill.Parent = barBg
        createUICorner(barFill, 2)

        createMonoLabel(mCard, "-> " .. m.reward, UDim2.new(0, 150, 0, 16), UDim2.new(1, -150, 0.5, -8), C.Gold, 12)
    end

    -- History tab
    local historyPane = Instance.new("Frame")
    historyPane.Size = UDim2.new(1, 0, 0, 400)
    historyPane.BackgroundTransparency = 1
    historyPane.Visible = false
    historyPane.Parent = body
    tabPanes.history = historyPane

    createMonoLabel(historyPane, "RECENT MATCHES", UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 0, 0), Color3.fromRGB(72, 72, 72), 10)

    local historyMsg = createMonoLabel(historyPane, "No games played yet.", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 40), C.WhiteDimmer, 13)
    UI.historyMsg = historyMsg

    -- Activate loadout tab by default
    switchTab("loadout")
end

------------------------------------------------------
-- CREATE GAME SCREEN
------------------------------------------------------
local function buildCreateScreen()
    local create = Instance.new("Frame")
    create.Name = "CreateScreen"
    create.Size = UDim2.new(1, 0, 1, 0)
    create.BackgroundColor3 = C.Background
    create.BorderSizePixel = 0
    create.Visible = false
    create.Parent = screenGui
    screens.create = create

    local card = createGlassFrame(create, UDim2.new(0, 480, 0, 420), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
    createUIPadding(card, 40, 40, 48, 48)

    local title = createLabel(card, "Create Game", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 0), C.White, 28, Enum.Font.GothamBlack)
    local sub = createMonoLabel(card, "choose your battle mode", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 40), C.WhiteDim, 13)

    -- Name input
    createMonoLabel(card, "YOUR NAME", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 76), C.WhiteDimmer, 10)

    local nameInput = Instance.new("TextBox")
    nameInput.Size = UDim2.new(1, 0, 0, 44)
    nameInput.Position = UDim2.new(0, 0, 0, 94)
    nameInput.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    nameInput.BackgroundTransparency = 0.3
    nameInput.Text = myName
    nameInput.PlaceholderText = "Commander name..."
    nameInput.PlaceholderColor3 = Color3.fromRGB(50, 50, 50)
    nameInput.TextColor3 = C.White
    nameInput.Font = Enum.Font.Gotham
    nameInput.TextSize = 15
    nameInput.ClearTextOnFocus = false
    nameInput.Parent = card
    createUICorner(nameInput, 10)
    createUIStroke(nameInput, C.GlassBorder, 1)
    createUIPadding(nameInput, 0, 0, 16, 16)
    UI.createNameInput = nameInput

    -- Game mode selection
    createMonoLabel(card, "GAME MODE", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 152), C.WhiteDimmer, 10)

    local modeFrame = Instance.new("Frame")
    modeFrame.Size = UDim2.new(1, 0, 0, 90)
    modeFrame.Position = UDim2.new(0, 0, 0, 170)
    modeFrame.BackgroundTransparency = 1
    modeFrame.Parent = card

    local modeLayout = Instance.new("UIListLayout")
    modeLayout.FillDirection = Enum.FillDirection.Horizontal
    modeLayout.Padding = UDim.new(0, 10)
    modeLayout.Parent = modeFrame

    local selectedMode = "cpu"

    local cpuCard = createGlassFrame(modeFrame, UDim2.new(0.5, -5, 1, 0))
    cpuCard.LayoutOrder = 1
    local cpuIcon = createLabel(cpuCard, "CPU", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 12), C.White, 22, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    local cpuName = createLabel(cpuCard, "vs CPU", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 40), C.White, 13, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    local cpuDesc = createMonoLabel(cpuCard, "Solo vs AI opponent", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 60), C.WhiteDimmer, 10)
    cpuDesc.TextXAlignment = Enum.TextXAlignment.Center

    local pvpCard = createGlassFrame(modeFrame, UDim2.new(0.5, -5, 1, 0))
    pvpCard.LayoutOrder = 2
    local pvpIcon = createLabel(pvpCard, "PVP", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 12), C.White, 22, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    local pvpName = createLabel(pvpCard, "vs Player", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 40), C.White, 13, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    local pvpDesc = createMonoLabel(pvpCard, "Online multiplayer", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 60), C.WhiteDimmer, 10)
    pvpDesc.TextXAlignment = Enum.TextXAlignment.Center

    local function updateModeVisual()
        if selectedMode == "cpu" then
            cpuCard.BackgroundTransparency = 0.1
            pvpCard.BackgroundTransparency = 0.5
        else
            cpuCard.BackgroundTransparency = 0.5
            pvpCard.BackgroundTransparency = 0.1
        end
    end
    updateModeVisual()

    cpuCard.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            selectedMode = "cpu"
            updateModeVisual()
        end
    end)
    pvpCard.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            selectedMode = "player"
            updateModeVisual()
        end
    end)

    -- Buttons
    local btnFrame = Instance.new("Frame")
    btnFrame.Size = UDim2.new(1, 0, 0, 38)
    btnFrame.Position = UDim2.new(0, 0, 0, 280)
    btnFrame.BackgroundTransparency = 1
    btnFrame.Parent = card

    local backBtn = createButton(btnFrame, "Back", UDim2.new(0.48, 0, 1, 0), UDim2.new(0, 0, 0, 0), C.Glass, C.White, function()
        showScreen("home")
    end)
    backBtn.BackgroundTransparency = 0.3
    createUIStroke(backBtn, C.GlassBorder, 1)

    local goBtn = createButton(btnFrame, "Create", UDim2.new(0.48, 0, 1, 0), UDim2.new(0.52, 0, 0, 0), C.White, C.Background, function()
        local name = nameInput.Text
        if name == "" then name = myName end
        myName = name
        isCpuGame = (selectedMode == "cpu")
        amHost = true

        local result = Remotes.CreateGame:InvokeServer(name, selectedMode)
        if result and result.success then
            currentGameId = result.gameId
            if selectedMode == "cpu" then
                gameState = result.game
                showScreen("game")
                buildGameBoard()
                updateGameUI()
            else
                -- Show loading/waiting screen
                UI.loadingCode.Text = result.roomCode or result.gameId
                UI.loadingStatus.Text = "Waiting for opponent to join..."
                showScreen("loading")
            end
        end
    end)
end

------------------------------------------------------
-- JOIN LOBBY SCREEN
------------------------------------------------------
local function buildLobbyScreen()
    local lobby = Instance.new("Frame")
    lobby.Name = "LobbyScreen"
    lobby.Size = UDim2.new(1, 0, 1, 0)
    lobby.BackgroundColor3 = C.Background
    lobby.BorderSizePixel = 0
    lobby.Visible = false
    lobby.Parent = screenGui
    screens.lobby = lobby

    local card = createGlassFrame(lobby, UDim2.new(0, 520, 0, 380), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
    createUIPadding(card, 40, 40, 48, 48)

    createLabel(card, "War of Jonk", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), C.White, 36, Enum.Font.GothamBlack)
    createMonoLabel(card, "join an existing room", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 44), C.WhiteDim, 13)

    -- Name input
    createMonoLabel(card, "YOUR NAME", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 80), C.WhiteDimmer, 10)
    local joinNameInput = Instance.new("TextBox")
    joinNameInput.Size = UDim2.new(1, 0, 0, 44)
    joinNameInput.Position = UDim2.new(0, 0, 0, 98)
    joinNameInput.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    joinNameInput.BackgroundTransparency = 0.3
    joinNameInput.Text = myName
    joinNameInput.PlaceholderText = "Commander name..."
    joinNameInput.PlaceholderColor3 = Color3.fromRGB(50, 50, 50)
    joinNameInput.TextColor3 = C.White
    joinNameInput.Font = Enum.Font.Gotham
    joinNameInput.TextSize = 15
    joinNameInput.ClearTextOnFocus = false
    joinNameInput.Parent = card
    createUICorner(joinNameInput, 10)
    createUIStroke(joinNameInput, C.GlassBorder, 1)
    createUIPadding(joinNameInput, 0, 0, 16, 16)

    -- Room code input
    createMonoLabel(card, "ROOM CODE", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 156), C.WhiteDimmer, 10)
    local codeInput = Instance.new("TextBox")
    codeInput.Size = UDim2.new(1, 0, 0, 44)
    codeInput.Position = UDim2.new(0, 0, 0, 174)
    codeInput.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    codeInput.BackgroundTransparency = 0.3
    codeInput.Text = ""
    codeInput.PlaceholderText = "e.g. JONK42"
    codeInput.PlaceholderColor3 = Color3.fromRGB(50, 50, 50)
    codeInput.TextColor3 = C.White
    codeInput.Font = Enum.Font.RobotoMono
    codeInput.TextSize = 15
    codeInput.ClearTextOnFocus = false
    codeInput.Parent = card
    createUICorner(codeInput, 10)
    createUIStroke(codeInput, C.GlassBorder, 1)
    createUIPadding(codeInput, 0, 0, 16, 16)

    -- Status label
    local joinStatus = createMonoLabel(card, "", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 280), C.WhiteDim, 12)
    joinStatus.TextXAlignment = Enum.TextXAlignment.Center
    UI.joinStatus = joinStatus

    -- Buttons
    local btnFrame = Instance.new("Frame")
    btnFrame.Size = UDim2.new(1, 0, 0, 38)
    btnFrame.Position = UDim2.new(0, 0, 0, 234)
    btnFrame.BackgroundTransparency = 1
    btnFrame.Parent = card

    local backBtn = createButton(btnFrame, "Back", UDim2.new(0.48, 0, 1, 0), UDim2.new(0, 0, 0, 0), C.Glass, C.White, function()
        showScreen("home")
    end)
    backBtn.BackgroundTransparency = 0.3
    createUIStroke(backBtn, C.GlassBorder, 1)

    createButton(btnFrame, "Join", UDim2.new(0.48, 0, 1, 0), UDim2.new(0.52, 0, 0, 0), C.White, C.Background, function()
        local name = joinNameInput.Text
        if name == "" then name = myName end
        local code = string.upper(codeInput.Text)
        if code == "" then
            joinStatus.Text = "Enter room code"
            return
        end

        myName = name
        amHost = false
        isCpuGame = false

        local result = Remotes.JoinGame:InvokeServer(name, code)
        if result and result.success then
            currentGameId = result.gameId
            gameState = result.game
            showScreen("game")
            buildGameBoard()
            updateGameUI()
        else
            joinStatus.Text = result and result.error or "Failed to join"
        end
    end)
end

------------------------------------------------------
-- LOADING / WAITING SCREEN
------------------------------------------------------
local function buildLoadingScreen()
    local loading = Instance.new("Frame")
    loading.Name = "LoadingScreen"
    loading.Size = UDim2.new(1, 0, 1, 0)
    loading.BackgroundColor3 = C.Background
    loading.BorderSizePixel = 0
    loading.Visible = false
    loading.Parent = screenGui
    screens.loading = loading

    local card = createGlassFrame(loading, UDim2.new(0, 480, 0, 360), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
    createUIPadding(card, 48, 48, 56, 56)

    createLabel(card, "Room Created", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 0), C.White, 22, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
    createMonoLabel(card, "Share this code with your opponent", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 32), C.WhiteDim, 13).TextXAlignment = Enum.TextXAlignment.Center

    local codeLabel = createLabel(card, "------", UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0, 70), C.White, 48, Enum.Font.RobotoMono, Enum.TextXAlignment.Center)
    UI.loadingCode = codeLabel

    createMonoLabel(card, "Share this code -- opponent enters it to join", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 138), C.WhiteDimmer, 11).TextXAlignment = Enum.TextXAlignment.Center

    -- Loading bar
    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, 0, 0, 2)
    barBg.Position = UDim2.new(0, 0, 0, 170)
    barBg.BackgroundColor3 = C.WhiteDimmest
    barBg.BorderSizePixel = 0
    barBg.Parent = card
    createUICorner(barBg, 1)

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = C.Player1
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg
    createUICorner(barFill, 1)

    -- Animate the loading bar
    task.spawn(function()
        while loading.Visible do
            local tween = TweenService:Create(barFill, TweenInfo.new(3, Enum.EasingStyle.Quad), {Size = UDim2.new(0.95, 0, 1, 0)})
            tween:Play()
            tween.Completed:Wait()
            barFill.Size = UDim2.new(0, 0, 1, 0)
        end
    end)

    -- Dots animation
    local dotsLabel = createMonoLabel(card, "...", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 190), C.WhiteDim, 16)
    dotsLabel.TextXAlignment = Enum.TextXAlignment.Center

    local statusLabel = createMonoLabel(card, "Waiting for opponent to join...", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 216), C.WhiteDim, 12)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    UI.loadingStatus = statusLabel

    -- Cancel button
    local cancelBtn = createButton(card, "Cancel", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 1, -36), C.Glass, C.White, function()
        showScreen("home")
    end)
    cancelBtn.BackgroundTransparency = 0.3
    createUIStroke(cancelBtn, C.GlassBorder, 1)
end

------------------------------------------------------
-- GAME SCREEN
------------------------------------------------------
local function buildGameScreen()
    local gameScreen = Instance.new("Frame")
    gameScreen.Name = "GameScreen"
    gameScreen.Size = UDim2.new(1, 0, 1, 0)
    gameScreen.BackgroundColor3 = C.Background
    gameScreen.BorderSizePixel = 0
    gameScreen.Visible = false
    gameScreen.Parent = screenGui
    screens.game = gameScreen

    -- TOP BAR
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 50)
    topBar.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
    topBar.BackgroundTransparency = 0.08
    topBar.BorderSizePixel = 0
    topBar.Parent = gameScreen

    local topBarStroke = Instance.new("Frame")
    topBarStroke.Size = UDim2.new(1, 0, 0, 1)
    topBarStroke.Position = UDim2.new(0, 0, 1, -1)
    topBarStroke.BackgroundColor3 = C.GlassBorder
    topBarStroke.BackgroundTransparency = 0.5
    topBarStroke.BorderSizePixel = 0
    topBarStroke.Parent = topBar

    createLabel(topBar, "War of Jonk", UDim2.new(0, 120, 1, 0), UDim2.new(0, 16, 0, 0), C.White, 14, Enum.Font.GothamBlack)

    -- Divider
    local div1 = Instance.new("Frame")
    div1.Size = UDim2.new(0, 1, 0, 18)
    div1.Position = UDim2.new(0, 140, 0.5, -9)
    div1.BackgroundColor3 = C.GlassBorder
    div1.BorderSizePixel = 0
    div1.Parent = topBar

    -- Turn indicator
    local turnDot = Instance.new("Frame")
    turnDot.Size = UDim2.new(0, 8, 0, 8)
    turnDot.Position = UDim2.new(0, 156, 0.5, -4)
    turnDot.BackgroundColor3 = C.Player1
    turnDot.BorderSizePixel = 0
    turnDot.Parent = topBar
    createUICorner(turnDot, 4)
    UI.turnDot = turnDot

    local turnLabel = createMonoLabel(topBar, "Your turn", UDim2.new(0, 120, 1, 0), UDim2.new(0, 172, 0, 0), C.WhiteDim, 12)
    turnLabel.TextYAlignment = Enum.TextYAlignment.Center
    UI.turnLabel = turnLabel

    -- Divider 2
    local div2 = Instance.new("Frame")
    div2.Size = UDim2.new(0, 1, 0, 18)
    div2.Position = UDim2.new(0, 300, 0.5, -9)
    div2.BackgroundColor3 = C.GlassBorder
    div2.BorderSizePixel = 0
    div2.Parent = topBar

    -- Phase pill
    local phasePill = Instance.new("TextLabel")
    phasePill.Size = UDim2.new(0, 110, 0, 24)
    phasePill.Position = UDim2.new(0, 316, 0.5, -12)
    phasePill.BackgroundColor3 = C.Glass
    phasePill.BackgroundTransparency = 0.3
    phasePill.Text = "BUILD PHASE"
    phasePill.TextColor3 = C.Warning
    phasePill.Font = Enum.Font.RobotoMono
    phasePill.TextSize = 10
    phasePill.Parent = topBar
    createUICorner(phasePill, 12)
    createUIStroke(phasePill, Color3.fromRGB(100, 58, 24), 1)
    UI.phasePill = phasePill

    -- Timer
    local timer = createLabel(topBar, "--", UDim2.new(0, 50, 1, 0), UDim2.new(1, -180, 0, 0), C.White, 16, Enum.Font.RobotoMono, Enum.TextXAlignment.Center)
    timer.TextYAlignment = Enum.TextYAlignment.Center
    UI.timer = timer

    -- End Turn button
    local endTurnBtn = createButton(topBar, "End turn", UDim2.new(0, 100, 0, 32), UDim2.new(1, -118, 0.5, -16), C.White, C.Background, function()
        if gameState and gameState.currentTurn == myId then
            Remotes.EndTurn:FireServer()
            clearSelection()
        end
    end)
    UI.endTurnBtn = endTurnBtn

    -- GAME BODY
    local gameBody = Instance.new("Frame")
    gameBody.Size = UDim2.new(1, 0, 1, -84)
    gameBody.Position = UDim2.new(0, 0, 0, 50)
    gameBody.BackgroundTransparency = 1
    gameBody.BorderSizePixel = 0
    gameBody.Parent = gameScreen

    -- LEFT PANEL (Player HUD + Deploy roster)
    local leftPanel = Instance.new("Frame")
    leftPanel.Size = UDim2.new(0, 210, 1, 0)
    leftPanel.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
    leftPanel.BackgroundTransparency = 0.3
    leftPanel.BorderSizePixel = 0
    leftPanel.Parent = gameBody

    local leftStroke = Instance.new("Frame")
    leftStroke.Size = UDim2.new(0, 1, 1, 0)
    leftStroke.Position = UDim2.new(1, -1, 0, 0)
    leftStroke.BackgroundColor3 = C.GlassBorder
    leftStroke.BackgroundTransparency = 0.5
    leftStroke.BorderSizePixel = 0
    leftStroke.Parent = leftPanel

    -- My HUD section
    local myHudSection = Instance.new("Frame")
    myHudSection.Size = UDim2.new(1, 0, 0, 120)
    myHudSection.BackgroundTransparency = 1
    myHudSection.Parent = leftPanel
    createUIPadding(myHudSection, 14, 14, 14, 14)

    createMonoLabel(myHudSection, "YOU", UDim2.new(1, 0, 0, 12), UDim2.new(0, 0, 0, 0), Color3.fromRGB(64, 64, 64), 9)

    local myHud = createGlassFrame(myHudSection, UDim2.new(1, 0, 0, 80), UDim2.new(0, 0, 0, 18))
    myHud.BackgroundColor3 = C.Player1Dim
    createUIStroke(myHud, C.Player1Border, 1)
    createUIPadding(myHud, 10, 10, 12, 12)

    -- Player dot + name
    local myDot = Instance.new("Frame")
    myDot.Size = UDim2.new(0, 6, 0, 6)
    myDot.Position = UDim2.new(0, 0, 0, 3)
    myDot.BackgroundColor3 = C.Player1
    myDot.BorderSizePixel = 0
    myDot.Parent = myHud
    createUICorner(myDot, 3)

    local myNameLabel = createLabel(myHud, myName, UDim2.new(1, -14, 0, 16), UDim2.new(0, 14, 0, 0), C.White, 12, Enum.Font.GothamBold)
    UI.myNameLabel = myNameLabel

    -- King HP bar
    createMonoLabel(myHud, "King", UDim2.new(0, 30, 0, 12), UDim2.new(0, 0, 0, 22), C.WhiteDimmer, 9)
    local myKingBarBg = Instance.new("Frame")
    myKingBarBg.Size = UDim2.new(1, -70, 0, 3)
    myKingBarBg.Position = UDim2.new(0, 35, 0, 28)
    myKingBarBg.BackgroundColor3 = C.WhiteDimmest
    myKingBarBg.BorderSizePixel = 0
    myKingBarBg.Parent = myHud
    createUICorner(myKingBarBg, 2)

    local myKingBar = Instance.new("Frame")
    myKingBar.Size = UDim2.new(1, 0, 1, 0)
    myKingBar.BackgroundColor3 = C.Player1
    myKingBar.BorderSizePixel = 0
    myKingBar.Parent = myKingBarBg
    createUICorner(myKingBar, 2)
    UI.myKingBar = myKingBar

    local myKingVal = createMonoLabel(myHud, "100", UDim2.new(0, 30, 0, 12), UDim2.new(1, -30, 0, 22), C.WhiteDim, 9)
    myKingVal.TextXAlignment = Enum.TextXAlignment.Right
    UI.myKingVal = myKingVal

    -- Gold display
    local goldLabel = createMonoLabel(myHud, "@ 0 gold", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 40), C.Gold, 11)
    UI.myGoldLabel = goldLabel

    -- Separator
    local sepLine = Instance.new("Frame")
    sepLine.Size = UDim2.new(1, 0, 0, 1)
    sepLine.Position = UDim2.new(0, 0, 0, 120)
    sepLine.BackgroundColor3 = C.WhiteDimmest
    sepLine.BackgroundTransparency = 0.5
    sepLine.BorderSizePixel = 0
    sepLine.Parent = leftPanel

    -- Deploy roster
    local deploySection = Instance.new("Frame")
    deploySection.Size = UDim2.new(1, 0, 0, 30)
    deploySection.Position = UDim2.new(0, 0, 0, 124)
    deploySection.BackgroundTransparency = 1
    deploySection.Parent = leftPanel
    createUIPadding(deploySection, 0, 0, 14, 14)
    createMonoLabel(deploySection, "DEPLOY -- click unit then board", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(64, 64, 64), 9)

    local deployScroll = Instance.new("ScrollingFrame")
    deployScroll.Size = UDim2.new(1, 0, 1, -160)
    deployScroll.Position = UDim2.new(0, 0, 0, 158)
    deployScroll.BackgroundTransparency = 1
    deployScroll.ScrollBarThickness = 3
    deployScroll.ScrollBarImageColor3 = C.WhiteDimmest
    deployScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    deployScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    deployScroll.BorderSizePixel = 0
    deployScroll.Parent = leftPanel

    local deployLayout = Instance.new("UIListLayout")
    deployLayout.Padding = UDim.new(0, 5)
    deployLayout.SortOrder = Enum.SortOrder.LayoutOrder
    deployLayout.Parent = deployScroll
    createUIPadding(deployScroll, 4, 4, 10, 10)

    UI.deployScroll = deployScroll

    -- CENTER (Board canvas area)
    local canvasWrap = Instance.new("Frame")
    canvasWrap.Size = UDim2.new(1, -420, 1, 0)
    canvasWrap.Position = UDim2.new(0, 210, 0, 0)
    canvasWrap.BackgroundColor3 = Color3.fromRGB(3, 3, 3)
    canvasWrap.BackgroundTransparency = 0
    canvasWrap.BorderSizePixel = 0
    canvasWrap.ClipsDescendants = true
    canvasWrap.Parent = gameBody
    UI.canvasWrap = canvasWrap

    -- The board will be built from SurfaceGuis or Frame-based tile grid
    local boardFrame = Instance.new("Frame")
    boardFrame.Name = "BoardFrame"
    boardFrame.BackgroundTransparency = 1
    boardFrame.Parent = canvasWrap
    UI.boardFrame = boardFrame

    -- RIGHT PANEL (Opponent HUD + Unit detail)
    local rightPanel = Instance.new("Frame")
    rightPanel.Size = UDim2.new(0, 210, 1, 0)
    rightPanel.Position = UDim2.new(1, -210, 0, 0)
    rightPanel.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
    rightPanel.BackgroundTransparency = 0.3
    rightPanel.BorderSizePixel = 0
    rightPanel.Parent = gameBody

    local rightStroke = Instance.new("Frame")
    rightStroke.Size = UDim2.new(0, 1, 1, 0)
    rightStroke.Position = UDim2.new(0, 0, 0, 0)
    rightStroke.BackgroundColor3 = C.GlassBorder
    rightStroke.BackgroundTransparency = 0.5
    rightStroke.BorderSizePixel = 0
    rightStroke.Parent = rightPanel

    -- Opponent HUD section
    local oppHudSection = Instance.new("Frame")
    oppHudSection.Size = UDim2.new(1, 0, 0, 100)
    oppHudSection.BackgroundTransparency = 1
    oppHudSection.Parent = rightPanel
    createUIPadding(oppHudSection, 14, 14, 14, 14)

    createMonoLabel(oppHudSection, "OPPONENT", UDim2.new(1, 0, 0, 12), UDim2.new(0, 0, 0, 0), Color3.fromRGB(64, 64, 64), 9)

    local oppHud = createGlassFrame(oppHudSection, UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0, 18))
    oppHud.BackgroundColor3 = C.Player2Dim
    createUIStroke(oppHud, C.Player2Border, 1)
    createUIPadding(oppHud, 10, 10, 12, 12)

    local oppDot = Instance.new("Frame")
    oppDot.Size = UDim2.new(0, 6, 0, 6)
    oppDot.Position = UDim2.new(0, 0, 0, 3)
    oppDot.BackgroundColor3 = C.Player2
    oppDot.BorderSizePixel = 0
    oppDot.Parent = oppHud
    createUICorner(oppDot, 3)

    local oppNameLabel = createLabel(oppHud, "Opponent", UDim2.new(1, -14, 0, 16), UDim2.new(0, 14, 0, 0), C.White, 12, Enum.Font.GothamBold)
    UI.oppNameLabel = oppNameLabel

    createMonoLabel(oppHud, "King", UDim2.new(0, 30, 0, 12), UDim2.new(0, 0, 0, 22), C.WhiteDimmer, 9)
    local oppKingBarBg = Instance.new("Frame")
    oppKingBarBg.Size = UDim2.new(1, -70, 0, 3)
    oppKingBarBg.Position = UDim2.new(0, 35, 0, 28)
    oppKingBarBg.BackgroundColor3 = C.WhiteDimmest
    oppKingBarBg.BorderSizePixel = 0
    oppKingBarBg.Parent = oppHud
    createUICorner(oppKingBarBg, 2)

    local oppKingBar = Instance.new("Frame")
    oppKingBar.Size = UDim2.new(1, 0, 1, 0)
    oppKingBar.BackgroundColor3 = C.Player2
    oppKingBar.BorderSizePixel = 0
    oppKingBar.Parent = oppKingBarBg
    createUICorner(oppKingBar, 2)
    UI.oppKingBar = oppKingBar

    local oppKingVal = createMonoLabel(oppHud, "100", UDim2.new(0, 30, 0, 12), UDim2.new(1, -30, 0, 22), C.WhiteDim, 9)
    oppKingVal.TextXAlignment = Enum.TextXAlignment.Right
    UI.oppKingVal = oppKingVal

    -- Unit detail section (scrollable)
    local detailScroll = Instance.new("ScrollingFrame")
    detailScroll.Size = UDim2.new(1, 0, 1, -106)
    detailScroll.Position = UDim2.new(0, 0, 0, 106)
    detailScroll.BackgroundTransparency = 1
    detailScroll.ScrollBarThickness = 3
    detailScroll.ScrollBarImageColor3 = C.WhiteDimmest
    detailScroll.CanvasSize = UDim2.new(0, 0, 0, 400)
    detailScroll.BorderSizePixel = 0
    detailScroll.Parent = rightPanel
    createUIPadding(detailScroll, 10, 10, 14, 14)
    UI.detailScroll = detailScroll

    local detailPlaceholder = createMonoLabel(detailScroll, "Click a unit", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 24), Color3.fromRGB(46, 46, 46), 11)
    detailPlaceholder.TextXAlignment = Enum.TextXAlignment.Center
    UI.detailPlaceholder = detailPlaceholder

    -- Action buttons (hidden by default)
    local actionFrame = Instance.new("Frame")
    actionFrame.Name = "ActionFrame"
    actionFrame.Size = UDim2.new(1, 0, 0, 120)
    actionFrame.Position = UDim2.new(0, 0, 0, 260)
    actionFrame.BackgroundTransparency = 1
    actionFrame.Visible = false
    actionFrame.Parent = detailScroll

    local actionLayout = Instance.new("UIListLayout")
    actionLayout.Padding = UDim.new(0, 5)
    actionLayout.Parent = actionFrame

    local moveBtn = createButton(actionFrame, "Move", UDim2.new(1, 0, 0, 32), nil, C.Glass, C.Player1, function()
        startInteractionMode("move")
    end)
    moveBtn.BackgroundTransparency = 0.3
    createUIStroke(moveBtn, C.Player1Border, 1)
    moveBtn.LayoutOrder = 1
    UI.moveBtn = moveBtn

    local attackBtn = createButton(actionFrame, "Attack", UDim2.new(1, 0, 0, 32), nil, C.Glass, C.Danger, function()
        startInteractionMode("attack")
    end)
    attackBtn.BackgroundTransparency = 0.3
    createUIStroke(attackBtn, Color3.fromRGB(100, 45, 45), 1)
    attackBtn.LayoutOrder = 2
    UI.attackBtn = attackBtn

    local abilityBtn = createButton(actionFrame, "Use ability", UDim2.new(1, 0, 0, 32), nil, C.Glass, C.Gold, function()
        if selectedUnitId and gameState then
            Remotes.UseAbility:FireServer(selectedUnitId)
        end
    end)
    abilityBtn.BackgroundTransparency = 0.3
    createUIStroke(abilityBtn, Color3.fromRGB(100, 76, 14), 1)
    abilityBtn.LayoutOrder = 3
    abilityBtn.Visible = false
    UI.abilityBtn = abilityBtn

    UI.actionFrame = actionFrame

    -- LOG BAR (bottom)
    local logBar = Instance.new("Frame")
    logBar.Size = UDim2.new(1, 0, 0, 34)
    logBar.Position = UDim2.new(0, 0, 1, -34)
    logBar.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
    logBar.BackgroundTransparency = 0.08
    logBar.BorderSizePixel = 0
    logBar.Parent = gameScreen

    local logStroke = Instance.new("Frame")
    logStroke.Size = UDim2.new(1, 0, 0, 1)
    logStroke.Position = UDim2.new(0, 0, 0, 0)
    logStroke.BackgroundColor3 = C.GlassBorder
    logStroke.BackgroundTransparency = 0.5
    logStroke.BorderSizePixel = 0
    logStroke.Parent = logBar

    local logLabel = createMonoLabel(logBar, "Welcome to War of Jonk", UDim2.new(1, -32, 1, 0), UDim2.new(0, 16, 0, 0), C.WhiteDim, 11)
    logLabel.TextYAlignment = Enum.TextYAlignment.Center
    logLabel.TextTruncate = Enum.TextTruncate.AtEnd
    UI.logLabel = logLabel
end

------------------------------------------------------
-- WIN MODAL
------------------------------------------------------
local function buildWinModal()
    local backdrop = Instance.new("Frame")
    backdrop.Name = "WinModal"
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.25
    backdrop.BorderSizePixel = 0
    backdrop.Visible = false
    backdrop.ZIndex = 100
    backdrop.Parent = screenGui
    UI.winModal = backdrop

    local modal = Instance.new("Frame")
    modal.Size = UDim2.new(0, 380, 0, 320)
    modal.Position = UDim2.new(0.5, 0, 0.5, 0)
    modal.AnchorPoint = Vector2.new(0.5, 0.5)
    modal.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
    modal.BackgroundTransparency = 0.02
    modal.BorderSizePixel = 0
    modal.ZIndex = 101
    modal.Parent = backdrop
    createUICorner(modal, 18)
    createUIStroke(modal, C.GlassBorder, 1)
    createUIPadding(modal, 36, 36, 44, 44)

    local winTitle = createLabel(modal, "Victory!", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), C.White, 32, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
    UI.winTitle = winTitle

    local winSub = createLabel(modal, "The enemy King has fallen.", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 44), C.WhiteDim, 14, Enum.Font.Gotham, Enum.TextXAlignment.Center)
    UI.winSub = winSub

    -- Stats row
    local statsRow = Instance.new("Frame")
    statsRow.Size = UDim2.new(1, 0, 0, 60)
    statsRow.Position = UDim2.new(0, 0, 0, 80)
    statsRow.BackgroundTransparency = 1
    statsRow.Parent = modal

    local statsLayout = Instance.new("UIListLayout")
    statsLayout.FillDirection = Enum.FillDirection.Horizontal
    statsLayout.Padding = UDim.new(0, 8)
    statsLayout.Parent = statsRow

    local function addStat(name, defaultVal)
        local statFrame = Instance.new("Frame")
        statFrame.Size = UDim2.new(0.32, 0, 1, 0)
        statFrame.BackgroundColor3 = C.Glass
        statFrame.BackgroundTransparency = 0.3
        statFrame.Parent = statsRow
        createUICorner(statFrame, 8)

        local val = createLabel(statFrame, tostring(defaultVal), UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 8), C.White, 20, Enum.Font.RobotoMono, Enum.TextXAlignment.Center)
        local lbl = createMonoLabel(statFrame, name, UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 36), C.WhiteDimmer, 10)
        lbl.TextXAlignment = Enum.TextXAlignment.Center

        return val
    end

    UI.winKills = addStat("Kills", 0)
    UI.winTurns = addStat("Turns", 0)
    UI.winGold = addStat("Gold", 0)

    -- Buttons
    local playAgainBtn = createButton(modal, "Play again", UDim2.new(1, 0, 0, 38), UDim2.new(0, 0, 0, 160), C.White, C.Background, function()
        UI.winModal.Visible = false
        gameState = nil
        currentGameId = nil
        clearBoard()
        showScreen("home")
    end)

    local homeBtn = createButton(modal, "Home", UDim2.new(1, 0, 0, 38), UDim2.new(0, 0, 0, 206), C.Glass, C.White, function()
        UI.winModal.Visible = false
        gameState = nil
        currentGameId = nil
        clearBoard()
        showScreen("home")
    end)
    homeBtn.BackgroundTransparency = 0.3
    createUIStroke(homeBtn, C.GlassBorder, 1)
end

------------------------------------------------------
-- TOAST
------------------------------------------------------
local toastLabel = Instance.new("TextLabel")
toastLabel.Name = "Toast"
toastLabel.Size = UDim2.new(0, 300, 0, 36)
toastLabel.Position = UDim2.new(0.5, -150, 1, -60)
toastLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
toastLabel.BackgroundTransparency = 0.03
toastLabel.Text = ""
toastLabel.TextColor3 = C.White
toastLabel.Font = Enum.Font.RobotoMono
toastLabel.TextSize = 12
toastLabel.Visible = false
toastLabel.ZIndex = 200
toastLabel.Parent = screenGui
createUICorner(toastLabel, 10)
createUIStroke(toastLabel, C.GlassBorder, 1)

local function showToast(msg, toastType)
    toastLabel.Text = msg
    if toastType == "warn" then
        toastLabel.TextColor3 = C.Warning
    elseif toastType == "good" then
        toastLabel.TextColor3 = C.Success
    elseif toastType == "bad" then
        toastLabel.TextColor3 = C.Danger
    else
        toastLabel.TextColor3 = C.White
    end
    toastLabel.Visible = true
    task.delay(2.6, function()
        toastLabel.Visible = false
    end)
end

------------------------------------------------------
-- BOARD RENDERING (2D tile grid using Frames)
------------------------------------------------------
local tileFrames = {}  -- [row][col] = {bg, unitIcon, hpBar, highlight}
local TILE_PX = 44

function clearBoard()
    for _, child in ipairs(UI.boardFrame:GetChildren()) do
        child:Destroy()
    end
    tileFrames = {}
end

function buildGameBoard()
    if not gameState then return end
    clearBoard()

    local mapKey = gameState.mapKey or "grasslands"
    local mapDef = MapDefs.Maps[mapKey]
    if not mapDef then return end

    local totalW = mapDef.cols * TILE_PX
    local totalH = mapDef.rows * TILE_PX

    UI.boardFrame.Size = UDim2.new(0, totalW, 0, totalH)
    -- Center the board
    local wrapW = UI.canvasWrap.AbsoluteSize.X
    local wrapH = UI.canvasWrap.AbsoluteSize.Y
    local offX = math.max(0, math.floor((wrapW - totalW) / 2))
    local offY = math.max(0, math.floor((wrapH - totalH) / 2))
    UI.boardFrame.Position = UDim2.new(0, offX, 0, offY)

    for r = 0, mapDef.rows - 1 do
        tileFrames[r] = {}
        for c = 0, mapDef.cols - 1 do
            local isRiver = MapDefs.isRiver(mapKey, c)
            local isP1Side = c < (mapDef.riverCols[1] or 0)

            local tile = Instance.new("TextButton")
            tile.Size = UDim2.new(0, TILE_PX, 0, TILE_PX)
            tile.Position = UDim2.new(0, c * TILE_PX, 0, r * TILE_PX)
            tile.Text = ""
            tile.AutoButtonColor = false
            tile.BorderSizePixel = 0
            tile.Parent = UI.boardFrame

            if isRiver then
                tile.BackgroundColor3 = mapDef.theme.river
            elseif (r + c) % 2 == 0 then
                tile.BackgroundColor3 = mapDef.theme.land1
            else
                tile.BackgroundColor3 = mapDef.theme.land2
            end

            -- Grid lines
            local gridStroke = createUIStroke(tile, isRiver and mapDef.theme.riverBorder or mapDef.theme.grid, 0.5)
            gridStroke.Transparency = isRiver and 0.6 or 0.8

            -- Highlight overlay (invisible by default)
            local highlight = Instance.new("Frame")
            highlight.Size = UDim2.new(1, 0, 1, 0)
            highlight.BackgroundColor3 = C.Player1
            highlight.BackgroundTransparency = 1
            highlight.BorderSizePixel = 0
            highlight.ZIndex = 2
            highlight.Parent = tile

            -- Unit icon
            local unitIcon = Instance.new("TextLabel")
            unitIcon.Size = UDim2.new(1, 0, 0.7, 0)
            unitIcon.Position = UDim2.new(0, 0, 0, 0)
            unitIcon.BackgroundTransparency = 1
            unitIcon.Text = ""
            unitIcon.TextColor3 = C.White
            unitIcon.Font = Enum.Font.GothamBold
            unitIcon.TextSize = math.floor(TILE_PX * 0.4)
            unitIcon.ZIndex = 5
            unitIcon.Parent = tile

            -- HP bar background
            local hpBarBg = Instance.new("Frame")
            hpBarBg.Size = UDim2.new(0.72, 0, 0, 3)
            hpBarBg.Position = UDim2.new(0.14, 0, 1, -6)
            hpBarBg.BackgroundColor3 = C.WhiteDimmest
            hpBarBg.BorderSizePixel = 0
            hpBarBg.Visible = false
            hpBarBg.ZIndex = 5
            hpBarBg.Parent = tile
            createUICorner(hpBarBg, 1)

            local hpBarFill = Instance.new("Frame")
            hpBarFill.Size = UDim2.new(1, 0, 1, 0)
            hpBarFill.BackgroundColor3 = C.HealthHigh
            hpBarFill.BorderSizePixel = 0
            hpBarFill.ZIndex = 6
            hpBarFill.Parent = hpBarBg
            createUICorner(hpBarFill, 1)

            -- Selection ring (invisible by default)
            local selRing = Instance.new("Frame")
            selRing.Size = UDim2.new(0.7, 0, 0.7, 0)
            selRing.Position = UDim2.new(0.15, 0, 0.05, 0)
            selRing.BackgroundTransparency = 1
            selRing.BorderSizePixel = 0
            selRing.ZIndex = 4
            selRing.Visible = false
            selRing.Parent = tile
            createUICorner(selRing, TILE_PX)
            local selStroke = createUIStroke(selRing, C.Player1, 2)

            -- Click handler
            local row, col = r, c
            tile.MouseButton1Click:Connect(function()
                handleCellClick(row, col)
            end)

            tileFrames[r][c] = {
                bg = tile,
                unitIcon = unitIcon,
                hpBarBg = hpBarBg,
                hpBarFill = hpBarFill,
                highlight = highlight,
                selRing = selRing,
                selStroke = selStroke,
            }
        end
    end
end

------------------------------------------------------
-- RENDER BOARD STATE
------------------------------------------------------
function renderBoard()
    if not gameState or not tileFrames[0] then return end

    local mapKey = gameState.mapKey or "grasslands"
    local mapDef = MapDefs.Maps[mapKey]
    if not mapDef then return end

    -- Clear all tiles
    for r = 0, mapDef.rows - 1 do
        for c = 0, mapDef.cols - 1 do
            local tf = tileFrames[r] and tileFrames[r][c]
            if tf then
                tf.unitIcon.Text = ""
                tf.hpBarBg.Visible = false
                tf.selRing.Visible = false
                tf.highlight.BackgroundTransparency = 1
            end
        end
    end

    -- Draw highlights
    for _, h in ipairs(highlights) do
        local tf = tileFrames[h.row] and tileFrames[h.row][h.col]
        if tf then
            if h.type == "move" then
                tf.highlight.BackgroundColor3 = C.Player1
                tf.highlight.BackgroundTransparency = 0.75
            elseif h.type == "attack" then
                tf.highlight.BackgroundColor3 = C.Danger
                tf.highlight.BackgroundTransparency = 0.75
            elseif h.type == "deploy" then
                tf.highlight.BackgroundColor3 = C.Gold
                tf.highlight.BackgroundTransparency = 0.8
            end
        end
    end

    -- Draw units
    if gameState.units then
        for uid, u in pairs(gameState.units) do
            if not u.dead then
                local def = UnitDefs.Types[u.type]
                if def then
                    local tf = tileFrames[u.row] and tileFrames[u.row][u.col]
                    if tf then
                        local isMe = (u.owner == myId)
                        tf.unitIcon.Text = def.emoji or def.name:sub(1, 2)
                        tf.unitIcon.TextColor3 = isMe and C.Player1 or C.Player2

                        -- HP bar
                        tf.hpBarBg.Visible = true
                        local pct = u.hp / def.maxHp
                        tf.hpBarFill.Size = UDim2.new(math.max(0, pct), 0, 1, 0)
                        if pct > 0.6 then
                            tf.hpBarFill.BackgroundColor3 = C.HealthHigh
                        elseif pct > 0.3 then
                            tf.hpBarFill.BackgroundColor3 = C.HealthMid
                        else
                            tf.hpBarFill.BackgroundColor3 = C.HealthLow
                        end

                        -- Selection ring
                        if uid == selectedUnitId then
                            tf.selRing.Visible = true
                            tf.selStroke.Color = isMe and C.Player1 or C.Player2
                        end
                    end
                end
            end
        end
    end

    -- Draw traps (only your own)
    if gameState.traps then
        for _, trap in pairs(gameState.traps) do
            if trap.owner == myId then
                local tf = tileFrames[trap.row] and tileFrames[trap.row][trap.col]
                if tf then
                    tf.highlight.BackgroundColor3 = C.Gold
                    tf.highlight.BackgroundTransparency = 0.8
                end
            end
        end
    end
end

------------------------------------------------------
-- DEPLOY ROSTER
------------------------------------------------------
function buildDeployRoster()
    if not gameState or not UI.deployScroll then return end

    -- Clear existing
    for _, child in ipairs(UI.deployScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    local myGold = 0
    if gameState.players and gameState.players[myId] then
        myGold = gameState.players[myId].gold or 0
    end

    local allDeploy = {}
    for _, t in ipairs(UnitDefs.InfantryOrder) do
        if UnitDefs.Types[t].deployable then table.insert(allDeploy, t) end
    end
    for _, t in ipairs(UnitDefs.NavalOrder) do
        if UnitDefs.Types[t].deployable then table.insert(allDeploy, t) end
    end

    for i, unitType in ipairs(allDeploy) do
        local def = UnitDefs.Types[unitType]
        local canAfford = myGold >= def.cost

        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, 0, 0, 44)
        item.BackgroundColor3 = C.Glass
        item.BackgroundTransparency = canAfford and 0.3 or 0.7
        item.LayoutOrder = i
        item.Parent = UI.deployScroll
        createUICorner(item, 8)
        createUIStroke(item, C.GlassBorder, 0.5)

        local icon = createLabel(item, def.emoji or "?", UDim2.new(0, 30, 1, 0), UDim2.new(0, 8, 0, 0), C.White, 18, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
        icon.TextYAlignment = Enum.TextYAlignment.Center
        icon.TextTransparency = canAfford and 0 or 0.5

        local nameL = createLabel(item, def.name, UDim2.new(0.5, 0, 0, 14), UDim2.new(0, 42, 0, 6), C.White, 11, Enum.Font.GothamBold)
        nameL.TextTransparency = canAfford and 0 or 0.5

        local costL = createMonoLabel(item, "@ " .. def.cost, UDim2.new(0.4, 0, 0, 12), UDim2.new(0, 42, 0, 22), C.Gold, 9)
        costL.TextTransparency = canAfford and 0 or 0.5

        if canAfford then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 1, 0)
            btn.BackgroundTransparency = 1
            btn.Text = ""
            btn.Parent = item
            btn.MouseButton1Click:Connect(function()
                selectDeploy(unitType)
            end)
        end
    end
end

------------------------------------------------------
-- INTERACTION LOGIC
------------------------------------------------------
function clearSelection()
    selectedUnitId = nil
    interactionMode = "idle"
    deployType = nil
    highlights = {}
    if UI.actionFrame then UI.actionFrame.Visible = false end
    if UI.detailPlaceholder then UI.detailPlaceholder.Visible = true end
    renderBoard()
end

function selectUnit(uid)
    if not gameState or not gameState.units then return end
    local u = gameState.units[uid]
    if not u then return end
    local def = UnitDefs.Types[u.type]
    if not def then return end

    selectedUnitId = uid
    interactionMode = "idle"
    highlights = {}

    local isMe = (u.owner == myId)
    local isMyTurn = (gameState.currentTurn == myId)

    -- Update detail panel
    if UI.detailPlaceholder then UI.detailPlaceholder.Visible = false end

    -- Clear old detail content (except placeholder and action frame)
    for _, child in ipairs(UI.detailScroll:GetChildren()) do
        if child.Name ~= "ActionFrame" and child ~= UI.detailPlaceholder and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end

    -- Unit detail
    local detIcon = createLabel(UI.detailScroll, def.emoji or "?", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), C.White, 32, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    detIcon.Name = "DetailContent"

    local detName = createLabel(UI.detailScroll, def.name, UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 42), C.White, 14, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    detName.Name = "DetailContent"

    local detType = createMonoLabel(UI.detailScroll, string.upper(def.theatre), UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 64), C.WhiteDimmer, 9)
    detType.TextXAlignment = Enum.TextXAlignment.Center
    detType.Name = "DetailContent"

    -- HP bar
    local pct = u.hp / def.maxHp
    local hpColor = pct > 0.6 and C.HealthHigh or (pct > 0.3 and C.HealthMid or C.HealthLow)

    local hpFrame = Instance.new("Frame")
    hpFrame.Name = "DetailContent"
    hpFrame.Size = UDim2.new(1, 0, 0, 20)
    hpFrame.Position = UDim2.new(0, 0, 0, 84)
    hpFrame.BackgroundTransparency = 1
    hpFrame.Parent = UI.detailScroll

    createMonoLabel(hpFrame, "HP", UDim2.new(0, 20, 1, 0), UDim2.new(0, 0, 0, 0), C.WhiteDimmer, 9)
    local val = createMonoLabel(hpFrame, u.hp .. "/" .. def.maxHp, UDim2.new(0, 50, 1, 0), UDim2.new(1, -50, 0, 0), C.WhiteDim, 9)
    val.TextXAlignment = Enum.TextXAlignment.Right

    local hpBg = Instance.new("Frame")
    hpBg.Size = UDim2.new(1, 0, 0, 4)
    hpBg.Position = UDim2.new(0, 0, 0, 106)
    hpBg.BackgroundColor3 = C.WhiteDimmest
    hpBg.BorderSizePixel = 0
    hpBg.Name = "DetailContent"
    hpBg.Parent = UI.detailScroll
    createUICorner(hpBg, 2)

    local hpFill = Instance.new("Frame")
    hpFill.Size = UDim2.new(pct, 0, 1, 0)
    hpFill.BackgroundColor3 = hpColor
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBg
    createUICorner(hpFill, 2)

    -- Stats
    local yOff = 118
    local function addDetStat(lbl, v)
        local sf = Instance.new("Frame")
        sf.Name = "DetailContent"
        sf.Size = UDim2.new(1, 0, 0, 16)
        sf.Position = UDim2.new(0, 0, 0, yOff)
        sf.BackgroundTransparency = 1
        sf.Parent = UI.detailScroll
        createMonoLabel(sf, lbl, UDim2.new(0.5, 0, 1, 0), UDim2.new(0, 0, 0, 0), C.WhiteDimmer, 9)
        local vl = createMonoLabel(sf, tostring(v), UDim2.new(0.5, 0, 1, 0), UDim2.new(0.5, 0, 0, 0), C.WhiteDim, 11)
        vl.TextXAlignment = Enum.TextXAlignment.Right
        yOff = yOff + 18
    end

    addDetStat("ATK", def.atk)
    addDetStat("DEF", def.def)
    addDetStat("Move", def.move)
    addDetStat("Range", def.range)
    addDetStat("Owner", isMe and "You" or "Enemy")

    -- Ability
    if def.ability then
        local abilFrame = Instance.new("Frame")
        abilFrame.Name = "DetailContent"
        abilFrame.Size = UDim2.new(1, 0, 0, 50)
        abilFrame.Position = UDim2.new(0, 0, 0, yOff + 4)
        abilFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
        abilFrame.BackgroundTransparency = 0.3
        abilFrame.Parent = UI.detailScroll
        createUICorner(abilFrame, 8)
        createUIStroke(abilFrame, Color3.fromRGB(24, 24, 24), 0.5)
        createUIPadding(abilFrame, 6, 6, 8, 8)

        createLabel(abilFrame, def.ability, UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 0), C.White, 10, Enum.Font.GothamBold)
        createMonoLabel(abilFrame, def.abilityDesc, UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 14), C.WhiteDim, 9)
        yOff = yOff + 60
    end

    -- Action buttons
    if isMe and isMyTurn then
        UI.actionFrame.Visible = true
        UI.actionFrame.Position = UDim2.new(0, 0, 0, yOff + 8)

        UI.moveBtn.AutoButtonColor = not u.moved
        UI.moveBtn.TextTransparency = u.moved and 0.5 or 0
        UI.moveBtn.BackgroundTransparency = u.moved and 0.7 or 0.3

        UI.attackBtn.AutoButtonColor = not u.attacked
        UI.attackBtn.TextTransparency = u.attacked and 0.5 or 0
        UI.attackBtn.BackgroundTransparency = u.attacked and 0.7 or 0.3

        if def.ability then
            UI.abilityBtn.Visible = true
            UI.abilityBtn.Text = def.ability
            UI.abilityBtn.AutoButtonColor = not u.usedAbility
            UI.abilityBtn.TextTransparency = u.usedAbility and 0.5 or 0
        else
            UI.abilityBtn.Visible = false
        end
    else
        UI.actionFrame.Visible = false
    end

    renderBoard()
end

function startInteractionMode(mode)
    if not selectedUnitId or not gameState then return end
    if gameState.currentTurn ~= myId then return end

    local u = gameState.units[selectedUnitId]
    if not u then return end

    if mode == "move" and u.moved then
        showToast("Already moved this turn", "warn")
        return
    end
    if mode == "attack" and u.attacked then
        showToast("Already attacked this turn", "warn")
        return
    end

    local def = UnitDefs.Types[u.type]
    if not def then return end

    interactionMode = mode
    highlights = {}

    local mapKey = gameState.mapKey or "grasslands"
    local mapDef = MapDefs.Maps[mapKey]
    if not mapDef then return end

    if mode == "move" then
        -- Calculate move range
        local isNaval = def.theatre == "naval"
        for dr = -def.move, def.move do
            for dc = -def.move, def.move do
                if math.abs(dr) + math.abs(dc) <= def.move and (dr ~= 0 or dc ~= 0) then
                    local nr = u.row + dr
                    local nc = u.col + dc
                    if nr >= 0 and nr < mapDef.rows and nc >= 0 and nc < mapDef.cols then
                        local isRiver = MapDefs.isRiver(mapKey, nc)
                        local validTerrain = (isNaval and isRiver) or (not isNaval and not isRiver)
                        if validTerrain then
                            -- Check no unit there
                            local occupied = false
                            for _, ou in pairs(gameState.units) do
                                if not ou.dead and ou.row == nr and ou.col == nc then
                                    occupied = true
                                    break
                                end
                            end
                            if not occupied then
                                table.insert(highlights, {row = nr, col = nc, type = "move"})
                            end
                        end
                    end
                end
            end
        end
        if #highlights == 0 then showToast("No valid move tiles", "warn") end

    elseif mode == "attack" then
        -- Calculate attack range
        for dr = -def.range, def.range do
            for dc = -def.range, def.range do
                if math.abs(dr) + math.abs(dc) <= def.range and (dr ~= 0 or dc ~= 0) then
                    local nr = u.row + dr
                    local nc = u.col + dc
                    if nr >= 0 and nr < mapDef.rows and nc >= 0 and nc < mapDef.cols then
                        for _, eu in pairs(gameState.units) do
                            if eu.owner ~= myId and not eu.dead and eu.row == nr and eu.col == nc then
                                table.insert(highlights, {row = nr, col = nc, type = "attack"})
                            end
                        end
                    end
                end
            end
        end
        if #highlights == 0 then showToast("No enemies in range", "warn") end
    end

    renderBoard()
end

function selectDeploy(unitType)
    if not gameState or gameState.currentTurn ~= myId then
        showToast("Not your turn", "warn")
        return
    end
    local phase = gameState.phase
    if phase ~= GameConfig.Phase.BUILD and phase ~= GameConfig.Phase.DEPLOY then
        showToast("Can't deploy in battle phase", "warn")
        return
    end

    local def = UnitDefs.Types[unitType]
    if not def then return end

    local myGold = gameState.players and gameState.players[myId] and gameState.players[myId].gold or 0
    if myGold < def.cost then
        showToast("Not enough gold!", "warn")
        return
    end

    deployType = unitType
    interactionMode = "deploy"
    selectedUnitId = nil
    highlights = {}

    local mapKey = gameState.mapKey or "grasslands"
    local mapDef = MapDefs.Maps[mapKey]
    if not mapDef then return end

    local isNaval = def.theatre == "naval"
    for r = 0, mapDef.rows - 1 do
        for c = 0, mapDef.cols - 1 do
            local isRiver = MapDefs.isRiver(mapKey, c)
            local isMyZone
            if amHost then
                isMyZone = c < (mapDef.riverCols[1] or 0)
            else
                isMyZone = c > (mapDef.riverCols[#mapDef.riverCols] or 0)
            end

            local validTerrain = (isNaval and isRiver) or (not isNaval and not isRiver)
            if validTerrain and isMyZone then
                local occupied = false
                for _, u in pairs(gameState.units) do
                    if not u.dead and u.row == r and u.col == c then
                        occupied = true
                        break
                    end
                end
                if not occupied then
                    table.insert(highlights, {row = r, col = c, type = "deploy"})
                end
            end
        end
    end

    if #highlights == 0 then
        showToast("No valid deployment tiles", "warn")
        interactionMode = "idle"
        return
    end

    showToast("Click to place " .. def.name)
    renderBoard()
end

function handleCellClick(row, col)
    if not gameState or gameState.currentTurn ~= myId then return end

    -- Deploy mode
    if interactionMode == "deploy" then
        local valid = false
        for _, h in ipairs(highlights) do
            if h.row == row and h.col == col then
                valid = true
                break
            end
        end
        if valid and deployType then
            Remotes.DeployUnit:FireServer(deployType, row, col)
            interactionMode = "idle"
            deployType = nil
            highlights = {}
        else
            clearSelection()
        end
        return
    end

    -- Move mode
    if interactionMode == "move" then
        local valid = false
        for _, h in ipairs(highlights) do
            if h.row == row and h.col == col then
                valid = true
                break
            end
        end
        if valid and selectedUnitId then
            Remotes.MoveUnit:FireServer(selectedUnitId, row, col)
            interactionMode = "idle"
            highlights = {}
        else
            clearSelection()
        end
        return
    end

    -- Attack mode
    if interactionMode == "attack" then
        local valid = false
        for _, h in ipairs(highlights) do
            if h.row == row and h.col == col then
                valid = true
                break
            end
        end
        if valid and selectedUnitId then
            -- Find the unit at clicked cell
            local targetUid = nil
            for uid, u in pairs(gameState.units) do
                if not u.dead and u.row == row and u.col == col then
                    targetUid = uid
                    break
                end
            end
            if targetUid then
                Remotes.AttackUnit:FireServer(selectedUnitId, targetUid)
                interactionMode = "idle"
                highlights = {}
            end
        else
            clearSelection()
        end
        return
    end

    -- Normal click: select unit
    local clickedUid = nil
    if gameState.units then
        for uid, u in pairs(gameState.units) do
            if not u.dead and u.row == row and u.col == col then
                clickedUid = uid
                break
            end
        end
    end

    if clickedUid then
        selectUnit(clickedUid)
    else
        clearSelection()
    end
end

------------------------------------------------------
-- UPDATE GAME UI
------------------------------------------------------
function updateGameUI()
    if not gameState then return end

    local isMyTurn = (gameState.currentTurn == myId)
    local phase = gameState.phase or "build"

    -- Turn indicator
    if UI.turnDot then
        UI.turnDot.BackgroundColor3 = isMyTurn and C.Player1 or C.Player2
    end
    if UI.turnLabel then
        if isMyTurn then
            UI.turnLabel.Text = "Your turn"
        else
            local oppId = nil
            for pid in pairs(gameState.players) do
                if pid ~= myId then oppId = pid; break end
            end
            local oppName = oppId and gameState.players[oppId] and gameState.players[oppId].name or "Opponent"
            if gameState.players[oppId] and gameState.players[oppId].isCPU then
                UI.turnLabel.Text = "CPU's turn"
            else
                UI.turnLabel.Text = oppName .. "'s turn"
            end
        end
    end

    -- Phase pill
    if UI.phasePill then
        local phaseNames = {build = "BUILD PHASE", deploy = "DEPLOY PHASE", turn = "BATTLE PHASE"}
        UI.phasePill.Text = phaseNames[phase] or phase
        if isMyTurn then
            if phase == "build" then
                UI.phasePill.TextColor3 = C.Warning
            elseif phase == "deploy" then
                UI.phasePill.TextColor3 = C.Gold
            else
                UI.phasePill.TextColor3 = C.Player1
            end
        else
            UI.phasePill.TextColor3 = C.WhiteDimmer
        end
    end

    -- End turn button
    if UI.endTurnBtn then
        UI.endTurnBtn.AutoButtonColor = isMyTurn
        UI.endTurnBtn.BackgroundTransparency = isMyTurn and 0 or 0.5
        UI.endTurnBtn.TextTransparency = isMyTurn and 0 or 0.5
    end

    -- Gold
    if UI.myGoldLabel and gameState.players and gameState.players[myId] then
        UI.myGoldLabel.Text = "@ " .. (gameState.players[myId].gold or 0) .. " gold"
    end

    -- Player name
    if UI.myNameLabel then
        UI.myNameLabel.Text = myName
    end

    -- Opponent info
    local oppId = nil
    for pid in pairs(gameState.players) do
        if pid ~= myId then oppId = pid; break end
    end
    if oppId and gameState.players[oppId] then
        if UI.oppNameLabel then
            UI.oppNameLabel.Text = gameState.players[oppId].name or "Opponent"
        end
    end

    -- King HP bars
    if gameState.units then
        for _, u in pairs(gameState.units) do
            if u.type == "king" then
                local pct = math.max(0, u.hp / 100)
                if u.owner == myId then
                    if UI.myKingBar then
                        UI.myKingBar.Size = UDim2.new(pct, 0, 1, 0)
                    end
                    if UI.myKingVal then
                        UI.myKingVal.Text = tostring(u.hp)
                    end
                else
                    if UI.oppKingBar then
                        UI.oppKingBar.Size = UDim2.new(pct, 0, 1, 0)
                    end
                    if UI.oppKingVal then
                        UI.oppKingVal.Text = tostring(u.hp)
                    end
                end
            end
        end
    end

    -- Rebuild deploy roster
    if phase == "build" or phase == "deploy" then
        buildDeployRoster()
    end

    -- Render board
    renderBoard()
end

------------------------------------------------------
-- REMOTE EVENT HANDLERS
------------------------------------------------------
Remotes.GameStateUpdate.OnClientEvent:Connect(function(newState)
    gameState = newState
    if screens.game and not screens.game.Visible then
        showScreen("game")
        buildGameBoard()
    end
    -- Determine if host
    if gameState.players and gameState.players[myId] then
        amHost = gameState.players[myId].isHost or false
    end
    updateGameUI()
end)

Remotes.GameOver.OnClientEvent:Connect(function(won, finalState)
    gameState = finalState
    updateGameUI()

    if UI.winModal then
        UI.winModal.Visible = true
    end
    if UI.winTitle then
        UI.winTitle.Text = won and "Victory!" or "Defeated"
    end
    if UI.winSub then
        UI.winSub.Text = won and "The enemy King has been eliminated!" or "Your King has fallen. Better luck next time."
    end
end)

Remotes.LogMessage.OnClientEvent:Connect(function(msg)
    if UI.logLabel then
        UI.logLabel.Text = msg
    end
end)

Remotes.ToastMessage.OnClientEvent:Connect(function(msg, toastType)
    showToast(msg, toastType)
end)

------------------------------------------------------
-- INIT
------------------------------------------------------
buildHomeScreen()
buildCreateScreen()
buildLobbyScreen()
buildLoadingScreen()
buildGameScreen()
buildWinModal()
showScreen("home")

print("[War of Jonk] Client loaded successfully")
