class_name DesignTokens
extends RefCounted

# SPEC §6: all dimensions are base-viewport pixels.
const BG: Color = Color("0e0f12")
const SURFACE: Color = Color("1a1c21")
const SURFACE_RAISED: Color = Color("252830")
const SCRIM: Color = Color(0, 0, 0, 0.6)
const TEXT_PRIMARY: Color = Color("f2f3f5")
const TEXT_SECONDARY: Color = Color("a4a9b4")
const ACCENT: Color = Color("ffc83d")
const ACCENT_INK: Color = Color("1a1400")
const DANGER: Color = Color("ff5c5c")
const SUCCESS: Color = Color("4cd38a")
const BAR: Color = Color("1e6bff")
const DOUBLE_BAR: Color = Color("8a3ffc")
const REPEAT_BAR: Color = Color("ff7a00")
const LONG_REST: Color = Color("00a86b")
const LONG_REST_BOTTOM: Color = Color("00a3a3")
const CAPTION_SIZE: int = 32
const BODY_SIZE: int = 40
const BUTTON_SIZE: int = 44
const HEADING_SIZE: int = 56
const TITLE_SIZE: int = 72
const SPACE_12: int = 12
const SPACE_24: int = 24
const SPACE_36: int = 36
const SPACE_48: int = 48
const SPACE_72: int = 72
const RADIUS: int = 24
const SHEET_RADIUS: int = 36
const HIT_SIZE: int = 144
const ICON_SIZE: int = 96
const ICON_STROKE: int = 4
const SIDE_MARGIN: int = 24
const GESTURE_MARGIN: int = 96
const SCREEN_FADE: float = 0.15
const SHEET_SLIDE: float = 0.2
const MAX_MOTION: float = 0.25
const SNACKBAR_DURATION: float = 5.0
const SETTINGS_SAVED_DURATION: float = SNACKBAR_DURATION / 3.0
const SPINNER_PERIOD: float = 1.0
const SPINNER_SWEEP: float = TAU * 0.75
const SPINNER_SEGMENTS: int = 48
const BASE_VIEWPORT: Vector2 = Vector2(1080, 1920)
const MIN_BUTTON_HEIGHT: float = HIT_SIZE
const GAP: int = SPACE_24
const HAPTIC_TAP_MS: int = 20
const HAPTIC_HEAVY_MS: int = 50
# Explicit text/background pairings; detection colours are outlines on paper, not text.
const TEXT_PAIRS: Dictionary = {
	"primary/bg": [TEXT_PRIMARY, BG],
	"primary/surface": [TEXT_PRIMARY, SURFACE],
	"primary/raised": [TEXT_PRIMARY, SURFACE_RAISED],
	"secondary/bg": [TEXT_SECONDARY, BG],
	"secondary/surface": [TEXT_SECONDARY, SURFACE],
	"secondary/raised": [TEXT_SECONDARY, SURFACE_RAISED],
	"accent ink/accent": [ACCENT_INK, ACCENT],
	"accent ink/danger": [ACCENT_INK, DANGER],
	"danger/surface": [DANGER, SURFACE],
	"success/surface": [SUCCESS, SURFACE],
}

# Capture screen.
const SHUTTER_SIZE: int = 216
const THUMBNAIL_SIZE: int = 144
const THUMBNAIL_LONG_SIDE: int = 256
const CAPTURE_PANEL_FRACTION: float = 0.45
const CAMERA_SURFACE: Color = Color(0.10196, 0.10980, 0.12941, 0.85)
const CAMERA_TOP_SURFACE: Color = Color(0.10196, 0.10980, 0.12941, 0.6)
const CAPTURE_WHITE: Color = Color.WHITE
const FLASH_DURATION: float = 0.08
const PHOTO_PREVIEW_HEIGHT: int = 480

# Detection overlays (screen pixels, compensated for viewer zoom).
const MARKER_FILL_ALPHA: float = 0.25
const MARKER_OUTLINE: float = 2.0
const MARKER_SELECTION: float = 6.0
const MARKER_TEXT_SIZE: int = 30
const MARKER_PICK_RADIUS: float = 96.0
const MARKER_TAP_SLOP: float = 12.0
const MARKER_TAP_MS: int = 400

# Results viewer.
const LINE_NUMBER_LEFT: float = 15.0
const LINE_NUMBER_HEIGHT_RATIO: float = 0.7
const LINE_NUMBER_MIN_SIZE: int = 20
const LINE_NUMBER_MAX_SIZE: int = 72
const LINE_NUMBER_HALO: int = 3
const RESULTS_ARROW_ALPHA: float = 0.6
const RESULTS_IDLE_ALPHA: float = 0.3
const RESULTS_IDLE_SECONDS: float = 2.0
const RESULTS_SPINNER_DELAY_MS: int = 100

const RESULTS_TOP_SURFACE: Color = Color(0.14510, 0.15686, 0.18824, 0.85)

# Camera alignment guides.
const CAPTURE_GUIDE_COUNT: int = 6
const CAPTURE_GUIDE_WIDTH: float = 2.0
const CAPTURE_GUIDE_COLOR: Color = Color(1, 1, 1, 0.45)
