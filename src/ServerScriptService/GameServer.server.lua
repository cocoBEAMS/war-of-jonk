--[[
    GameServer.server.lua
    Main server-side game controller for War of Jonk
    Handles game creation, turn management, combat, abilities, CPU AI,
    DataStore persistence, missions, shop, and Super King buff
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UnitDefs = require(Modules:WaitForChild("UnitDefs"))
local MapDefs = require(Modules:WaitForChild("MapDefs"))
local GameConfig = require(Modules:WaitForChild("GameConfig"))

------------------------------------------------------
-- DataStore
------------------------------------------------------
local PlayerDataStore = DataStoreService:GetDataStore("WarOfJonk_PlayerData_v1")
local PlayerDataCache = {}

local DEFAULT_PLAYER_DATA = {
    coins = 0,
    gamesPlayed = 0,
    gamesWon = 0,
    gamesLost = 0,
    unitsKilled = 0,
    kingsKilled = 0,
    upgrades = {},
    completedMissions = {},
    hasSuperKing = false,
}

local function loadPlayerData(userId)
    local key = "player_" .. tostring(userId)
    local success, data = pcall(function()
        return PlayerDataStore:GetAsync(key)
    end)
    if success and data then
        for k, v in pairs(DEFAULT_PLAYER_DATA) do
            if data[k] == nil then data[k] = v end
        end
        PlayerDataCache[tostring(userId)] = data
        return data
    else
        local newData = {}
        for k, v in pairs(DEFAULT_PLAYER_DATA) do
            if type(v) == "table" then newData[k] = {} else newData[k] = v end
        end
        PlayerDataCache[tostring(userId)] = newData
        return newData
    end
end

local function savePlayerData(userId)
    local data = PlayerDataCache[tostring(userId)]
    if not data then return end
    local key = "player_" .. tostring(userId)
    pcall(function() PlayerDataStore:SetAsync(key, data) end)
end

local function getPlayerData(userId)
    local id = tostring(userId)
    if PlayerDataCache[id] then return PlayerDataCache[id] end
    return loadPlayerData(userId)
end

local function incrementStat(userId, stat, amount)
    local data = getPlayerData(userId)
    data[stat] = (data[stat] or 0) + (amount or 1)
    for _, mission in ipairs(GameConfig.Missions) do
        if not data.completedMissions[mission.id] then
            if data[mission.stat] and data[mission.stat] >= mission.target then
                data.completedMissions[mission.id] = true
            end
        end
    end
    savePlayerData(userId)
end

------------------------------------------------------
-- Remotes
------------------------------------------------------
local RemoteFolder = Instance.new("Folder")
RemoteFolder.Name = "Remotes"
RemoteFolder.Parent = ReplicatedStorage

local Remotes = {}
local remoteFunctions = { CreateGame = true, JoinGame = true, GetPlayerData = true, UpgradeTroop = true }
for _, name in ipairs(GameConfig.Remotes) do
    if remoteFunctions[name] then
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
-- State
------------------------------------------------------
local ActiveGames = {}
local PlayerToGame = {}

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

local function getOtherPlayerId(gm, playerId)
    for pid in pairs(gm.players) do
        if pid ~= playerId then return pid end
    end
    return nil
end

local function getUnitAt(gm, row, col)
    for uid, u in pairs(gm.units) do
        if not u.dead and u.row == row and u.col == col then return uid, u end
    end
    return nil, nil
end

local function manhattanDist(r1, c1, r2, c2)
    return math.abs(r1 - r2) + math.abs(c1 - c2)
end

local function findPlayerObj(pid)
    for _, p in ipairs(Players:GetPlayers()) do
        if tostring(p.UserId) == tostring(pid) then return p end
    end
    return nil
end

local function broadcastState(gm)
    for pid in pairs(gm.players) do
        if not gm.players[pid].isCPU then
            local player = findPlayerObj(pid)
            if player then Remotes.GameStateUpdate:FireClient(player, gm) end
        end
    end
end

local function broadcastLog(gm, msg)
    for pid in pairs(gm.players) do
        if not gm.players[pid].isCPU then
            local player = findPlayerObj(pid)
            if player then Remotes.LogMessage:FireClient(player, msg) end
        end
    end
end

local function broadcastToast(gm, msg, toastType)
    if not gm then return end
    for pid in pairs(gm.players) do
        if not gm.players[pid].isCPU then
            local player = findPlayerObj(pid)
            if player then Remotes.ToastMessage:FireClient(player, msg, toastType or "") end
        end
    end
end

local function sendGameOver(gm)
    for pid in pairs(gm.players) do
        if not gm.players[pid].isCPU then
            local player = findPlayerObj(pid)
            if player then
                Remotes.GameOver:FireClient(player, gm.winner == pid, gm)
            end
        end
    end
end

local function sendPlayerDataUpdate(player)
    local data = getPlayerData(player.UserId)
    if data then Remotes.PlayerDataUpdate:FireClient(player, data) end
end

------------------------------------------------------
-- Buff calculations
------------------------------------------------------
local function getAtkWithBuffs(gm, unit)
    local def = UnitDefs.Types[unit.type]
    if not def then return 0 end
    local baseAtk = def.atk
    local ownerData = PlayerDataCache[tostring(unit.owner)]
    if ownerData and ownerData.upgrades and ownerData.upgrades[unit.type] then
        local level = ownerData.upgrades[unit.type]
        baseAtk = math.floor(baseAtk * (1 + level * GameConfig.UPGRADE_STAT_BONUS))
    end
    if ownerData and ownerData.hasSuperKing then
        baseAtk = math.floor(baseAtk * (1 + GameConfig.SUPER_KING_BUFF))
    end
    for _, eff in pairs(gm.effects) do
        if eff.type == "rally" and eff.owner == unit.owner then
            if def.theatre == "infantry" and manhattanDist(unit.row, unit.col, eff.row, eff.col) <= 2 then
                baseAtk = baseAtk + 8
            end
        end
    end
    return baseAtk
end

local function isUnitUnlocked(userId, unitType)
    local def = UnitDefs.Types[unitType]
    if not def then return false end
    if not def.locked then return true end
    local data = getPlayerData(userId)
    for _, mission in ipairs(GameConfig.Missions) do
        if mission.reward == unitType and data.completedMissions[mission.id] then return true end
    end
    if unitType == "zumwalt" then
        local parts = { "zumwalt_part1", "zumwalt_part2", "zumwalt_part3" }
        local allDone = true
        for _, pid in ipairs(parts) do
            if not data.completedMissions[pid] then allDone = false; break end
        end
        return allDone
    end
    return false
end

------------------------------------------------------
-- Build initial game
------------------------------------------------------
local function buildInitialGame(mapKey, hostId, guestId)
    local mapDef = MapDefs.Maps[mapKey]
    if not mapDef then mapKey = "grasslands"; mapDef = MapDefs.Maps[mapKey] end
    local kingRow = math.floor(mapDef.rows / 2)
    local maxCol = mapDef.cols - 1
    return {
        id = generateId(), mapKey = mapKey,
        phase = GameConfig.Phase.BUILD, currentTurn = hostId, turnNum = 1, winner = nil,
        players = {
            [hostId] = { name = "Player 1", gold = GameConfig.STARTING_GOLD, isHost = true, isCPU = false },
            [guestId] = { name = "Player 2", gold = GameConfig.STARTING_GOLD, isHost = false, isCPU = false },
        },
        units = {
            king_host = UnitDefs.createUnit("king", hostId, kingRow, 0),
            king_guest = UnitDefs.createUnit("king", guestId, kingRow, maxCol),
            guard_host1 = UnitDefs.createUnit("guard", hostId, 3, 1),
            guard_host2 = UnitDefs.createUnit("guard", hostId, mapDef.rows - 4, 1),
            spear_host1 = UnitDefs.createUnit("spear", hostId, 2, 3),
            spear_host2 = UnitDefs.createUnit("spear", hostId, mapDef.rows - 3, 3),
            marine_host1 = UnitDefs.createUnit("marine", hostId, kingRow, 4),
        },
        traps = {}, effects = {},
    }
end

------------------------------------------------------
-- CPU AI
------------------------------------------------------
local function runCPUTurn(gm)
    local cpuId = nil
    for pid, pd in pairs(gm.players) do if pd.isCPU then cpuId = pid; break end end
    if not cpuId then return end
    local humanId = getOtherPlayerId(gm, cpuId)
    local mapDef = MapDefs.Maps[gm.mapKey]

    -- Deploy
    if gm.phase == GameConfig.Phase.BUILD or gm.phase == GameConfig.Phase.DEPLOY then
        local pool = {"spear","guard","marine","mole","commander"}
        local gold = gm.players[cpuId].gold
        local att = 0
        while gold >= 15 and att < 5 do
            att = att + 1
            local ut = pool[math.random(1,#pool)]
            local d = UnitDefs.Types[ut]
            if d and gold >= d.cost then
                local placed = false
                for _ = 1, 20 do
                    local r = math.random(0, mapDef.rows-1)
                    local c = math.random(MapDefs.getP2MinCol(gm.mapKey), mapDef.cols-1)
                    if not MapDefs.isRiver(gm.mapKey,c) and not getUnitAt(gm,r,c) then
                        local uid = ut.."_cpu_"..tostring(os.clock()):gsub("%.","")..tostring(att)
                        gm.units[uid] = UnitDefs.createUnit(ut, cpuId, r, c)
                        gold = gold - d.cost; gm.players[cpuId].gold = gold
                        broadcastLog(gm, "CPU deployed "..d.name); placed = true; break
                    end
                end
                if not placed then break end
            end
        end
    end

    -- Attack and move
    for uid, u in pairs(gm.units) do
        if u.owner == cpuId and not u.dead then
            local d = UnitDefs.Types[u.type]
            if d then
                if not u.attacked and d.atk > 0 then
                    local bt, bd = nil, 999
                    for tid, tu in pairs(gm.units) do
                        if tu.owner ~= cpuId and not tu.dead then
                            local dist = manhattanDist(u.row,u.col,tu.row,tu.col)
                            if dist <= d.range and dist < bd then bt = tid; bd = dist end
                        end
                    end
                    if bt then
                        local tgt = gm.units[bt]; local at = bt
                        if tgt.type == "king" then
                            for gid, gu in pairs(gm.units) do
                                if gu.owner == tgt.owner and gu.type == "guard" and not gu.dead then
                                    if manhattanDist(gu.row,gu.col,tgt.row,tgt.col) <= 1 then
                                        at = gid; broadcastLog(gm,"Guard Jonk intercepts!"); break
                                    end
                                end
                            end
                        end
                        local au = gm.units[at]; local ad = UnitDefs.Types[au.type]
                        local ap = getAtkWithBuffs(gm, u)
                        local dmg = math.max(1, math.floor(ap - ad.def*0.4 + 0.5))
                        au.hp = math.max(0, au.hp - dmg); u.attacked = true
                        if au.hp <= 0 then
                            au.dead = true
                            broadcastLog(gm, "CPU "..d.name.." destroyed "..ad.name.."!")
                            if au.type == "king" then
                                gm.winner = cpuId
                                if humanId then incrementStat(humanId,"gamesLost",1) end
                                broadcastLog(gm,"CPU wins! Your King has fallen!")
                                sendGameOver(gm); broadcastState(gm); return
                            end
                        else
                            broadcastLog(gm, "CPU "..d.name.." hit "..ad.name.." for "..dmg)
                            if at == bt and tgt.type == "king" then
                                for _, xu in pairs(gm.units) do
                                    if xu.owner == humanId and xu.type ~= "king" and not xu.dead then
                                        xu.hp = math.max(1, math.floor(xu.hp*(1-GameConfig.KING_AURA_DAMAGE)))
                                    end
                                end
                                broadcastLog(gm,"King struck! All troops weakened!")
                            end
                        end
                    end
                end
                if not u.moved and not u.dead then
                    local be, bed = nil, 999
                    for _, tu in pairs(gm.units) do
                        if tu.owner ~= cpuId and not tu.dead then
                            local dist = manhattanDist(u.row,u.col,tu.row,tu.col)
                            if dist < bed then be = tu; bed = dist end
                        end
                    end
                    if be then
                        local isN = d.theatre == "naval"
                        local bestT, bestD = nil, bed
                        for dr = -d.move, d.move do
                            for dc = -d.move, d.move do
                                if math.abs(dr)+math.abs(dc) <= d.move and (dr~=0 or dc~=0) then
                                    local nr, nc = u.row+dr, u.col+dc
                                    if nr>=0 and nr<mapDef.rows and nc>=0 and nc<mapDef.cols then
                                        local ir = MapDefs.isRiver(gm.mapKey,nc)
                                        if (isN and ir) or (not isN and not ir) then
                                            if not getUnitAt(gm,nr,nc) then
                                                local nd = manhattanDist(nr,nc,be.row,be.col)
                                                if nd < bestD then bestD = nd; bestT = {nr,nc} end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        if bestT then u.row = bestT[1]; u.col = bestT[2]; u.moved = true end
                    end
                end
            end
        end
    end

    for _, u in pairs(gm.units) do
        if u.owner == cpuId then u.moved = false; u.attacked = false; u.usedAbility = false end
    end
    if gm.phase == GameConfig.Phase.BUILD then gm.phase = GameConfig.Phase.DEPLOY
    elseif gm.phase == GameConfig.Phase.DEPLOY then gm.phase = GameConfig.Phase.BATTLE end
    gm.currentTurn = humanId; gm.turnNum = gm.turnNum + 1
    gm.players[cpuId].gold = math.min(GameConfig.MAX_GOLD, gm.players[cpuId].gold + GameConfig.GOLD_PER_TURN)
    broadcastLog(gm,"CPU ended turn -- your move!"); broadcastState(gm)
end

------------------------------------------------------
-- GetPlayerData
------------------------------------------------------
Remotes.GetPlayerData.OnServerInvoke = function(player)
    local data = getPlayerData(player.UserId)
    local gpId = GameConfig.Shop.SuperKingGamePassId
    if gpId and gpId > 0 then
        local owns = false
        pcall(function() owns = MarketplaceService:UserOwnsGamePassAsync(player.UserId, gpId) end)
        data.hasSuperKing = owns
    end
    return data
end

------------------------------------------------------
-- UpgradeTroop
------------------------------------------------------
Remotes.UpgradeTroop.OnServerInvoke = function(player, unitType)
    local data = getPlayerData(player.UserId)
    local def = UnitDefs.Types[unitType]
    if not def then return {success=false, error="Invalid unit"} end
    if unitType == "king" then return {success=false, error="Cannot upgrade King"} end
    local lvl = (data.upgrades[unitType] or 0)
    if lvl >= GameConfig.MAX_UPGRADE_LEVEL then return {success=false, error="Max level"} end
    local cost = GameConfig.UpgradeCost[lvl+1]
    if not cost then return {success=false, error="Invalid level"} end
    if data.coins < cost then return {success=false, error="Not enough coins"} end
    data.coins = data.coins - cost
    data.upgrades[unitType] = lvl + 1
    savePlayerData(player.UserId)
    sendPlayerDataUpdate(player)
    return {success=true, newLevel=lvl+1, newCoins=data.coins}
end

------------------------------------------------------
-- CreateGame
------------------------------------------------------
Remotes.CreateGame.OnServerInvoke = function(player, playerName, mode)
    local playerId = tostring(player.UserId)
    getPlayerData(player.UserId)
    incrementStat(player.UserId, "gamesPlayed", 1)
    sendPlayerDataUpdate(player)

    if PlayerToGame[playerId] then
        ActiveGames[PlayerToGame[playerId]] = nil; PlayerToGame[playerId] = nil
    end
    local mapKey = "grasslands"

    if mode == "cpu" then
        local cpuId = "cpu_"..tostring(os.clock()):gsub("%.","")
        local gm = buildInitialGame(mapKey, playerId, cpuId)
        gm.players[playerId].name = playerName or "Commander"
        gm.players[cpuId].name = "CPU Jonk"; gm.players[cpuId].isCPU = true
        local md = MapDefs.Maps[mapKey]; local mc = md.cols - 1
        local cu = {
            cpu_guard1 = UnitDefs.createUnit("guard",cpuId,3,mc-1),
            cpu_guard2 = UnitDefs.createUnit("guard",cpuId,md.rows-4,mc-1),
            cpu_spear1 = UnitDefs.createUnit("spear",cpuId,2,mc-3),
            cpu_spear2 = UnitDefs.createUnit("spear",cpuId,md.rows-3,mc-3),
            cpu_marine1 = UnitDefs.createUnit("marine",cpuId,math.floor(md.rows/2),mc-4),
            cpu_mole1 = UnitDefs.createUnit("mole",cpuId,1,mc-2),
        }
        for k,v in pairs(cu) do gm.units[k] = v end
        ActiveGames[gm.id] = gm; PlayerToGame[playerId] = gm.id
        return {success=true, gameId=gm.id, game=gm}
    elseif mode == "player" then
        local gm = buildInitialGame(mapKey, playerId, "__WAITING__")
        gm.players[playerId].name = playerName or "Commander"
        gm.players["__WAITING__"] = nil; gm.waitingForPlayer = true
        ActiveGames[gm.id] = gm; PlayerToGame[playerId] = gm.id
        return {success=true, gameId=gm.id, roomCode=gm.id}
    end
    return {success=false, error="Invalid mode"}
end

------------------------------------------------------
-- JoinGame
------------------------------------------------------
Remotes.JoinGame.OnServerInvoke = function(player, playerName, roomCode)
    local playerId = tostring(player.UserId)
    roomCode = string.upper(roomCode or "")
    getPlayerData(player.UserId)
    incrementStat(player.UserId, "gamesPlayed", 1)
    sendPlayerDataUpdate(player)
    local gm = ActiveGames[roomCode]
    if not gm then return {success=false, error="Room not found"} end
    if not gm.waitingForPlayer then return {success=false, error="Room is full"} end
    if PlayerToGame[playerId] then
        ActiveGames[PlayerToGame[playerId]] = nil; PlayerToGame[playerId] = nil
    end
    gm.players[playerId] = {name=playerName or "Commander", gold=GameConfig.STARTING_GOLD, isHost=false, isCPU=false}
    gm.waitingForPlayer = false; PlayerToGame[playerId] = gm.id
    local md = MapDefs.Maps[gm.mapKey]; local mc = md.cols-1; local kr = math.floor(md.rows/2)
    gm.units.king_guest = UnitDefs.createUnit("king",playerId,kr,mc)
    gm.units.guard_guest1 = UnitDefs.createUnit("guard",playerId,3,mc-1)
    gm.units.guard_guest2 = UnitDefs.createUnit("guard",playerId,md.rows-4,mc-1)
    gm.units.spear_guest1 = UnitDefs.createUnit("spear",playerId,2,mc-3)
    gm.units.spear_guest2 = UnitDefs.createUnit("spear",playerId,md.rows-3,mc-3)
    gm.units.marine_guest1 = UnitDefs.createUnit("marine",playerId,kr,mc-4)
    broadcastLog(gm, playerName.." has joined the battle!")
    broadcastState(gm)
    return {success=true, gameId=gm.id, game=gm}
end

------------------------------------------------------
-- DeployUnit
------------------------------------------------------
Remotes.DeployUnit.OnServerEvent:Connect(function(player, unitType, row, col)
    local playerId = tostring(player.UserId)
    local gameId = PlayerToGame[playerId]
    if not gameId then return end
    local gm = ActiveGames[gameId]
    if not gm or gm.winner then return end
    if gm.currentTurn ~= playerId then return end
    if gm.phase ~= GameConfig.Phase.BUILD and gm.phase ~= GameConfig.Phase.DEPLOY then return end
    local def = UnitDefs.Types[unitType]
    if not def or not def.deployable then return end
    if def.locked and not isUnitUnlocked(player.UserId, unitType) then
        broadcastToast(gm, def.name.." is locked! Complete missions to unlock.", "warn"); return
    end
    local pdata = gm.players[playerId]
    if not pdata or pdata.gold < def.cost then return end
    local mapDef = MapDefs.Maps[gm.mapKey]
    if row < 0 or row >= mapDef.rows or col < 0 or col >= mapDef.cols then return end
    if getUnitAt(gm, row, col) then return end
    local isRiver = MapDefs.isRiver(gm.mapKey, col)
    local isNaval = def.theatre == "naval"
    if isNaval and not isRiver then return end
    if not isNaval and isRiver then return end
    -- Zone check: skip for river tiles (naval can deploy on any river tile)
    if not isRiver then
        if pdata.isHost then
            if col > MapDefs.getP1MaxCol(gm.mapKey) then return end
        else
            if col < MapDefs.getP2MinCol(gm.mapKey) then return end
        end
    end
    local uid = unitType.."_"..playerId.."_"..tostring(os.clock()):gsub("%.","")
    gm.units[uid] = UnitDefs.createUnit(unitType, playerId, row, col)
    pdata.gold = pdata.gold - def.cost
    broadcastLog(gm, pdata.name.." deployed "..def.name)
    broadcastState(gm)
end)

------------------------------------------------------
-- MoveUnit
------------------------------------------------------
Remotes.MoveUnit.OnServerEvent:Connect(function(player, unitId, toRow, toCol)
    local playerId = tostring(player.UserId)
    local gameId = PlayerToGame[playerId]
    if not gameId then return end
    local gm = ActiveGames[gameId]
    if not gm or gm.winner then return end
    if gm.currentTurn ~= playerId then return end
    local unit = gm.units[unitId]
    if not unit or unit.dead or unit.owner ~= playerId or unit.moved then return end
    local def = UnitDefs.Types[unit.type]
    if not def then return end
    local mapDef = MapDefs.Maps[gm.mapKey]
    if toRow < 0 or toRow >= mapDef.rows or toCol < 0 or toCol >= mapDef.cols then return end
    local dist = manhattanDist(unit.row, unit.col, toRow, toCol)
    if dist > def.move or dist == 0 then return end
    local isRiver = MapDefs.isRiver(gm.mapKey, toCol)
    local isNaval = def.theatre == "naval"
    if isNaval and not isRiver then return end
    if not isNaval and isRiver then return end
    if getUnitAt(gm, toRow, toCol) then return end
    for tid, trap in pairs(gm.traps) do
        if trap.row == toRow and trap.col == toCol and trap.owner ~= playerId then
            local trapDmg = 15
            unit.hp = math.max(0, unit.hp - trapDmg)
            gm.traps[tid] = nil
            broadcastLog(gm, unit.name.." triggered a trap! -"..trapDmg.." HP")
            if unit.hp <= 0 then
                unit.dead = true
                broadcastLog(gm, unit.name.." was destroyed by a trap!")
                broadcastState(gm); return
            end
        end
    end
    unit.row = toRow; unit.col = toCol; unit.moved = true
    broadcastLog(gm, unit.name.." moved"); broadcastState(gm)
end)

------------------------------------------------------
-- AttackUnit
------------------------------------------------------
Remotes.AttackUnit.OnServerEvent:Connect(function(player, attackerUid, defenderUid)
    local playerId = tostring(player.UserId)
    local gameId = PlayerToGame[playerId]
    if not gameId then return end
    local gm = ActiveGames[gameId]
    if not gm or gm.winner then return end
    if gm.currentTurn ~= playerId then return end
    local atk = gm.units[attackerUid]; local dfn = gm.units[defenderUid]
    if not atk or not dfn or atk.dead or dfn.dead then return end
    if atk.owner ~= playerId or dfn.owner == playerId or atk.attacked then return end
    local atkDef = UnitDefs.Types[atk.type]; local dfnDef = UnitDefs.Types[dfn.type]
    if not atkDef or not dfnDef then return end
    local dist = manhattanDist(atk.row, atk.col, dfn.row, dfn.col)
    if dist > atkDef.range then return end
    local actualId = defenderUid
    if dfn.type == "king" then
        for gid, gu in pairs(gm.units) do
            if gu.owner == dfn.owner and gu.type == "guard" and not gu.dead then
                if manhattanDist(gu.row,gu.col,dfn.row,dfn.col) <= 1 then
                    actualId = gid; broadcastLog(gm,"Guard Jonk intercepts!"); break
                end
            end
        end
    end
    local actualUnit = gm.units[actualId]; local actualDef = UnitDefs.Types[actualUnit.type]
    local atkPower = getAtkWithBuffs(gm, atk)
    local dmg = math.max(1, math.floor(atkPower - actualDef.def*0.4 + 0.5))
    actualUnit.hp = math.max(0, actualUnit.hp - dmg); atk.attacked = true
    if actualUnit.hp <= 0 then
        actualUnit.dead = true
        broadcastLog(gm, atk.name.." destroyed "..actualUnit.name.."!")
        incrementStat(player.UserId, "unitsKilled", 1)
        if actualUnit.type == "king" then
            incrementStat(player.UserId, "kingsKilled", 1)
            gm.winner = playerId
            incrementStat(player.UserId, "gamesWon", 1)
            local oppId = getOtherPlayerId(gm, playerId)
            if oppId and not gm.players[oppId].isCPU then incrementStat(oppId, "gamesLost", 1) end
            broadcastLog(gm, gm.players[playerId].name.." wins! Enemy King eliminated!")
            sendGameOver(gm); sendPlayerDataUpdate(player)
            if oppId then local op = findPlayerObj(oppId); if op then sendPlayerDataUpdate(op) end end
            broadcastState(gm); return
        end
    else
        broadcastLog(gm, atk.name.." hit "..actualUnit.name.." for "..dmg.." dmg")
        if actualId == defenderUid and dfn.type == "king" then
            for _, u in pairs(gm.units) do
                if u.owner == dfn.owner and u.type ~= "king" and not u.dead then
                    u.hp = math.max(1, math.floor(u.hp*(1-GameConfig.KING_AURA_DAMAGE)))
                end
            end
            broadcastLog(gm,"King struck! All troops weakened!")
        end
    end
    sendPlayerDataUpdate(player); broadcastState(gm)
end)

------------------------------------------------------
-- UseAbility
------------------------------------------------------
Remotes.UseAbility.OnServerEvent:Connect(function(player, unitId)
    local playerId = tostring(player.UserId)
    local gameId = PlayerToGame[playerId]
    if not gameId then return end
    local gm = ActiveGames[gameId]
    if not gm or gm.winner then return end
    if gm.currentTurn ~= playerId then return end
    local unit = gm.units[unitId]
    if not unit or unit.dead or unit.owner ~= playerId or unit.usedAbility then return end
    local def = UnitDefs.Types[unit.type]
    if not def or not def.ability then return end
    unit.usedAbility = true
    if unit.type == "mole" then
        local mapDef = MapDefs.Maps[gm.mapKey]
        local adj = {}
        for dr = -1, 1 do for dc = -1, 1 do
            if dr ~= 0 or dc ~= 0 then
                local nr, nc = unit.row+dr, unit.col+dc
                if nr>=0 and nr<mapDef.rows and nc>=0 and nc<mapDef.cols then
                    if not MapDefs.isRiver(gm.mapKey,nc) and not getUnitAt(gm,nr,nc) then
                        table.insert(adj, {nr,nc})
                    end
                end
            end
        end end
        if #adj > 0 then
            local s = adj[math.random(1,#adj)]
            local tid = "trap_"..tostring(os.clock()):gsub("%.","")
            gm.traps[tid] = {row=s[1], col=s[2], owner=playerId}
            broadcastLog(gm, "Mole Jonk plants a hidden trap!")
        end
    elseif unit.type == "lawyer" then
        local oppId = getOtherPlayerId(gm, playerId)
        if oppId and gm.players[oppId] then
            local stolen = math.floor((gm.players[oppId].gold or 0)*0.25)
            gm.players[oppId].gold = (gm.players[oppId].gold or 0) - stolen
            gm.players[playerId].gold = (gm.players[playerId].gold or 0) + stolen
            broadcastLog(gm, "Lawyer sues! Stole "..stolen.." gold!")
        end
    elseif unit.type == "commander" then
        local eid = "rally_"..tostring(os.clock()):gsub("%.","")
        gm.effects[eid] = {type="rally", row=unit.row, col=unit.col, owner=playerId, turnsLeft=1}
        broadcastLog(gm, "Commander rallies troops! +8 ATK this turn.")
    else
        broadcastLog(gm, def.name.." uses "..def.ability.."!")
    end
    broadcastState(gm)
end)

------------------------------------------------------
-- EndTurn
------------------------------------------------------
Remotes.EndTurn.OnServerEvent:Connect(function(player)
    local playerId = tostring(player.UserId)
    local gameId = PlayerToGame[playerId]
    if not gameId then return end
    local gm = ActiveGames[gameId]
    if not gm or gm.winner then return end
    if gm.currentTurn ~= playerId then return end
    for _, u in pairs(gm.units) do
        if u.owner == playerId then u.moved = false; u.attacked = false; u.usedAbility = false end
    end
    if gm.phase == GameConfig.Phase.BUILD then gm.phase = GameConfig.Phase.DEPLOY
    elseif gm.phase == GameConfig.Phase.DEPLOY then gm.phase = GameConfig.Phase.BATTLE end
    local otherId = getOtherPlayerId(gm, playerId)
    gm.currentTurn = otherId; gm.turnNum = gm.turnNum + 1
    gm.players[playerId].gold = math.min(GameConfig.MAX_GOLD, (gm.players[playerId].gold or 0)+GameConfig.GOLD_PER_TURN)
    local rem = {}
    for eid, eff in pairs(gm.effects) do
        eff.turnsLeft = (eff.turnsLeft or 1) - 1
        if eff.turnsLeft <= 0 then table.insert(rem, eid) end
    end
    for _, eid in ipairs(rem) do gm.effects[eid] = nil end
    broadcastLog(gm, gm.players[playerId].name.." ended their turn")
    broadcastState(gm)
    if otherId and gm.players[otherId] and gm.players[otherId].isCPU then
        task.delay(1.5, function() if gm.winner then return end; runCPUTurn(gm) end)
    end
end)

------------------------------------------------------
-- MarketplaceService
------------------------------------------------------
MarketplaceService.ProcessReceipt = function(info)
    local player = Players:GetPlayerByUserId(info.PlayerId)
    if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
    local data = getPlayerData(info.PlayerId)
    for _, pack in ipairs(GameConfig.Shop.CoinPacks) do
        if pack.id == info.ProductId and pack.id > 0 then
            data.coins = (data.coins or 0) + pack.coins
            savePlayerData(info.PlayerId); sendPlayerDataUpdate(player)
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
    end
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gpId, bought)
    if bought then
        local skId = GameConfig.Shop.SuperKingGamePassId
        if skId and skId > 0 and gpId == skId then
            local data = getPlayerData(player.UserId)
            data.hasSuperKing = true; savePlayerData(player.UserId); sendPlayerDataUpdate(player)
        end
    end
end)

------------------------------------------------------
-- Player lifecycle
------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
    loadPlayerData(player.UserId)
    local gpId = GameConfig.Shop.SuperKingGamePassId
    if gpId and gpId > 0 then
        pcall(function()
            if MarketplaceService:UserOwnsGamePassAsync(player.UserId, gpId) then
                getPlayerData(player.UserId).hasSuperKing = true
            end
        end)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    local playerId = tostring(player.UserId)
    savePlayerData(player.UserId)
    local gameId = PlayerToGame[playerId]
    if gameId then
        local gm = ActiveGames[gameId]
        if gm and not gm.winner then
            local otherId = getOtherPlayerId(gm, playerId)
            if otherId then
                gm.winner = otherId
                incrementStat(player.UserId, "gamesLost", 1)
                broadcastLog(gm, gm.players[playerId].name.." disconnected!")
                sendGameOver(gm); broadcastState(gm)
            end
        end
        PlayerToGame[playerId] = nil
    end
    PlayerDataCache[playerId] = nil
end)

task.spawn(function()
    while true do
        task.wait(120)
        for uid in pairs(PlayerDataCache) do savePlayerData(uid) end
    end
end)

print("[War of Jonk] GameServer loaded successfully")
