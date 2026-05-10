# ChopStyx

A turn-based strategy game built in **Godot 4.6** using GDScript. Based on the hand game "Chopsticks," the player faces off against **Charon** (the ferryman of the dead) in an asymmetric duel augmented by a ring-based upgrade system inspired by Greek mythology.

---

## Game Overview (from GDD v2)

- **Player:** 2 hands, each starting with 1 finger (max 5 per hand)
- **Opponent (Charon):** 3 hands, each starting with 1 finger (max 5 per hand)
- **Overflow system:** `(current + added) % 5` -- reaching 0 kills a hand
- **Win condition:** Eliminate all of Charon's hands
- **Lose condition:** All player hands are eliminated
- **Design intent:** Inherently disadvantageous to the player; rings provide the edge needed to win

### Player Actions (per turn)

| Action | Description | Consumes Turn? |
|--------|-------------|----------------|
| **Hit** | Select one of your hands, then target any living hand (yours or Charon's). Adds source finger count to target (mod 5). | Yes |
| **Split** | Redistribute fingers across your own hands. Total must be preserved, distribution must change. | Yes |
| **Use Ring** | Activate a ring ability (see Ring System below). | **Free action (GDD)** |

### Ring System

Rings are earned when the player kills one of Charon's hands. The player is offered 2 random rings from those not at capacity and picks one. Rings are categorized by finger type with ascending power:

| Finger | Power | Cooldown | Capacity | Rings |
|--------|-------|----------|----------|-------|
| Index (I) | 1 | 1 round | 1 per type (GDD says 1 total) | Asclepius, Icarus |
| Middle (M) | 2 | 2 rounds | 2 per type | Medusa, Aegis |
| Ring (R) | 3 | 4 rounds | 2 per type | Hercules, Midas |
| Pinky (P) | 4 | 6 rounds | 1 per type | Hermes, Pandora |

**Activation requirement:** A ring can only be used if the player has a living hand with at least N fingers, where N corresponds to the finger position (Index=1, Middle=2, Ring=3, Pinky=4).

#### Ring Descriptions

| Ring | Finger | Effect | Cooldown |
|------|--------|--------|----------|
| **Asclepius** | Index | Select one of your hands. That hand gains +1 finger. | 1 |
| **Icarus** | Index | Select one of Charon's hands. That hand loses 1 finger. | 1 |
| **Medusa** | Middle | Select one of Charon's hands. Stuns it (cannot attack or split). | 2 |
| **Aegis** | Middle | Select one of your hands. Protects it from Charon's next attack. | 2 |
| **Hercules** | Ring | Select one of your hands. That hand deals double damage on next hit. | 4 |
| **Midas** | Ring | Select one of Charon's hands. Forces Charon to attack that hand on his turn. | 4 |
| **Hermes** | Pinky | Instant. Grants +1 action this turn. | 6 |
| **Pandora** | Pinky | Opens a split dialog for ALL hands (yours + Charon's). Redistribute freely. | 6 |

### Sound Effects (planned, not yet implemented)

The GDD references these sound assets:
- Charon Hand Death: "ghost fire swoosh" (mixkit.co)
- Hand Impact: "impact of a blow" (mixkit.co)
- Hand Select: "clickselect" (pixabay.com)
- Ring Inspect: "dropping keys in the floor" (mixkit.co)
- Hand Death: "knuckle cracking" (pixabay.com)
- BGM: "noncopyright music pianos" (pixabay.com)

---

## GDD v2 vs Current Implementation -- Discrepancies

| # | GDD v2 Specification | Current Code Behavior | Severity |
|---|----------------------|----------------------|----------|
| 1 | **Ring usage is a free action** ("Gaining and consuming Rings are free actions. They do not consume a turn.") | Every `use_ring_*()` function calls `_consume_action()`, costing the player their turn action. | **High** |
| 2 | **Index finger capacity = 1** (the table says max 1 ring held for Index type) | Code sets `capacity: 2` for both Asclepius and Icarus individually, allowing 2 of each. | Medium |
| 3 | **Middle finger ability** described in the table as "Gain a new hand with 3 fingers" | Neither Medusa nor Aegis spawns a new hand. The detailed descriptions (stun/protect) match the code. The table may be outdated or describing a different design. | Low (table vs detail conflict in GDD itself) |
| 4 | **Sound effects** listed in GDD | No audio system implemented. No `.wav`/`.ogg`/`.mp3` assets present. | Medium |
| 5 | **Hit described as "add +1 finger to target"** in GDD action list | Code correctly implements standard Chopsticks rules (add source finger count, not a flat +1). The GDD's "Regular Chopsticks rules" preamble takes precedence. | Low (GDD wording ambiguity) |

---

## Project Structure

```
chopstyx/
├── .godot/                      # Godot editor cache (auto-generated)
├── assets/
│   └── bg_gradient.gdshader     # Background gradient shader
├── scenes/
│   ├── main.tscn                # Root game scene (full UI layout)
│   ├── hand_display.tscn        # Reusable hand display component
│   └── split_panel.tscn         # Split dialog overlay component
├── scripts/
│   ├── enums.gd                 # [Autoload] Enums and game constants
│   ├── game_state.gd            # [Autoload] Core game logic and state
│   ├── main.gd                  # Game controller and state machine
│   ├── hand_display.gd          # Individual hand rendering (custom draw)
│   ├── ring_panel.gd            # Ring inventory UI + RingSlot inner class
│   ├── split_panel.gd           # Drag-and-drop split dialog
│   ├── ai_opponent.gd           # Charon's AI turn logic
│   └── ui_constants.gd          # Colors, sizes, animation durations
├── _GDD.pdf                     # Original Game Design Document
├── _GDD v2.pdf                  # Updated Game Design Document
├── project.godot                # Godot project configuration
└── icon.svg                     # Project icon
```

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     AUTOLOAD SINGLETONS                     │
│  ┌──────────────┐    ┌──────────────────────────────────┐   │
│  │   Enums.gd   │    │         GameState.gd              │   │
│  │  Constants,   │    │  State, signals, game logic,     │   │
│  │  ring data,   │◄───│  ring mechanics, turn management │   │
│  │  enum defs    │    │                                  │   │
│  └──────────────┘    └──────────┬───────────────────────┘   │
└─────────────────────────────────┼───────────────────────────┘
                                  │ signals (hands_changed,
                                  │ hand_died, turn_changed,
                                  │ game_over, log_message, etc.)
                                  ▼
┌─────────────────────────────────────────────────────────────┐
│                      main.gd (Controller)                   │
│  State machine ─ input routing ─ UI orchestration           │
│  Connects to all UI components and GameState signals        │
├─────────────┬──────────────┬──────────────┬─────────────────┤
│             │              │              │                  │
▼             ▼              ▼              ▼                  ▼
hand_display  ring_panel     split_panel    ai_opponent     Dialogs
.gd           .gd            .gd            .gd            (RingSelect,
(per hand)    (8 RingSlots)  (drag & drop)  (Charon AI)     GameOver)
```

### Data Flow

1. **Player clicks hand** -> `main.gd` receives `hand_clicked` signal -> routes via state machine
2. **Action executed** -> `main.gd` calls `GameState.perform_hit()` / `perform_split()` / `use_ring_*()`
3. **State changes** -> `GameState` emits signals (`hands_changed`, `rings_changed`, etc.)
4. **UI updates** -> `main.gd` receives signals -> calls `refresh()` on displays, updates labels
5. **AI turn** -> `main.gd` starts timer -> `AIOpponent.take_turn()` -> GameState methods -> signals -> UI update

---

## File-by-File Function Reference

### `scripts/enums.gd` (118 lines) -- Autoload Singleton

Global constants, enumerations, and ring configuration data.

**Enums:**

| Enum | Values | Purpose |
|------|--------|---------|
| `Owner` | `PLAYER`, `OPPONENT` | Identifies hand ownership |
| `ActionState` | `CHOOSE_ACTION`, `HIT_SELECT_TARGET`, `SPLIT_DIALOG`, `RING_SELECT_TARGET`, `RING_DRAG`, `AI_TURN`, `GAME_OVER` | State machine states |
| `RingType` | `ASCLEPIUS`, `ICARUS`, `MEDUSA`, `AEGIS`, `HERCULES`, `MIDAS`, `HERMES`, `PANDORA` | The 8 ring types |

**Constants:**

| Constant | Value | Purpose |
|----------|-------|---------|
| `MAX_FINGERS` | `5` | Modulus for overflow system |
| `PLAYER_START_HANDS` | `2` | Player starts with 2 hands |
| `OPPONENT_START_HANDS` | `3` | Charon starts with 3 hands |
| `AI_HIT_CHANCE` | `0.7` | 70% chance AI chooses hit over split |
| `AI_DELAY` | `0.5` | Seconds before AI acts |

**`RING_DATA` Dictionary:**

Each entry keyed by `RingType` contains: `name`, `short_name`, `desc`, `cooldown`, `capacity`, `min_fingers`, `finger_group`.

---

### `scripts/game_state.gd` (512 lines) -- Autoload Singleton

Core game logic, state management, and ring mechanics. All game mutations happen here.

**Signals:**

| Signal | Parameters | Emitted When |
|--------|-----------|-------------|
| `hands_changed` | -- | Any hand data is modified |
| `hand_died` | `hand_id: int` | A hand reaches 0 fingers |
| `rings_changed` | -- | Ring inventory or cooldowns change |
| `turn_changed` | `is_player_turn: bool` | Turn switches between player/Charon |
| `round_changed` | `round_num: int` | A new round begins |
| `game_over` | `player_won: bool` | All hands of one side are eliminated |
| `log_message` | `text: String` | An event should be logged to the action log |

**State Variables:**

| Variable | Type | Purpose |
|----------|------|---------|
| `hands` | `Array[Dictionary]` | All hands. Each: `{id, fingers, alive, owner, stunned, protected, double_damage, midas_target}` |
| `next_hand_id` | `int` | Auto-incrementing hand ID |
| `player_rings` | `Dictionary` | `RingType -> count` (how many of each ring the player holds) |
| `ring_cooldowns` | `Dictionary` | `RingType -> rounds remaining` before ring is usable again |
| `current_round` | `int` | Current round number |
| `is_player_turn` | `bool` | Whose turn it is |
| `actions_remaining` | `int` | Actions left this turn (default 1) |
| `bonus_actions` | `int` | Extra actions from Hermes ring |

**Functions:**

| Function | Signature | Description |
|----------|-----------|-------------|
| `_ready` | `() -> void` | Calls `reset_game()` on load |
| `reset_game` | `() -> void` | Clears all state, creates starting hands (2 player + 3 opponent, 1 finger each), initializes ring inventories to 0, emits initial signals |
| `_create_hand` | `(owner: Owner, fingers: int) -> Dictionary` | Creates a hand dict, appends to `hands`, returns it |
| `get_hand` | `(hand_id: int) -> Dictionary` | Finds hand by ID, returns `{}` if not found |
| `get_hands_for_owner` | `(owner: Owner) -> Array[Dictionary]` | Returns all hands (alive or dead) for an owner |
| `get_living_hands` | `(owner: Owner) -> Array[Dictionary]` | Returns only alive hands for an owner |
| `get_all_living_hands` | `() -> Array[Dictionary]` | Returns all alive hands across both sides |
| `get_player_hands` | `() -> Array[Dictionary]` | Shortcut for `get_living_hands(PLAYER)` |
| `get_opponent_hands` | `() -> Array[Dictionary]` | Shortcut for `get_living_hands(OPPONENT)` |
| `has_living_hand_with_min_fingers` | `(min_fingers: int) -> bool` | Checks if any player hand has >= N fingers (ring activation check) |
| `perform_hit` | `(source_id: int, target_id: int) -> bool` | Executes an attack. Handles Aegis protection, Hercules double damage. Calculates `(target + damage) % 5`. Kills hand if result is 0. Triggers ring earn check and game over check. |
| `perform_split` | `(owner: Owner, new_distribution: Array[int]) -> bool` | Validates and applies finger redistribution. Total must be preserved, must differ from current, each value 0-4. |
| `earn_ring` | `(ring_type: RingType) -> bool` | Adds ring to inventory if under capacity. Emits `rings_changed`. |
| `can_use_ring` | `(ring_type: RingType) -> bool` | Returns `true` if: player owns >= 1, cooldown is 0, and player has a hand with enough fingers |
| `use_ring_asclepius` | `(target_id: int) -> bool` | Target (player hand) gains +1 finger (mod 5). Applies cooldown. |
| `use_ring_icarus` | `(target_id: int) -> bool` | Target (opponent hand) loses 1 finger. Kills if reaches 0. |
| `use_ring_medusa` | `(target_id: int) -> bool` | Sets `stunned = true` on opponent hand. |
| `use_ring_aegis` | `(target_id: int) -> bool` | Sets `protected = true` on player hand. Shield breaks after blocking one attack. |
| `use_ring_hercules` | `(target_id: int) -> bool` | Sets `double_damage = true` on player hand. Effect consumed on next hit. |
| `use_ring_midas` | `(target_id: int) -> bool` | Sets `midas_target = true` on opponent hand. Forces AI to attack it. |
| `use_ring_hermes` | `() -> bool` | Grants +1 `bonus_actions` and +1 `actions_remaining`. |
| `use_ring_pandora` | `(new_distribution: Array[int]) -> bool` | Validates and applies combined redistribution across ALL hands (player + opponent). |
| `_apply_ring_cost` | `(ring_type: RingType) -> void` | Decrements ring count by 1, sets cooldown from `RING_DATA`. |
| `_consume_action` | `() -> void` | Decrements `actions_remaining` by 1 |
| `has_actions_remaining` | `() -> bool` | Returns `actions_remaining > 0` |
| `end_player_turn` | `() -> void` | Sets `is_player_turn = false`, resets actions to 1, emits `turn_changed(false)` |
| `end_opponent_turn` | `() -> void` | Sets `is_player_turn = true`, resets actions, ticks cooldowns, increments round, emits signals |
| `_tick_cooldowns` | `() -> void` | Decrements all positive cooldowns by 1, emits `rings_changed` |
| `_check_ring_earn` | `(dead_hand: Dictionary) -> void` | Stub -- ring earn is handled by `main.gd` via `should_earn_ring_on_kill()` |
| `_check_game_over` | `() -> void` | Emits `game_over(true)` if no opponent hands alive, `game_over(false)` if no player hands alive |
| `_hand_label` | `(hand: Dictionary) -> String` | Returns label like `"P-Hand1(3)"` or `"C-Hand2(1)"` for logging |
| `should_earn_ring_on_kill` | `(dead_hand: Dictionary) -> bool` | Returns `true` if dead hand belongs to opponent |
| `get_available_ring_types` | `() -> Array[RingType]` | Returns ring types where player count < capacity |

---

### `scripts/main.gd` (693 lines) -- Game Controller

Attached to root `Control` node. Manages the game state machine, connects all UI components, routes player input, and orchestrates AI turns.

**State Variables:**

| Variable | Type | Purpose |
|----------|------|---------|
| `current_state` | `ActionState` | Current state machine state |
| `hit_source_id` | `int` | Hand ID selected as hit source (-1 = none) |
| `active_ring_type` | `RingType` | Ring type currently being targeted |
| `hand_displays` | `Dictionary` | `hand_id -> HandDisplay` node mapping |
| `ai` | `Node` | AIOpponent instance (created at runtime) |
| `_pending_ring_earn` | `bool` | Whether a ring earn dialog needs to be shown |
| `_pandora_mode` | `bool` | Whether the split dialog is in Pandora (all-hands) mode |

**Functions:**

| Function | Signature | Description |
|----------|-----------|-------------|
| `_ready` | `() -> void` | Creates AI node, connects all signals (buttons, GameState, ring panel, split panel, dialogs, AI timer), builds hand displays, sets initial state |
| `_play_entrance_animations` | `() -> void` | Triggers staggered entrance animations on all hand displays |
| `_build_hand_displays` | `() -> void` | Clears and rebuilds all hand display nodes for both containers |
| `_add_hand_display` | `(hand, index, container) -> void` | Instantiates `HandDisplayScene`, connects `hand_clicked` and `ring_dropped` signals, stores in `hand_displays` dict |
| `_set_state` | `(new_state: ActionState) -> void` | **Core state machine.** Clears highlights, updates labels, then configures UI for the new state (enables/disables buttons, sets hand selectability and highlights). Handles all 7 states. |
| `_on_split_pressed` | `() -> void` | Validates split is possible (>= 2 hands, >= 1 total finger), enters `SPLIT_DIALOG` state |
| `_on_end_turn_pressed` | `() -> void` | Starts AI turn |
| `_on_cancel_pressed` | `() -> void` | Resets to `CHOOSE_ACTION`, closes split panel if open |
| `_on_hand_clicked` | `(hand_id: int) -> void` | **Main input router.** Behavior depends on `current_state`: selects source in `CHOOSE_ACTION`, executes hit in `HIT_SELECT_TARGET`, applies ring in `RING_SELECT_TARGET` / `RING_DRAG` |
| `_on_split_confirmed` | `(distribution: Array[int]) -> void` | Handles split result. Routes to `use_ring_pandora()` if in Pandora mode, otherwise `perform_split()`. Shows error log on invalid input. |
| `_on_ring_use_requested` | `(ring_type: RingType) -> void` | Called when ring slot is clicked. Routes to target selection state or handles instant rings (Hermes, Pandora). |
| `_on_ring_drag_started` | `(ring_type: RingType) -> void` | Same as above but enters `RING_DRAG` state for target-requiring rings |
| `_on_ring_dropped` | `(hand_id, ring_type) -> void` | Applies ring to dropped-on hand during `RING_DRAG` state |
| `_after_ring_action` | `() -> void` | Post-ring-use flow. Shows ring earn dialog if pending, otherwise returns to `CHOOSE_ACTION`. |
| `_on_hand_died` | `(hand_id: int) -> void` | Plays death animation. Sets `_pending_ring_earn = true` if player killed an opponent hand. |
| `_show_ring_select_dialog` | `() -> void` | Populates dialog with 2 random available rings, shows popup |
| `_on_ring_selected` | `(ring_type: RingType) -> void` | Earns the selected ring, hides dialog, continues game flow |
| `_on_ring_select_closed` | `() -> void` | Handles dialog close without selection (ring forfeited) |
| `_after_player_action` | `() -> void` | Checks for pending ring earn, then either returns to `CHOOSE_ACTION` (if actions remain) or starts AI turn |
| `_continue_after_ring_earn` | `() -> void` | Called after ring earn dialog resolves. Checks remaining actions. |
| `_start_ai_turn` | `() -> void` | Ends player turn, enters `AI_TURN` state, starts AI delay timer |
| `_on_ai_timer_timeout` | `() -> void` | Executes `ai.take_turn()`, screen flash, ends opponent turn, returns to `CHOOSE_ACTION` |
| `_screen_flash` | `() -> void` | White flash overlay that fades out (visual feedback for hits) |
| `_on_turn_changed` | `(is_player: bool) -> void` | Updates turn label text |
| `_on_round_changed` | `(round_num: int) -> void` | Updates round label text |
| `_on_game_over` | `(player_won: bool) -> void` | Sets `GAME_OVER` state, shows win/lose dialog |
| `_on_log_message` | `(text: String) -> void` | Appends BBCode text to action log |
| `_on_restart` | `() -> void` | Resets GameState, rebuilds displays, clears log, plays entrance animations |
| `_refresh_hands` | `() -> void` | Updates all existing hand displays with current GameState data |
| `_rebuild_hand_displays_safe` | `() -> void` | Adds display nodes for any new hands not yet in `hand_displays` (unused currently) |
| `_clear_highlights` | `() -> void` | Sets all hand displays to `NONE` highlight, not selectable |
| `_set_all_hands_not_selectable` | `() -> void` | Disables selectability on all hands |
| `_set_action_buttons` | `(enabled: bool) -> void` | Enables/disables Split and End Turn buttons |
| `_update_actions_label` | `() -> void` | Updates "Actions: N" label |

---

### `scripts/hand_display.gd` (255 lines) -- Hand Visual Component

Custom-drawn `Control` node representing a single hand. All rendering is done in `_draw()` -- no child nodes.

**Signals:**

| Signal | Parameters | Emitted When |
|--------|-----------|-------------|
| `hand_clicked` | `hand_id: int` | Player left-clicks a selectable hand |
| `ring_dropped` | `hand_id: int, ring_type: RingType` | A ring is drag-dropped onto this hand |

**State Variables:**

| Variable | Type | Purpose |
|----------|------|---------|
| `hand_id` | `int` | ID of the hand this display represents |
| `hand_data` | `Dictionary` | Current hand state dict from GameState |
| `_hand_index` | `int` | Display index (0-based, per owner) |
| `_highlight_mode` | `HighlightMode` | Current border glow mode |
| `_selectable` | `bool` | Whether clicks are accepted |
| `_hovered` | `bool` | Mouse hover state |
| `_pulse_time` | `float` | Breathing animation timer |
| `_flash_alpha` | `float` | Hit flash overlay opacity (fades to 0) |
| `_death_alpha` | `float` | Death overlay opacity (fades to 1) |
| `_entrance_progress` | `float` | Entrance animation progress (0->1) |

**Functions:**

| Function | Signature | Description |
|----------|-----------|-------------|
| `_ready` | `() -> void` | Sets mouse filter, cursor, minimum size, connects hover signals |
| `_process` | `(delta: float) -> void` | Updates animation timers (pulse, flash fade, entrance), triggers redraw if needed |
| `setup` | `(hand_id, hand_data, index) -> void` | Initial setup with hand data |
| `refresh` | `(hand_data, index) -> void` | Updates hand data and redraws |
| `set_highlight` | `(mode: HighlightMode) -> void` | Sets border glow mode |
| `set_selectable` | `(enabled: bool) -> void` | Enables/disables click interaction, changes cursor |
| `play_hit_flash` | `() -> void` | Triggers white flash overlay animation |
| `play_death` | `() -> void` | Tweens death overlay to full opacity |
| `play_entrance` | `(delay: float) -> void` | Fade-in + scale entrance with optional delay |
| `_gui_input` | `(event: InputEvent) -> void` | Handles left-click -> emits `hand_clicked` if selectable |
| `_on_mouse_entered` / `_on_mouse_exited` | `() -> void` | Hover state tracking |
| `_draw` | `() -> void` | **Main rendering.** Draws: rounded rect background, border glow (pulsing/source/target), hand label, finger dots (using `DOT_PATTERNS`), dead X mark, status text, hit flash overlay, death overlay |
| `_draw_finger_dots` | `(center, count, color) -> void` | Renders finger dots with glow, fill, and colored ring |
| `_draw_rounded_rect` | `(rect, color, radius) -> void` | Draws filled rounded rectangle via polygon |
| `_draw_rounded_rect_outline` | `(rect, color, radius, width) -> void` | Draws rounded rectangle border via line segments |
| `_rounded_rect_points` | `(rect, radius) -> PackedVector2Array` | Generates corner-rounded polygon points |
| `_draw_circle_outline` | `(center, radius, color, width) -> void` | Draws circle outline via 24-segment line loop |
| `_get_text_width` | `(text, font_size) -> float` | Measures text width using fallback font |

---

### `scripts/ring_panel.gd` (250 lines) -- Ring Inventory UI

An `HBoxContainer` that creates and manages 8 `RingSlot` controls (one per ring type). Includes a floating tooltip system.

**Signals:**

| Signal | Parameters | Emitted When |
|--------|-----------|-------------|
| `ring_use_requested` | `ring_type: RingType` | A ring slot is activated (unused -- drag path preferred) |
| `ring_drag_started` | `ring_type: RingType` | Player clicks an active ring slot |

**Functions:**

| Function | Signature | Description |
|----------|-----------|-------------|
| `_ready` | `() -> void` | Creates slots, connects to `GameState.rings_changed`, initial refresh |
| `_create_slots` | `() -> void` | Instantiates 8 `RingSlot` controls, connects signals, stores in `ring_slots` dict |
| `_refresh` | `() -> void` | Updates each slot's state (count, cooldown, usability) from GameState |
| `_on_slot_pressed` | `(ring_type) -> void` | Emits `ring_use_requested` |
| `_on_slot_hover` | `(ring_type) -> void` | Creates and positions tooltip panel on viewport root |
| `_on_slot_unhover` | `() -> void` | Destroys tooltip panel |
| `_create_tooltip_panel` | `(ring_data, ring_type) -> Control` | Builds tooltip with styled PanelContainer: title, description (autowrap), cooldown info. Clamped to screen bounds. |
| `set_enabled` | `(enabled: bool) -> void` | Refreshes if enabled, deactivates all slots if disabled |

#### Inner Class: `RingSlot` (extends Control)

Individual ring slot with custom drawing.

| Function | Signature | Description |
|----------|-----------|-------------|
| `_ready` | `() -> void` | Sets mouse filter, cursor, connects hover lambdas |
| `update_state` | `(count, cd, max_cd, usable) -> void` | Updates internal state, changes cursor, redraws |
| `set_active` | `(active: bool) -> void` | Enables/disables the slot |
| `_gui_input` | `(event) -> void` | Left-click on active slot emits `ring_drag_started` |
| `get_drag_data` | `(from_position) -> Variant` | Returns null (drag handled via signals, not Godot DnD) |
| `_draw` | `() -> void` | Draws: circle background, colored border, cooldown arc overlay, ring letter, count badge (bottom-right), cooldown number (center) |
| `_draw_circle_outline_static` | `(center, radius, color, width) -> void` | 32-segment circle outline |
| `_draw_cooldown_arc` | `(center, radius, fraction, color) -> void` | Filled arc from top, clockwise, showing cooldown progress |

---

### `scripts/split_panel.gd` (357 lines) -- Split Dialog

Full-screen overlay with drag-and-drop finger redistribution. All rendering is custom `_draw()`.

**Signals:**

| Signal | Parameters | Emitted When |
|--------|-----------|-------------|
| `split_confirmed` | `distribution: Array[int]` | Player confirms a valid new distribution |
| `split_canceled` | -- | Player cancels the split |

**Constants:**

| Constant | Value | Purpose |
|----------|-------|---------|
| `BOX_SIZE` | `160x200` | Size of each hand box |
| `BOX_GAP` | `40` | Space between boxes |
| `DRAG_DOT_RADIUS` | `18` | Dot size while dragging |
| `SNAP_DOT_RADIUS` | `16` | Dot size when snapped |
| `BUTTON_WIDTH/HEIGHT` | `120x40` | Confirm/Cancel button sizes |

**Functions:**

| Function | Signature | Description |
|----------|-----------|-------------|
| `_ready` | `() -> void` | Hides panel, sets mouse filter |
| `open` | `(hands: Array[Dictionary]) -> void` | Stores hand data, builds layout, fade-in animation |
| `close` | `() -> void` | Fade-out animation, then clears state |
| `_on_fade_out_done` | `() -> void` | Hides panel, clears internal arrays |
| `_process` | `(delta) -> void` | Forces redraw during fade animation |
| `_build_layout` | `() -> void` | Calculates box positions (centered), creates dot objects for each finger, calculates button rects |
| `_get_snap_position` | `(box_index, dot_index, total_dots) -> Vector2` | Returns dot position using `DOT_PATTERNS` scaled to box |
| `_get_distribution` | `() -> Array[int]` | Counts dots in each box, returns as array |
| `_reindex_dots_in_box` | `(box_index) -> void` | Re-snaps all dots in a box to correct positions after move |
| `_gui_input` | `(event) -> void` | Routes mouse button and motion events |
| `_on_press` | `(pos) -> void` | Hit-tests dots (reverse order for z-layering), checks button clicks |
| `_on_release` | `(pos) -> void` | Drops dragged dot into target box (if valid, max 4), or snaps back |
| `_try_confirm` | `() -> void` | Validates distribution differs from current and is within bounds, emits `split_confirmed` |
| `_draw` | `() -> void` | Draws: dark backdrop, "SPLIT FINGERS" title, hand boxes, dots, Confirm/Cancel buttons, instruction text |
| `_draw_hand_box` | `(index) -> void` | Draws box background, border, label, dot count |
| `_draw_dot` | `(index) -> void` | Draws finger dot with glow, fill, and ring outline |
| `_draw_button` | `(rect, text, color, hovered) -> void` | Draws button with background, border, centered text |
| `_draw_rect_outline` | `(rect, color, width) -> void` | 4-line rectangle outline |
| `_draw_circle_outline` | `(center, radius, color, width) -> void` | 24-segment circle outline |

---

### `scripts/ai_opponent.gd` (131 lines) -- Charon AI

Simple randomized AI for the opponent's turn.

**Functions:**

| Function | Signature | Description |
|----------|-----------|-------------|
| `take_turn` | `() -> void` | **Main AI entry point.** Filters stunned hands. Handles Midas-forced attacks first. Otherwise: 70% hit, 30% split. Resets stun flags. |
| `_try_hit` | `(ai_hands, player_hands) -> void` | Picks random non-stunned source with fingers > 0, picks random target (any living hand except self). Executes `perform_hit()`. |
| `_try_split` | `(all_ai_hands) -> bool` | Generates random valid distributions (up to 20 attempts). Falls back to hit if no valid split found. |
| `_random_distribution` | `(total, count) -> Array[int]` | Distributes `total` fingers randomly across `count` hands, max 4 each. Returns empty array if impossible. |

---

### `scripts/ui_constants.gd` (91 lines) -- Visual Constants

A `class_name` (not autoload) containing all UI styling values. Referenced by hand_display, ring_panel, split_panel, and main.

**Color Constants:**

| Constant | Value | Used For |
|----------|-------|----------|
| `COLOR_PLAYER` | Cyan `(0.0, 0.9, 1.0)` | Player hand borders, dots |
| `COLOR_OPPONENT` | Magenta `(1.0, 0.2, 0.6)` | Opponent hand borders, dots |
| `RING_COLORS` | Dict of 8 colors | Each ring type's accent color (greens, blues, oranges, purples) |
| `RING_LETTERS` | Dict of 8 strings | Single-letter identifiers: A, I, M, E, H, D, R, P |
| `COLOR_BG_ALIVE` / `_DEAD` | Dark grays | Hand card backgrounds |
| `COLOR_HIGHLIGHT_SOURCE` | Yellow `(1.0, 1.0, 0.6)` | Selected source hand border |
| `COLOR_CONFIRM` / `COLOR_CANCEL` | Green / Red | Split dialog buttons |

**Size Constants:**

| Constant | Value | Purpose |
|----------|-------|---------|
| `HAND_SIZE` | `140x180` | Hand display minimum size |
| `DOT_RADIUS` | `14.0` | Finger dot radius |
| `DOT_AREA_RADIUS` | `50.0` | Area within which dots are placed |
| `RING_SLOT_SIZE` | `70x70` | Ring slot minimum size |
| `RING_SLOT_RADIUS` | `30.0` | Ring slot circle radius |

**Animation Constants:**

| Constant | Value | Purpose |
|----------|-------|---------|
| `ANIM_HIT_FLASH` | `0.3s` | Hit flash fade duration |
| `ANIM_DEATH_FADE` | `0.4s` | Death overlay fade-in duration |
| `ANIM_PULSE_SPEED` | `2.0` | Selectable hand breathing pulse (cycles/sec) |
| `ANIM_ENTRANCE_DURATION` | `0.4s` | Hand entrance animation |
| `ANIM_ENTRANCE_STAGGER` | `0.1s` | Delay between each hand's entrance |
| `ANIM_SPLIT_FADE` | `0.25s` | Split panel fade in/out |
| `ANIM_SCREEN_FLASH` | `0.2s` | Screen flash fade duration |

**`DOT_PATTERNS` Dictionary:**

Normalized Vector2 offsets (dice-face layout) for 0-4 finger dots.

**`HighlightMode` Enum:** `NONE`, `SELECTABLE`, `SOURCE`, `TARGET`

---

### `assets/bg_gradient.gdshader` (15 lines) -- Background Shader

Canvas item shader creating a vertical gradient from dark indigo (top) to near-black (bottom) with subtle procedural noise for visual depth.

---

### Scenes

| Scene | Root Node | Script | Child Structure |
|-------|-----------|--------|-----------------|
| `main.tscn` | `Control` (Main) | `main.gd` | Background ColorRect, Top bar (TurnLabel, RoundLabel, ActionsLabel, StatusLabel), OpponentHands/PlayerHands containers, RingPanel, ActionLog, Buttons (Split, EndTurn, Cancel), FlashOverlay, SplitPanel, RingSelectDialog, GameOverDialog, AITimer |
| `hand_display.tscn` | `Control` (HandDisplay) | `hand_display.gd` | No children (all custom-drawn) |
| `split_panel.tscn` | `Control` (SplitPanel) | `split_panel.gd` | No children (all custom-drawn), anchored full-screen, initially hidden |

---

## State Machine

The game flow is controlled by `ActionState` in `main.gd`:

```
                         ┌──────────────────┐
                    ┌───►│  CHOOSE_ACTION    │◄──────────────────────┐
                    │    │ (player's turn)   │                       │
                    │    └──┬──────┬─────┬───┘                       │
                    │       │      │     │                           │
                    │  click hand  │  use ring                      │
                    │       │      │     │                           │
                    │       ▼      │     ▼                           │
                    │  ┌─────────┐ │ ┌──────────────┐               │
                    │  │HIT_SEL- │ │ │RING_SELECT/  │               │
             cancel │  │ECT_TAR- │ │ │RING_DRAG     │   actions     │
                    │  │GET      │ │ │              │   remain?     │
                    │  └──┬──────┘ │ └──────┬───────┘      │        │
                    │     │        │        │              yes       │
                    ├─────┘  click │  apply ring            │        │
                    │      target  │        │              ▼        │
                    │        │     │        ├──────►CHOOSE_ACTION    │
                    │        ▼     │        │                       │
                    │   [perform   │  split pressed                 │
                    │    hit]      │        │                       │
                    │     │        │        ▼                       │
                    │     │        │  ┌───────────┐                 │
                    │     │        └─►│SPLIT_DIALOG│                │
                    │     │           │(+ Pandora) │                │
                    │     │           └──┬─────────┘                │
                    │     │              │ confirm                  │
                    │     │              ▼                          │
                    │     └──────►[action consumed]                 │
                    │                    │                          │
                    │               no actions left                 │
                    │                    │                          │
                    │                    ▼                          │
                    │             ┌──────────┐                      │
                    │             │ AI_TURN  │──── timer ───────────┘
                    │             └──────────┘
                    │
                    │    ┌──────────┐
                    └───►│GAME_OVER │ (when all hands of one side die)
                         └──────────┘
```

---

## Total Code Statistics

| File | Lines |
|------|-------|
| `enums.gd` | 118 |
| `game_state.gd` | 512 |
| `main.gd` | 693 |
| `hand_display.gd` | 255 |
| `ring_panel.gd` | 250 |
| `split_panel.gd` | 357 |
| `ai_opponent.gd` | 131 |
| `ui_constants.gd` | 91 |
| `bg_gradient.gdshader` | 15 |
| **Total** | **~2,422** |
