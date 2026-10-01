extends RefCounted
## The cartoon UI theme (H-008): cream paper panels with thick dark outlines,
## chunky rounded buttons in bright colors, big friendly text.
## Usage: some_control.theme = UITheme.cartoon()  (cached, so call it freely).

const INK := Color(0.12, 0.10, 0.15)
const PAPER := Color(1.0, 0.97, 0.90)
const PAPER_DARK := Color(0.93, 0.88, 0.78)
const BUTTON := Color(1.0, 0.82, 0.30)
const GOOD := Color(0.45, 0.85, 0.40)
const WARN := Color(1.0, 0.78, 0.25)
const BAD := Color(1.0, 0.42, 0.38)
const DESK := Color(0.55, 0.36, 0.22)

static var _cached: Theme


static func cartoon() -> Theme:
	if _cached:
		return _cached
	var theme := Theme.new()
	theme.default_font_size = 20

	theme.set_stylebox("panel", "PanelContainer", box(PAPER, 4, 16, 6))
	theme.set_stylebox("panel", "Panel", box(PAPER, 4, 16, 6))
	theme.set_color("font_color", "Label", INK)

	theme.set_stylebox("normal", "Button", box(BUTTON, 3, 12, 4))
	theme.set_stylebox("hover", "Button", box(BUTTON.lightened(0.25), 3, 12, 4))
	theme.set_stylebox("pressed", "Button", box(BUTTON.darkened(0.15), 3, 12, 1))
	theme.set_stylebox("disabled", "Button", box(Color(0.75, 0.73, 0.70), 3, 12, 0))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", INK)
	theme.set_color("font_disabled_color", "Button", Color(0.35, 0.33, 0.33))
	theme.set_font_size("font_size", "Button", 20)

	var bar_bg := box(PAPER_DARK, 3, 8, 0)
	var bar_fill := box(GOOD, 0, 8, 0)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	theme.set_color("font_color", "ProgressBar", INK)

	theme.set_stylebox("normal", "LineEdit", box(Color.WHITE, 3, 8, 0))
	theme.set_stylebox("focus", "LineEdit", box(Color(1.0, 0.98, 0.85), 3, 8, 0))
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", Color(0.55, 0.52, 0.50))
	theme.set_color("caret_color", "LineEdit", INK)
	theme.set_font_size("font_size", "LineEdit", 22)
	theme.set_stylebox("slider", "HSlider", box(PAPER_DARK, 2, 6, 0))
	_cached = theme
	return theme


## A rounded, outlined panel style. `shadow` drops a hard cartoon shadow.
static func box(fill: Color, border := 3, radius := 12, shadow := 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = INK
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(10 + border)
	if shadow > 0:
		style.shadow_color = Color(0, 0, 0, 0.35)
		style.shadow_size = 1
		style.shadow_offset = Vector2(shadow, shadow)
	return style


## A colored button (green = good, red = bad, ...).
static func colored_button(text: String, fill: Color, font_size := 22) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", box(fill, 3, 12, 4))
	button.add_theme_stylebox_override("hover", box(fill.lightened(0.2), 3, 12, 4))
	button.add_theme_stylebox_override("pressed", box(fill.darkened(0.15), 3, 12, 1))
	button.add_theme_font_size_override("font_size", font_size)
	return button


## A label with a size and optional color.
static func label(text: String, font_size := 20, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
