# War of Jonk — Roblox Edition

A turn-based strategy game for Roblox, ported from the browser version. Features a sleek dark glassmorphism UI, multiple unit types with unique abilities, CPU AI opponent, and online multiplayer support.

## Game Overview

**War of Jonk** is a tactical grid-based strategy game where two players battle to eliminate each other's King. The game features:

- **3 Phases**: Build → Deploy → Battle
- **15 unique unit types** across Infantry and Naval theatres
- **Special abilities** for each unit (Guard intercept, Lawyer gold steal, Mole traps, Commander rally, etc.)
- **3 maps**: Grasslands, Arctic Wastes, Desert Storm
- **CPU AI opponent** for solo play
- **Online multiplayer** via room codes
- **River mechanics** separating the two sides with naval units

## Project Structure

```
war-of-jonk/
├── default.project.json              # Rojo project config
├── README.md
└── src/
    ├── ReplicatedStorage/
    │   └── Modules/
    │       ├── GameConfig.lua         # Colors, constants, remote names
    │       ├── UnitDefs.lua           # All 15 unit type definitions
    │       └── MapDefs.lua            # Map layouts and river positions
    ├── ServerScriptService/
    │   └── GameServer.server.lua      # Server game logic, combat, CPU AI
    ├── StarterGui/
    │   └── WarOfJonkUI/
    │       └── init.meta.json         # ScreenGui metadata for Rojo
    └── StarterPlayerScripts/
        └── GameClient.client.lua      # Client UI, board rendering, input
```

## Setup Instructions

### Option 1: Using Rojo (Recommended)

1. Install [Rojo](https://rojo.space/) (v7+)
2. Clone this repository
3. Open Roblox Studio and install the Rojo plugin
4. Run `rojo serve` in the project root
5. Connect from Roblox Studio via the Rojo plugin
6. Hit Play to test

```bash
# Install Rojo via Aftman or Foreman
aftman add rojo-rbx/rojo

# Serve the project
rojo serve
```

### Option 2: Manual Import into Roblox Studio

1. Open Roblox Studio and create a new Baseplate place
2. Create the following service folders if they don't exist:
   - `ReplicatedStorage > Modules`
   - `ServerScriptService`
   - `StarterPlayer > StarterPlayerScripts`
3. Import each `.lua` file as a Script/ModuleScript/LocalScript:

| File | Roblox Location | Script Type |
|------|----------------|-------------|
| `GameConfig.lua` | `ReplicatedStorage.Modules.GameConfig` | ModuleScript |
| `UnitDefs.lua` | `ReplicatedStorage.Modules.UnitDefs` | ModuleScript |
| `MapDefs.lua` | `ReplicatedStorage.Modules.MapDefs` | ModuleScript |
| `GameServer.server.lua` | `ServerScriptService.GameServer` | Script (Server) |
| `GameClient.client.lua` | `StarterPlayer.StarterPlayerScripts.GameClient` | LocalScript |

4. Hit Play to test

## How to Play

### Controls
- **Click a unit** to select it and view its stats
- **Click "Move"** then click a highlighted tile to move
- **Click "Attack"** then click a highlighted enemy to attack
- **Click a unit in the Deploy roster** then click a highlighted tile to deploy
- **Click "End Turn"** to pass to the opponent

### Game Flow
1. **Create Game**: Choose vs CPU or vs Player (online)
2. **Build Phase**: Deploy your starting units using gold
3. **Deploy Phase**: Place additional units on your side
4. **Battle Phase**: Move, attack, and use abilities each turn
5. **Win Condition**: Destroy the enemy King!

### Unit Types

#### Infantry
| Unit | HP | ATK | DEF | MOV | Cost | Ability |
|------|-----|-----|-----|-----|------|---------|
| King | 100 | 25 | 20 | 1 | — | Aura of Command |
| Guard Jonk | 80 | 18 | 30 | 1 | 20 | Royal Shield |
| Spear Jonk | 60 | 22 | 12 | 2 | 15 | — |
| Marine Jonk | 70 | 26 | 15 | 2 | 22 | Suppressive Fire |
| Mole Jonk | 50 | 20 | 8 | 2 | 18 | Underground Spit |
| Commander Jonk | 65 | 15 | 18 | 2 | 25 | Rally |
| Lawyer Jonk | 45 | 0 | 0 | 2 | 20 | Sue |
| Lubatron | 55 | 10 | 10 | 2 | 18 | Grease Spill |
| Railgun Jonk | 45 | 55 | 5 | 1 | 45 | Bean Shot |
| Mole Daddy | 80 | 35 | 15 | 1 | 50 | Drill Strike |

#### Naval
| Unit | HP | ATK | DEF | MOV | Cost | Ability |
|------|-----|-----|-----|-----|------|---------|
| River Rat Jonk | 40 | 12 | 5 | 4 | 16 | Turbo Boost |
| Transport Jonk | 90 | 5 | 20 | 2 | 18 | Ferry |
| Borei Jonk | 70 | 30 | 18 | 2 | 35 | Missile Salvo |
| War Pirate | 55 | 18 | 12 | 3 | 24 | Hijack |
| Zumwalt Jonk | 120 | 50 | 25 | 2 | 60 | Full Salvo |

### Key Mechanics
- **King's Aura**: When the King takes damage, ALL friendly troops lose 10% HP
- **Guard Intercept**: Guards within 1 tile of the King automatically intercept attacks
- **River**: Divides the map — infantry can't cross, naval units can only be on river tiles
- **Traps**: Mole Jonk can plant hidden traps that deal 15 damage
- **Gold Income**: Earn 35 gold per turn (max 300)

## UI Design

The UI follows a sleek dark glassmorphism aesthetic matching the browser version:
- Dark background (#050505)
- Glass panels with subtle borders and transparency
- Sky blue for Player 1, pink for Player 2
- Gold accent for currency and special elements
- Monospace font for stats and labels
- Smooth rounded corners throughout

## Tech Stack

- **Roblox Luau** for all game logic
- **Rojo** for external project management
- **Frame-based 2D board** rendered in a ScreenGui (no 3D workspace needed)
- **RemoteEvents/RemoteFunctions** for client-server communication
