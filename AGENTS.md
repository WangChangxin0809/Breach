# AGENTS.md

## Project Introduction

**Game**: 2D 3v3 online top-down shooter with bomb defusal mode (like Counter-Strike).  
**Tech Stack**: Godot 4.6.2, Nakama 3.22.0, Go 1.22.
**Server URL**: `http://localhost:7350`
**Server Console URL**: `http://localhost:7351`
**Game Duration**: 2 minutes per round, 6 rounds per half, sides swap after half (all values are server-configurable; see Configuration & Data section).

### Core Game Loop
1. **Round Start**: Players spawn at faction bases. Attackers aim to plant the bomb; defenders protect the sites.
2. **Mid-Round**:
   - Players can move, shoot, melee, use items.
   - Zombie hunting zones exist for each faction – killing zombies grants points.
   - Earn points by killing enemies or neutral zombies. Points upgrade faction level (unlocks weapons/items).
3. **Round End**:
   - Attackers win if the bomb explodes. Defenders win if the bomb is defused or the round timer expires without a plant.
   - Each player has one respawn, activated upon teammate revive.
   - Respawn timers, weapon unlock costs, and other parameters are server-configurable.

### Key Mechanics
- **Vision**: Circular short-range vision + cone-shaped forward vision projecting from the player. Obstacles block cone vision creating dynamic shadows. Cone length limited by camera view.
- **Player State**: Health, movement speed (base values configurable).
- **Economy**: Points → Faction level → Weapon/item unlocks. Players have four loadout slots: sidearm, primary weapon, primary weapon attachment, and utility item. They equip from already unlocked items. Points reset to zero when sides swap. All costs and effects are defined in server config files.
- **Abilities**: Each character has a unique minor skill (basic ability) and an ultimate ability. Cooldowns, effects, and unlock conditions are defined in server config.

---

## Directory Structure

```
project-root/
├── addons/
│   ├── com.heroiclabs.nakama/       # Nakama Godot SDK (client-side)
│   │   ├── api/                     # API definitions
│   │   ├── client/                  # HTTP client implementation
│   │   ├── socket/                  # WebSocket client implementation
│   │   ├── utils/                   # Utility classes
│   │   └── dotnet-utils/            # .NET adapters
│   └── godot_mcp/                   # Godot MCP for AI agent integration
│       ├── commands/                # MCP command implementations
│       ├── ui/                      # MCP UI components
│       ├── utils/                   # MCP utility functions
│       └── skills.md                # MCP skill definition file
├── backend/
│   ├── modules/                     # Server-authoritative Go code (all match logic, config, handlers)
│   ├── proto/                       # Protocol Buffers definitions
│   │   └── generated/               # Auto-generated Protobuf code, DO NOT EDIT
│   └── docker-compose.yml           # Local Nakama server definition
├── codegen/
│   ├── README.md                    # Code generation documentation
│   └── main.go                      # Go code generator for Nakama API
├── docs/
│   └── Nakama-Godot-Client.md       # Official Nakama Godot SDK reference
├── test_suite/                      # Test suite for Nakama SDK
│   ├── tests/                       # Test scripts
│   ├── utils/                       # Test utilities
│   ├── bin/                         # Test binaries
│   ├── base_test.gd                 # Base test class
│   ├── runner.gd                    # Test runner
│   ├── tester.tscn                  # Test scene
│   └── project.godot                # Test project config
├── .github/                         # GitHub resources
├── .editorconfig                    # Editor configuration
├── .gitattributes                   # Git attributes
├── .gitignore                       # Git ignore rules
├── AGENTS.md                        # AI agent development guide
├── CHANGELOG.md                     # Project changelog
├── LICENSE                          # License file
├── README.md                        # Project documentation
├── icon.svg                         # Project icon
└── project.godot                    # Godot project configuration
```

- **Nakama SDK docs**: `docs/Nakama-Godot-Client.md` is the primary reference. Only if the solution is not found there, read the SDK source in `addons/com.heroiclabs.nakama/`.
- **Godot MCP**: `addons/godot_mcp/` allows the AI agent to interact with the Godot editor programmatically.

---

## Development Instructions

