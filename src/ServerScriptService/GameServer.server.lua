--[[
    GameServer.server.lua
    Main server-side game controller for War of Jonk
    Handles game creation, turn management, combat, abilities, and CPU AI
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UnitDefs = require(Modules:WaitForChild("UnitDefs"))
local MapDefs = require(Modules:WaitForChild("MapDefs"))
local GameConfig = require(Modules:WaitForChild("GameConfig"))

------------------------------------------------------
-- Remote Events / Functions setup
------------------------------------------------------
local RemoteFolder = Instance.new("Folder")
RemoteFolder.Name = "Remotes"
RemoteFolder.Parent = ReplicatedStorage

local Remotes = {}
for _, name in ipairs(GameConfig.Remotes) do
    if name == "CreateGame" or name == "JoinGame" then
        local rf = Instance.new("RemoteFunction")
        rf.Name = name
        rf.Parent = RemoteFolder
        Remotes[name] = rf
    else
        local re = Instance.new("RemoteEvent")
        re.Name = name
        re.Parent = RemoteFolder
        Remotes[name] = re
    end
end

------------------------------------------------------
-- Active games storage
------------------------------------------------------
-- Each game: { id, mapKey, phase, currentTurn, turnNum, players, units, traps, effects, winner }
-- players: { [playerId] = { name, gold, isHost, isCPU } }
local ActiveGames = {}        -- gameId -> game state
local PlayerToGame = {}       -- Player -> gameId

------------------------------------------------------
-- Utility
------------------------------------------------------
local function generateId()
    local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    local code = ""
    for _ = 1, 6 do
        local idx = math.random(1, #chars)
        code = code .. chars:sub(idx, idx)
    end
    return code
end

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = deepCopy(v)
    end
    return copy
end

local function getOtherPlayerId(game, playerId)
    for pid in pairs(game.players) do
        if pid ~= playerId then
            return pid
        end
    end
    return nil
end

local function getUnitAt(game, row, col)
    for uid, u in pairs(game.units) do
        if not u.dead and u.row == row and u.col == col then
            return uid, u
        end
    end
    return nil, nil
end

local function manhattanDist(r1, c1, r2, c2)
    return math.abs(r1 - r2) + math.abs(c1 - c2)
end

local function broadcastState(game)
    for pid in pairs(game.players) do
        if not game.players[pid].isCPU then
            local player = Players:FindFirstChild(tostring(pid))
            if not player then
                -- Try finding by UserId
                for _, p in ipairs(Players:GetPlayers()) do
                    if tostring(p.UserId) == tostring(pid) then
                        player = p
                        break
                    end
                end
            end
            if player then
                Remotes.GameStateUpdate:FireClient(player, game)
            end
        end
    end
end

local function broadcastLog(game, msg)
    for pid in pairs(game.players) do
        if not game.players[pid].isCPU then
            local player
            for _, p in ipairs(Players:GetPlayers()) do
                if tostring(p.UserId) == tostring(pid) then
                    player = p
                    break
                end
            end
            if player then
                Remotes.LogMessage:FireClient(player, msg)
            end
        end
    end
end

local function broadcastToast(game, msg, toastType)
    for pid in pairs(game.players) do
        if not game.players[pid].isCPU then
            local player
            for _, p in ipairs(Players:GetPlayers()) do
                if tostring(p.UserId) == tostring(pid) then
                    player = p
                    break
                end
            end
            if player then
                Remotes.ToastMessage:FireClient(player, msg, toastType or "")
            end
        end
    end
end

local function sendGameOver(game)
    for pid in pairs(game.players) do
        if not game.players[pid].isCPU then
            local player
            for _, p in ipairs(Players:GetPlayers()) do
                if tostring(p.UserId) == tostring(pid) then
                    player = p
                    break
                end
            end
            if player then
                local won = (game.winner == pid)
                Remotes.GameOver:FireClient(player, won, game)
            end
        end
    end
end

------------------------------------------------------
-- Build initial game state
------------------------------------------------------
local function buildInitialGame(mapKey, hostId, guestId)
    local mapDef = MapDefs.Maps[mapKey]
    if not mapDef then mapKey = "grasslands"; mapDef = MapDefs.Maps[mapKey] end

    local kingRow = math.floor(mapDef.rows / 2)
    local maxCol = mapDef.cols - 1

    local game = {
        id = generateId(),
        mapKey = mapKey,
        phase = GameConfig.Phase.BUILD,
        currentTurn = hostId,
        turnNum = 1,
        winner = nil,
        players = {
            [hostId] = {
                name = "Player 1",
                gold = GameConfig.STARTING_GOLD,
                isHost = true,
                isCPU = false,
            },
            [guestId] = {
                name = "Player 2",
                gold = GameConfig.STARTING_GOLD,
                isHost = false,
                isCPU = false,
            },
        },
        units = {
            -- Host king on left side
            king_host = UnitDefs.createUnit("king", hostId, kingRow, 0),
            -- Guest king on right side
            king_guest = UnitDefs.createUnit("king", guestId, kingRow, maxCol),
            -- Host starting guards
            guard_host1 = UnitDefs.createUnit("guard", hostId, 3, 1),
            guard_host2 = UnitDefs.createUnit("guard", hostId, mapDef.rows - 4, 1),
            -- Host starting spears
            spear_host1 = UnitDefs.createUnit("spear", hostId, 2, 3),
            spear_host2 = UnitDefs.createUnit("spear", hostId, mapDef.rows - 3, 3),
            -- Host marine
            marine_host1 = UnitDefs.createUnit("marine", hostId, kingRow, 4),
        },
        traps = {},
        effects = {},
    }

    return game
end

------------------------------------------------------
-- CPU AI
------------------------------------------------------
local function runCPUTurn(game)
    local cpuId = nil
    for pid, pdata in pairs(game.players) do
        if pdata.isCPU then
            cpuId = pid
            break
        end
    end
    if not cpuId then return end

    local humanId = getOtherPlayerId(game, cpuId)
    local mapDef = MapDefs.Maps[game.mapKey]

    -- Phase: Deploy units if in build/deploy phase
    if game.phase == GameConfig.Phase.BUILD or game.phase == GameConfig.Phase.DEPLOY then
        local deployable = {"spear", "guard", "marine", "mole", "commander"}
        local gold = game.players[cpuId].gold
        local attempts = 0
        while gold >= 15 and attempts < 5 do
            attempts = attempts + 1
            local unitType = deployable[math.random(1, #deployable)]
            local def = UnitDefs.Types[unitType]
            if def and gold >= def.cost then
                -- Find a valid deployment tile (right side of map, not river)
                local placed = false
                for try = 1, 20 do
                    local row = math.random(0, mapDef.rows - 1)
                    local col = math.random(MapDefs.getP2MinCol(game.mapKey), mapDef.cols - 1)
                    if not MapDefs.isRiver(game.mapKey, col) and not getUnitAt(game, row, col) then
                        local uid = unitType .. "_cpu_" .. tostring(os.clock()):gsub("%.", "") .. tostring(try)
                        game.units[uid] = UnitDefs.createUnit(unitType, cpuId, row, col)
                        gold = gold - def.cost
                        game.players[cpuId].gold = gold
                        broadcastLog(game, "CPU deployed " .. def.name)
                        placed = true
                        break
                    end
                end
                if not placed then break end
            end
        end
    end

    -- Phase: Battle - move and attack with existing units
    if game.phase == GameConfig.Phase.BATTLE or game.phase == GameConfig.Phase.BUILD or game.phase == GameConfig.Phase.DEPLOY then
        for uid, u in pairs(game.units) do
            if u.owner == cpuId and not u.dead then
                local def = UnitDefs.Types[u.type]
                if def then -- guard clause: skip if no def

                -- Try to attack first
                if not u.attacked and def.atk > 0 then
                    local bestTarget, bestDist = nil, 999
                    for tuid, tu in pairs(game.units) do
                        if tu.owner ~= cpuId and not tu.dead then
                            local dist = manhattanDist(u.row, u.col, tu.row, tu.col)
                            if dist <= def.range and dist < bestDist then
                                bestTarget = tuid
                                bestDist = dist
                            end
                        end
                    end
                    if bestTarget then
                        -- Execute attack
                        local target = game.units[bestTarget]
                        local targetDef = UnitDefs.Types[target.type]

                        -- Guard intercept check
                        local actualTarget = bestTarget
                        if target.type == "king" then
                            for gid, gu in pairs(game.units) do
                                if gu.owner == target.owner and gu.type == "guard" and not gu.dead then
                                    if manhattanDist(gu.row, gu.col, target.row, target.col) <= 1 then
                                        actualTarget = gid
                                        broadcastLog(game, "Guard Jonk intercepts!")
                                        break
                                    end
                                end
                            end
                        end

                        local actualUnit = game.units[actualTarget]
                        local actualDef = UnitDefs.Types[actualUnit.type]
                        local dmg = math.max(1, math.floor(def.atk - actualDef.def * 0.4 + 0.5))
                        actualUnit.hp = math.max(0, actualUnit.hp - dmg)
                        u.attacked = true

                        if actualUnit.hp <= 0 then
                            actualUnit.dead = true
                            broadcastLog(game, "CPU's " .. def.name .. " destroyed " .. actualDef.name .. "!")
                            if actualUnit.type == "king" then
                                game.winner = cpuId
                                broadcastLog(game, "CPU wins! Your King has fallen!")
                                sendGameOver(game)
                                broadcastState(game)
                                return
                            end
                        else
                            broadcastLog(game, "CPU's " .. def.name .. " hit " .. actualDef.name .. " for " .. dmg)
                            -- King aura damage
                            if actualTarget == bestTarget and target.type == "king" then
                                for aid, au in pairs(game.units) do
                                    if au.owner == humanId and au.type ~= "king" and not au.dead then
                                        au.hp = math.max(1, math.floor(au.hp * (1 - GameConfig.KING_AURA_DAMAGE)))
                                    end
                                end
                                broadcastLog(game, "King struck! All troops weakened!")
                            end
                        end
                    end
                end

                -- Try to move toward nearest enemy
                if not u.moved and not u.dead then
                    local bestEnemy, bestEnemyDist = nil, 999
                    for tuid, tu in pairs(game.units) do
                        if tu.owner ~= cpuId and not tu.dead then
                            local dist = manhattanDist(u.row, u.col, tu.row, tu.col)
                            if dist < bestEnemyDist then
                                bestEnemy = tuid
                                bestEnemyDist = dist
                            end
                        end
                    end

                    if bestEnemy then
                        local target = game.units[bestEnemy]
                        local isNaval = def.theatre == "naval"

                        -- Find best move tile (closer to target)
                        local bestTile, bestNewDist = nil, bestEnemyDist
                        for dr = -def.move, def.move do
                            for dc = -def.move, def.move do
                                if math.abs(dr) + math.abs(dc) <= def.move and (dr ~= 0 or dc ~= 0) then
                                    local nr = u.row + dr
                                    local nc = u.col + dc
                                    if nr >= 0 and nr < mapDef.rows and nc >= 0 and nc < mapDef.cols then
                                        local isRiver = MapDefs.isRiver(game.mapKey, nc)
                                        local validTerrain = (isNaval and isRiver) or (not isNaval and not isRiver)
                                        if validTerrain and not getUnitAt(game, nr, nc) then
                                            local newDist = manhattanDist(nr, nc, target.row, target.col)
                                            if newDist < bestNewDist then
                                                bestNewDist = newDist
                                                bestTile = {nr, nc}
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        if bestTile then
                            u.row = bestTile[1]
                            u.col = bestTile[2]
                            u.moved = true
                        end
                    end
                end
                end -- end if def then
            end
        end
    end

    -- End CPU turn: reset flags, advance phase, give gold
    for uid, u in pairs(game.units) do
        if u.owner == cpuId then
            u.moved = false
            u.attacked = false
            u.usedAbility = false
        end
    end

    -- Phase advancement
    if game.phase == GameConfig.Phase.BUILD then
        game.phase = GameConfig.Phase.DEPLOY
    elseif game.phase == GameConfig.Phase.DEPLOY then
        game.phase = GameConfig.Phase.BATTLE
    end

    game.currentTurn = humanId
    game.turnNum = game.turnNum + 1

    -- Give gold on battle phase end
    game.players[cpuId].gold = math.min(GameConfig.MAX_GOLD, game.players[cpuId].gold + GameConfig.GOLD_PER_TURN)

    broadcastLog(game, "CPU ended turn -- your move!")
    broadcastState(game)
end

------------------------------------------------------
-- Create Game (Remote Function)
------------------------------------------------------
Remotes.CreateGame.OnServerInvoke = function(player, playerName, mode)
    local playerId = tostring(player.UserId)

    -- Clean up old game if any
    if PlayerToGame[playerId] then
        ActiveGames[PlayerToGame[playerId]] = nil
        PlayerToGame[playerId] = nil
    end

    local mapKey = "grasslands"

    if mode == "cpu" then
        local cpuId = "cpu_" .. tostring(os.clock()):gsub("%.", "")
        local game = buildInitialGame(mapKey, playerId, cpuId)
        game.players[playerId].name = playerName or "Commander"
        game.players[cpuId].name = "CPU Jonk"
        game.players[cpuId].isCPU = true

        -- Give CPU starting units on the right side
        local mapDef = MapDefs.Maps[mapKey]
        local maxCol = mapDef.cols - 1
        local cpuUnits = {
            cpu_guard1  = UnitDefs.createUnit("guard", cpuId, 3, maxCol - 1),
            cpu_guard2  = UnitDefs.createUnit("guard", cpuId, mapDef.rows - 4, maxCol - 1),
            cpu_spear1  = UnitDefs.createUnit("spear", cpuId, 2, maxCol - 3),
            cpu_spear2  = UnitDefs.createUnit("spear", cpuId, mapDef.rows - 3, maxCol - 3),
            cpu_marine1 = UnitDefs.createUnit("marine", cpuId, math.floor(mapDef.rows / 2), maxCol - 4),
            cpu_mole1   = UnitDefs.createUnit("mole", cpuId, 1, maxCol - 2),
        }
        for k, v in pairs(cpuUnits) do
            game.units[k] = v
        end

        ActiveGames[game.id] = game
        PlayerToGame[playerId] = game.id

        return { success = true, gameId = game.id, game = game }

    elseif mode == "player" then
        local game = buildInitialGame(mapKey, playerId, "__WAITING__")
        game.players[playerId].name = playerName or "Commander"
        game.players["__WAITING__"] = nil -- Remove placeholder
        game.waitingForPlayer = true

        ActiveGames[game.id] = game
        PlayerToGame[playerId] = game.id

        return { success = true, gameId = game.id, roomCode = game.id }
    end

    return { success = false, error = "Invalid mode" }
end

------------------------------------------------------
-- Join Game (Remote Function)
------------------------------------------------------
Remotes.JoinGame.OnServerInvoke = function(player, playerName, roomCode)
    local playerId = tostring(player.UserId)
    roomCode = string.upper(roomCode or "")

    local game = ActiveGames[roomCode]
    if not game then
        return { success = false, error = "Room not found" }
    end
    if not game.waitingForPlayer then
        return { success = false, error = "Room is full or game already started" }
    end

    -- Clean up old game
    if PlayerToGame[playerId] then
        ActiveGames[PlayerToGame[playerId]] = nil
        PlayerToGame[playerId] = nil
    end

    -- Get host id
    local hostId = nil
    for pid, pdata in pairs(game.players) do
        if pdata.isHost then hostId = pid; break end
    end

    -- Add guest player
    game.players[playerId] = {
        name = playerName or "Commander",
        gold = GameConfig.STARTING_GOLD,
        isHost = false,
        isCPU = false,
    }
    game.waitingForPlayer = false
    PlayerToGame[playerId] = game.id

    -- Set up guest king and units on right side
    local mapDef = MapDefs.Maps[game.mapKey]
    local maxCol = mapDef.cols - 1
    local kingRow = math.floor(mapDef.rows / 2)

    game.units.king_guest = UnitDefs.createUnit("king", playerId, kingRow, maxCol)
    game.units.guard_guest1 = UnitDefs.createUnit("guard", playerId, 3, maxCol - 1)
    game.units.guard_guest2 = UnitDefs.createUnit("guard", playerId, mapDef.rows - 4, maxCol - 1)
    game.units.spear_guest1 = UnitDefs.createUnit("spear", playerId, 2, maxCol - 3)
    game.units.spear_guest2 = UnitDefs.createUnit("spear", playerId, mapDef.rows - 3, maxCol - 3)
    game.units.marine_guest1 = UnitDefs.createUnit("marine", playerId, kingRow, maxCol - 4)

    -- Notify host
    broadcastLog(game, playerName .. " has joined the battle!")
    broadcastState(game)

    return { success = true, gameId = game.id, game = game }
end

------------------------------------------------------
-- Deploy Unit
------------------------------------------------------
Remotes.DeployUnit.OnServerEvent:Connect(function(player, unitType, row, col)
    local playerId = tostring(player.UserId)
    local gameId = PlayerToGame[playerId]
    if not gameId then return end
    local game = ActiveGames[gameId]
    if not game or game.winner then return end

    -- Validate turn
    if game.currentTurn ~= playerId then return end
    if game.phase ~= GameConfig.Phase.BUILD and game.phase ~= GameConfig.Phase.DEPLOY then return end

    local def = UnitDefs.Types[unitType]
    if not def or not def.deployable then return end

    local pdata = game.players[playerId]
    if not pdata or pdata.gold < def.cost then return end

    -- Validate position
    local mapDef = MapDefs.Maps[game.mapKey]
    if row < 0 or row >= mapDef.rows or col < 0 or col >= mapDef.cols then return end
    if getUnitAt(game, row, col) then return end

    local isRiver = MapDefs.isRiver(game.mapKey, col)
    local isNaval = def.theatre == "naval"
    if isNaval and not isRiver then return end
    if not isNaval and isRiver then return end

    -- Validate zone (host = left, guest = right)
    local isHost = pdata.isHost
    if isHost then
        if col > MapDefs.getP1MaxCol(game.mapKey) and not isRiver then return end
    else
        if col < MapDefs.getP2MinCol(game.mapKey) and not isRiver then return end
    end

    -- Deploy
    local uid = unitType .. "_" .. playerId .. "_" .. tostring(os.clock()):gsub("%.", "")
    game.units[uid] = UnitDefs.createUnit(unitType, playerId, row, col)
    pdata.gold = pdata.gold - def.cost

    broadcastLog(game, pdata.name .. " deployed " .. def.name)
    broadcastState(game)
end)

------------------------------------------------------
-- Move Unit
------------------------------------------------------
Remotes.MoveUnit.OnServerEvent:Connect(function(player, unitId, toRow, toCol)
    local playerId = tostring(player.UserId)
    local gameId = PlayerToGame[playerId]
    if not gameId then return end
    local game = ActiveGames[gameId]
    if not game or game.winner then return end
    if game.currentTurn ~= playerId then return end

    local unit = game.units[unitId]
    if not unit or unit.dead or unit.owner ~= playerId then return end
    if unit.moved then return end

    local def = UnitDefs.Types[unit.type]
    if not def then return end

    local mapDef = MapDefs.Maps[game.mapKey]
    if toRow < 0 or toRow >= mapDef.rows or toCol < 0 or toCol >= mapDef.cols then return end

    -- Validate distance
    local dist = manhattanDist(unit.row, unit.col, toRow, toCol)
    if dist > def.move or dist == 0 then return end

    -- Validate terrain
    local isRiver = MapDefs.isRiver(game.mapKey, toCol)
    local isNaval = def.theatre == "naval"
    if isNaval and not isRiver then return end
    if not isNaval and isRiver then return end

    -- Check destination is empty
    if getUnitAt(game, toRow, toCol) then return end

    -- Check for traps
    for tid, trap in pairs(game.traps) do
        if trap.row == toRow and trap.col == toCol and trap.owner ~= playerId then
            -- Trigger trap
            local trapDmg = 15
            unit.hp = math.max(0, unit.hp - trapDmg)
            game.traps[tid] = nil
            broadcastLog(game, unit.name .. " triggered a trap! -" .. trapDmg .. " HP")
            if unit.hp <= 0 then
                unit.dead = true
                broadcastLog(game, unit.name .. " was destroyed by a trap!")
                broadcastState(game)
                return
            end
        end
    end

    unit.row = toRow
    unit.col = toCol
    unit.moved = true

    broadcastLog(game, unit.name .. " moved")
    broadcastState(game)
end)

------------------------------------------------------
-- Attack Unit
------------------------------------------------------
Remotes.AttackUnit.OnServerEvent:Connect(function(player, attackerUid, defenderUid)
    local playerId = tostring(player.UserId)
    local gameId = PlayerToGame[playerId]
    if not gameId then return end
    local game = ActiveGames[gameId]
    if not game or game.winner then return end
    if game.currentTurn ~= playerId then return end

    local attacker = game.units[attackerUid]
    local defender = game.units[defenderUid]
    if not attacker or not defender then return end
    if attacker.dead or defender.dead then return end
    if attacker.owner ~= playerId then return end
    if defender.owner == playerId then return end
    if attacker.attacked then return end

    local atkDef = UnitDefs.Types[attacker.type]
    local defDef = UnitDefs.Types[defender.type]
    if not atkDef or not defDef then return end

    -- Validate range
    local dist = manhattanDist(attacker.row, attacker.col, defender.row, defender.col)
    if dist > atkDef.range then return end

    -- Guard intercept
    local actualTargetId = defenderUid
    if defender.type == "king" then
        for gid, gu in pairs(game.units) do
            if gu.owner == defender.owner and gu.type == "guard" and not gu.dead then
                if manhattanDist(gu.row, gu.col, defender.row, defender.col) <= 1 then
                    actualTargetId = gid
                    broadcastLog(game, "Guard Jonk intercepts!")
                    break
                end
            end
        end
    end

    local actualTarget = game.units[actualTargetId]
    local actualTargetDef = UnitDefs.Types[actualTarget.type]

    local dmg = math.max(1, math.floor(atkDef.atk - actualTargetDef.def * 0.4 + 0.5))
    actualTarget.hp = math.max(0, actualTarget.hp - dmg)
    attacker.attacked = true

    if actualTarget.hp <= 0 then
        actualTarget.dead = true
        broadcastLog(game, attacker.name .. " destroyed " .. actualTarget.name .. "!")
        if actualTarget.type == "king" then
            game.winner = playerId
            broadcastLog(game, game.players[playerId].name .. " wins! Enemy King eliminated!")
            sendGameOver(game)
            broadcastState(game)
            return
        end
    else
        broadcastLog(game, attacker.name .. " hit " .. actualTarget.name .. " for " .. dmg .. " dmg")
        -- King aura damage if king was the original target and was actually hit
        if actualTargetId == defenderUid and defender.type == "king" then
            for _, u in pairs(game.units) do
                if u.owner == defender.owner and u.type ~= "king" and not u.dead then
                    u.hp = math.max(1, math.floor(u.hp * (1 - GameConfig.KING_AURA_DAMAGE)))
                end
            end
            broadcastLog(game, "King struck! All troops weakened!")
        end
    end

    broadcastState(game)
end)

------------------------------------------------------
-- Use Ability
------------------------------------------------------
Remotes.UseAbility.OnServerEvent:Connect(function(player, unitId)
    local playerId = tostring(player.UserId)
    local gameId = PlayerToGame[playerId]
    if not gameId then return end
    local game = ActiveGames[gameId]
    if not game or game.winner then return end
    if game.currentTurn ~= playerId then return end

    local unit = game.units[unitId]
    if not unit or unit.dead or unit.owner ~= playerId then return end
    if unit.usedAbility then return end

    local def = UnitDefs.Types[unit.type]
    if not def or not def.ability then return end

    unit.usedAbility = true

    if unit.type == "mole" then
        -- Plant a trap on an adjacent tile
        local mapDef = MapDefs.Maps[game.mapKey]
        local adjacent = {}
        for dr = -1, 1 do
            for dc = -1, 1 do
                if dr ~= 0 or dc ~= 0 then
                    local nr = unit.row + dr
                    local nc = unit.col + dc
                    if nr >= 0 and nr < mapDef.rows and nc >= 0 and nc < mapDef.cols then
                        if not MapDefs.isRiver(game.mapKey, nc) and not getUnitAt(game, nr, nc) then
                            table.insert(adjacent, {nr, nc})
                        end
                    end
                end
            end
        end
        if #adjacent > 0 then
            local spot = adjacent[math.random(1, #adjacent)]
            local trapId = "trap_" .. tostring(os.clock()):gsub("%.", "")
            game.traps[trapId] = {
                row = spot[1],
                col = spot[2],
                owner = playerId,
            }
            broadcastLog(game, "Mole Jonk plants a hidden trap!")
        end

    elseif unit.type == "lawyer" then
        local oppId = getOtherPlayerId(game, playerId)
        if oppId and game.players[oppId] then
            local stolen = math.floor((game.players[oppId].gold or 0) * 0.25)
            game.players[oppId].gold = (game.players[oppId].gold or 0) - stolen
            game.players[playerId].gold = (game.players[playerId].gold or 0) + stolen
            broadcastLog(game, "Lawyer sues! Stole " .. stolen .. " gold!")
        end

    elseif unit.type == "commander" then
        -- Rally: boost nearby infantry ATK (stored as temporary effect)
        local effectId = "rally_" .. tostring(os.clock()):gsub("%.", "")
        game.effects[effectId] = {
            type = "rally",
            row = unit.row,
            col = unit.col,
            owner = playerId,
            turnsLeft = 1,
        }
        broadcastLog(game, "Commander rallies troops! +8 ATK this turn.")

    else
        broadcastLog(game, def.name .. " uses " .. def.ability .. "!")
    end

    broadcastState(game)
end)

------------------------------------------------------
-- End Turn
------------------------------------------------------
Remotes.EndTurn.OnServerEvent:Connect(function(player)
    local playerId = tostring(player.UserId)
    local gameId = PlayerToGame[playerId]
    if not gameId then return end
    local game = ActiveGames[gameId]
    if not game or game.winner then return end
    if game.currentTurn ~= playerId then return end

    -- Reset unit flags for this player
    for _, u in pairs(game.units) do
        if u.owner == playerId then
            u.moved = false
            u.attacked = false
            u.usedAbility = false
        end
    end

    -- Phase advancement
    if game.phase == GameConfig.Phase.BUILD then
        game.phase = GameConfig.Phase.DEPLOY
    elseif game.phase == GameConfig.Phase.DEPLOY then
        game.phase = GameConfig.Phase.BATTLE
    end
    -- Battle phase stays as battle

    -- Switch turn
    local otherId = getOtherPlayerId(game, playerId)
    game.currentTurn = otherId
    game.turnNum = game.turnNum + 1

    -- Gold income
    game.players[playerId].gold = math.min(
        GameConfig.MAX_GOLD,
        (game.players[playerId].gold or 0) + GameConfig.GOLD_PER_TURN
    )

    -- Clean up expired effects
    local toRemove = {}
    for eid, eff in pairs(game.effects) do
        eff.turnsLeft = (eff.turnsLeft or 1) - 1
        if eff.turnsLeft <= 0 then
            table.insert(toRemove, eid)
        end
    end
    for _, eid in ipairs(toRemove) do
        game.effects[eid] = nil
    end

    broadcastLog(game, game.players[playerId].name .. " ended their turn")
    broadcastState(game)

    -- If next player is CPU, run CPU turn after a delay
    if otherId and game.players[otherId] and game.players[otherId].isCPU then
        task.delay(1.5, function()
            if game.winner then return end
            runCPUTurn(game)
        end)
    end
end)

------------------------------------------------------
-- Player disconnection cleanup
------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
    local playerId = tostring(player.UserId)
    local gameId = PlayerToGame[playerId]
    if gameId then
        local game = ActiveGames[gameId]
        if game and not game.winner then
            local otherId = getOtherPlayerId(game, playerId)
            if otherId then
                game.winner = otherId
                broadcastLog(game, game.players[playerId].name .. " disconnected!")
                sendGameOver(game)
                broadcastState(game)
            end
        end
        PlayerToGame[playerId] = nil
    end
end)

print("[War of Jonk] GameServer loaded successfully")
