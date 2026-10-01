extends Control
## A 2D cartoon portrait of a citizen (the same "bean" look as the 3D
## characters). Colors and face are derived from the citizen id, so the same
## person always looks the same. Some visible symptoms show on the face.

const SKIN_TONES: Array[Color] = [
	Color(1.0, 0.82, 0.65), Color(0.90, 0.68, 0.50), Color(0.70, 0.50, 0.35), Color(0.50, 0.35, 0.25),
]
const SHIRTS: Array[Color] = [
	Color(0.55, 0.30, 0.75), Color(0.95, 0.45, 0.25), Color(0.25, 0.55, 0.90),
	Color(0.95, 0.80, 0.25), Color(0.35, 0.70, 0.45), Color(0.85, 0.35, 0.55),
]
const INK := Color(0.12, 0.10, 0.15)

var citizen: Dictionary = {}:
	set(value):
		citizen = value
		queue_redraw()
## Symptoms the examiner has found (drawn on the face: red eyes, grey skin...).
var revealed: Array = []:
	set(value):
		revealed = value
		queue_redraw()


func _draw() -> void:
	if citizen.is_empty():
		return
	var id: int = citizen.get("id", 0)
	var w := size.x
	var h := size.y
	var skin: Color = SKIN_TONES[id % SKIN_TONES.size()]
	if revealed.has("grey_skin"):
		skin = skin.lerp(Color(0.55, 0.62, 0.55), 0.6)
	var shirt: Color = SHIRTS[floori(id / 3.0) % SHIRTS.size()]
	# Body bean (shirt) and face.
	var body := Rect2(w * 0.18, h * 0.30, w * 0.64, h * 0.75)
	_rounded(body, w * 0.32, shirt)
	var face := Rect2(w * 0.26, h * 0.12, w * 0.48, h * 0.42)
	_rounded(face, w * 0.22, skin)
	# Eyes (one bigger, friendslop).
	var eye_color := Color(1.0, 0.55, 0.55) if revealed.has("red_eyes") else Color.WHITE
	var big := id % 2 == 0
	for side in [-1.0, 1.0]:
		var r := w * (0.075 if (side < 0) == big else 0.055)
		var c := Vector2(w * 0.5 + side * w * 0.1, h * 0.29)
		draw_circle(c, r + 2.0, INK)
		draw_circle(c, r, eye_color)
		draw_circle(c + Vector2(side * 1.5, 1.0), r * 0.45, INK)
	# Mouth: worried if they look sick.
	var mouth_y := h * 0.43
	var frown := revealed.any(func(s: String) -> bool: return s in ["fever", "shaking", "bite"])
	var points := PackedVector2Array()
	for i in 7:
		var t := i / 6.0
		var bend := sin(t * PI) * h * 0.03 * (-1.0 if frown else 1.0)
		points.append(Vector2(w * 0.42 + t * w * 0.16, mouth_y + bend))
	draw_polyline(points, INK, 3.0, true)
	if revealed.has("fever"):
		draw_circle(Vector2(w * 0.33, h * 0.36), w * 0.04, Color(1.0, 0.35, 0.35, 0.6))
		draw_circle(Vector2(w * 0.67, h * 0.36), w * 0.04, Color(1.0, 0.35, 0.35, 0.6))
	if revealed.has("bite"):
		draw_arc(Vector2(w * 0.25, h * 0.75), w * 0.05, 0, PI, 8, Color(0.75, 0.05, 0.10), 4.0)


func _rounded(rect: Rect2, radius: float, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(int(radius))
	draw_style_box(style, rect)