### 1. Backend Language – **Go**
You **must** use Go for all server-side logic.  
- Go provides the highest performance and full access to all Nakama APIs.  
- JavaScript/TypeScript runtime (JSVM) is restricted and unsuitable for high‑frequency, latency‑sensitive shooter loops.

### 1.1 Code Formatting & Style
- **Go**: All Go code must be formatted with `gofmt` or `goimports`. Run `gofmt -w ./backend/` before committing. Follow the [Effective Go](https://go.dev/doc/effective_go) guide.
- **GDScript**: Follow the [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html), including using `snake_case` for variables and signal callbacks.

### 2. Server-Authoritative Architecture
The game uses a **server‑authoritative** match system. The server holds the single source of truth for all game state. The client is untrusted; all client-reported data must be treated as hearsay until verified by the authoritative server logic.

#### Protobuf Messaging
> For specific usage, you need to web search some best practice by yourself.
- **Message Format**: Use Protocol Buffers for all match state messages (player actions, server broadcasts) to minimise bandwidth and serialisation overhead. Keep JSON for less frequent, non-critical messages like chat or configurations.
- All `.proto` definitions belong in `backend/proto/`.
- **Code Generation**: Use `protoc` with Go and Godot plugins to auto-generate serialization code.
- **Versioning**: Include version fields in protobuf messages for backward compatibility during updates.
- **Compression**: Combine with gzip compression for large state snapshots.

#### Match Type
- Use Nakama’s **authoritative match** (not relayed). The server creates the match with a custom `MatchHandler`.

#### Client Responsibilities
- Process local input and run **client‑side prediction** for movement, aiming, and shooting (instant feedback).
- Send player actions to the server as compact messages via `socket.send_match_state_async(match_id, op_code, proto_serialized(payload))`.
- Apply authoritative state updates received from the server. The server’s state always overrides the client’s prediction. You can reference the Best Practice from https://www.gabrielgambetta.com/client-side-prediction-server-reconciliation.html

#### Server Responsibilities (in `backend/modules/`)
- Implement a `MatchHandler` that defines:
  - `MatchInit`: initialise match state, spawn points, loadout, and return the **server-authoritative tick rate** (e.g., 20). This rate (1-60) is a key performance parameter and must be defined in the server config.
  - `MatchJoinAttempt`: validate and accept/reject player join attempts.
  - `MatchJoin`: handle successful player joins.
  - `MatchLeave`: handle player leaves/disconnects.
  - `MatchLoop`: the authoritative game loop (run at a fixed tick rate, e.g., 20 Hz, configurable).
  - `MatchTerminate`: cleanup when match ends.
  - `MatchSignal`: process incoming player actions (move, shoot, plant, etc.).
- **Server‑side validation**:
  - Movement speed – check against configured max speed.
  - Shooting – verify ammo count, fire rate cooldown, line‑of‑sight, damage calculations.
  - Bomb plant/defuse – validate position and timing.
  - Economy transactions – ensure the player has enough points.
- **State broadcast**: After processing each tick, broadcast the relevant state (player positions, health, bomb status, vision objects) to all clients using `dispatcher.BroadcastMessage()`. Set the `reliable` flag to `true` for all critical state updates (round end, player death, bomb plant/defuse) to guarantee delivery.

#### Anti‑Cheat Strategy
- **Always validate critical actions** (movement, damage) server‑side.
- If a client‑reported value exceeds allowed thresholds (e.g., speed > config max), the server must:
  1. Log the violation with user/session details, including timestamp and violation type.
  2. Reject the invalid action and keep the authoritative state unchanged.
  3. Kick the player from the match using `dispatcher.MatchKick()`.
  4. Optionally, use `nk.UsersBanId()` to prevent the player from rejoining (use for repeat offenders or severe violations).
- **No pixel‑perfect client trust**: Even if visual precision is slightly relaxed, game‑breaking cheats must be prevented.
- **Rate limiting**: Implement rate limits on sensitive actions to prevent spam/DoS attacks.

### 3. Configuration & Data
All tuneable game parameters **must** be defined in `backend/modules/config/` as Go exported constants. Split them into logical files such as:

- `weapons.go`: damage, fire rate, range, reload time, unlock cost, etc.
- `characters.go`: base health, movement speed, respawn time, vision radius/cone length.
- `match.go`: round duration, rounds per half, points per kill (player/zombie), faction upgrade thresholds.

**Example (`backend/modules/config/characters.go`)**:
```go
package config

const (
    BASE_MOVE_SPEED = 200.0
    MAX_HEALTH      = 100
    RESPAWN_DELAY   = 5 // seconds
)
```

All game logic must import these constants; **never hard‑code values** outside the config package.

### 4. Prototyping & Minimal Visuals
During active development, keep scenes visually minimal to speed up iteration and reduce distractions.

Use simple colored rectangles or placeholder primitives for terrain, cover, projectiles, and characters.

The file icon.svg can be used as a temporary player or object sprite.

Focus on game logic, networking, and mechanics correctness; polished art, VFX, and lighting come later.

Do not spend time on detailed environments until core systems are stable.

### 5. Error Handling & Logging
- **Always check returned errors** from Nakama API calls (e.g., `dispatcher.BroadcastMessage()`, `dispatcher.MatchKick()`). Log them using the provided logger. Unchecked errors can lead to silent failures and desynchronization.
- Use structured logging with appropriate severity levels:
  - `logger.Debug()` for verbose match state details (e.g., position updates, internal state).
  - `logger.Info()` for critical match events (player joined, bomb planted, round started).
  - `logger.Warn()` for non-critical issues that require attention (e.g., slow operation, unusual input).
  - `logger.Error()` for all unexpected errors (e.g., broadcast failure, invalid player action).
- Best practice example:
    ```go
    func (h *MatchHandler) MatchLoop(ctx context.Context, logger runtime.Logger, dispatcher runtime.MatchDispatcher, tick int64) {
        // ... 游戏逻辑 ...
        
        // 广播状态时检查错误
        data, err := proto.Marshal(gameState)
        if err != nil {
            logger.Error("Failed to marshal game state: %v", err)
            return
        }
        
        err = dispatcher.BroadcastMessage(OpCodeGameState, data, h.players, nil)
        if err != nil {
            logger.Error("Failed to broadcast game state: %v", err)
        }
        
        // 警告示例 - 检测到可疑行为
        if player.Speed > config.MAX_SPEED {
            logger.Warn("Player %s exceeding speed limit: %.2f > %.2f", 
                player.ID, player.Speed, config.MAX_SPEED)
        }
        
        // 调试示例 - 详细状态信息
        logger.Debug("Tick %d: Players=%d, BombPlanted=%v", 
            tick, len(h.players), h.bombPlanted)
    }
    ```

### 6. Testing & Workflow
> Use the Godot MCP tools to create minimal placeholder scenes, add nodes,
> and attach scripts directly in the editor for fast prototyping.
Include these commands in your development loop:

```bash
# Lint server code (run from project root)
go vet ./backend/modules/...

# Run Nakama locally (requires Docker, run from backend/ directory)
cd backend/
docker-compose up

# After changes, rebuild and restart Nakama (run from backend/ directory)
cd backend/
docker-compose down && docker-compose up --build

# Run Godot client (for manual testing)
# (command depends on your OS, e.g. `godot --path ./`)
```

The AI agent should **always lint the Go code** after modifications and provide the corrected code when errors are found.

### 7. Git Workflow & Conventions
- **Branching**: Always create a new branch for your work. Do NOT push directly to `main` or `master`.
- **Commit Format**: Use semantic, conventional commits: `<type>(<scope>): <description>`. Acceptable types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`.
  - Example: `feat(match): add round timer logic to MatchLoop`
- **Pull Requests**: Keep changes focused. If your changes touch more than 5 files or introduce a new module, consider breaking them into multiple PRs.
- **Code Review**: All PRs require at least one review before merging. Explain the “why” behind complex logic in the PR description.

---

## Reference Materials
- **Official Nakama Godot SDK docs**: Open `docs/Nakama-Godot-Client.md` in a browser – this is the primary API reference.
- **Example authoritative match in Go**: [Go Match Handler Example](https://heroiclabs.com/docs/nakama/server-framework/go-runtime/matches/) - A more reliable and performant example than the Fish Game tutorial.
- **Nakama client and console API**: open `docs/Nakama-Client-API.md` and `Nakama-Console-API.md`
- **Nakama Go Runtime API**: https://heroiclabs.com/docs/nakama/server-framework/go-runtime/function-reference/
