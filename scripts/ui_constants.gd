class_name UIConstants

# === OWNER COLORS ===
const COLOR_PLAYER := Color(0.0, 0.9, 1.0)       # Cyan
const COLOR_OPPONENT := Color(1.0, 0.2, 0.6)      # Magenta
const COLOR_PLAYER_DIM := Color(0.0, 0.4, 0.5)
const COLOR_OPPONENT_DIM := Color(0.5, 0.1, 0.3)

# === RING POSITIONS ===
# Angles in degrees for ring indicators around the hand circle (for LEFT hand)
# 0° = right, 90° = up, 180° = left, 270° = down
const RING_ANGLES_LEFT := {
	"INDEX": 120.0,      # Top-left area (index finger side)
	"MIDDLE": 90.0,      # Top area
	"RING": 60.0,        # Top-right area
	"PINKY": 30.0,       # Right area (pinky side)
}

# For RIGHT hands, mirror the angles horizontally
const RING_ANGLES_RIGHT := {
	"INDEX": 60.0,       # Top-right area (index finger side)
	"MIDDLE": 90.0,      # Top area (same as left)
	"RING": 120.0,       # Top-left area
	"PINKY": 150.0,      # Left area (pinky side)
}

const RING_INDICATOR_RADIUS := 10.0      # Size of ring indicator circles
const RING_INDICATOR_DISTANCE := 90.0    # Distance from hand center (outside the glow zone)

# === HAND DISPLAY COLORS ===
const COLOR_BG_ALIVE := Color(0.1, 0.1, 0.15)
const COLOR_BG_DEAD := Color(0.08, 0.08, 0.08)
const COLOR_DOT_DEFAULT := Color(0.9, 0.95, 1.0)
const COLOR_DOT_DEAD := Color(0.3, 0.3, 0.3)
const COLOR_HIGHLIGHT_SOURCE := Color(1.0, 1.0, 0.6)
const COLOR_HIT_FLASH := Color(1.0, 1.0, 1.0, 0.8)
const COLOR_DEATH_OVERLAY := Color(0.0, 0.0, 0.0, 0.6)

# === UI COLORS ===
const COLOR_PANEL_BG := Color(0.06, 0.06, 0.1, 0.9)
const COLOR_BUTTON_BG := Color(0.15, 0.15, 0.25)
const COLOR_BUTTON_HOVER := Color(0.2, 0.2, 0.35)
const COLOR_BUTTON_DISABLED := Color(0.1, 0.1, 0.12)
const COLOR_CONFIRM := Color(0.2, 0.8, 0.4)
const COLOR_CANCEL := Color(0.8, 0.2, 0.3)

# === DOT PATTERNS ===
# Normalized positions (-1 to 1 range) for finger dot layouts (like dice faces)
# Each pattern is an array of Vector2 offsets from center
const DOT_PATTERNS := {
	0: [],
	1: [Vector2(0, 0)],
	2: [Vector2(-0.35, 0), Vector2(0.35, 0)],
	3: [Vector2(0, -0.35), Vector2(-0.35, 0.3), Vector2(0.35, 0.3)],
	4: [Vector2(-0.35, -0.35), Vector2(0.35, -0.35), Vector2(-0.35, 0.35), Vector2(0.35, 0.35)],
}

# === SIZES ===
const HAND_SIZE := Vector2(280, 360)
const DOT_RADIUS := 14.0
const DOT_AREA_RADIUS := 50.0  # Area within which dots are placed
const HAND_CORNER_RADIUS := 12.0
const HAND_BORDER_WIDTH := 3.0

const RING_SLOT_SIZE := Vector2(70, 70)
const RING_SLOT_RADIUS := 30.0

# === ANIMATION DURATIONS ===
const ANIM_HIT_FLASH := 0.3
const ANIM_DEATH_FADE := 0.4
const ANIM_PULSE_SPEED := 2.0      # Cycles per second for breathing pulse
const ANIM_ENTRANCE_DURATION := 0.4
const ANIM_ENTRANCE_STAGGER := 0.1
const ANIM_SPLIT_FADE := 0.25
const ANIM_SCREEN_FLASH := 0.2
const ANIM_HIT_LUNGE_OUT := 0.12    # Lunge toward target
const ANIM_HIT_LUNGE_BACK := 0.08   # Snap back to origin

# === HIGHLIGHT MODES ===
enum HighlightMode {
	NONE,
	SELECTABLE,
	SOURCE,
	TARGET,
}
