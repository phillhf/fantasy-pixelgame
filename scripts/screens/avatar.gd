class_name Avatar
extends Node2D
## Platzhalter-Figur auf der Karte (16 × 16). Wird später durch echte Grafik ersetzt.

var body_color := Color("#3a6fd8")
var kind := "person"  # person, shrine, sign
var facing := Vector2i.DOWN:
	set(v):
		facing = v
		queue_redraw()
var step := false:
	set(v):
		step = v
		queue_redraw()


func _draw() -> void:
	match kind:
		"shrine":
			draw_rect(Rect2(4, 4, 8, 11), Color("#9a9a9a"))
			draw_rect(Rect2(3, 3, 10, 2), Color("#6a6a6a"))
			draw_rect(Rect2(6, 7, 4, 4), Color("#3a3a3a"))
			draw_circle(Vector2(8, 9), 1.5, Color("#ffd860"))
		"sign":
			draw_rect(Rect2(7, 8, 2, 8), Color("#5a3a20"))
			draw_rect(Rect2(2, 3, 12, 6), Color("#a87a48"))
			draw_line(Vector2(4, 5), Vector2(12, 5), Color("#5a3a20"))
			draw_line(Vector2(4, 7), Vector2(10, 7), Color("#5a3a20"))
		_:
			_draw_person()


func _draw_person() -> void:
	var outline := Color(0.05, 0.05, 0.08)
	var skin := Color("#f0c8a0")
	# Schatten
	draw_rect(Rect2(4, 14, 8, 2), Color(0, 0, 0, 0.25))
	# Beine
	var lo := 1 if step else 0
	draw_rect(Rect2(5, 12 + lo, 2, 3 - lo), outline)
	draw_rect(Rect2(9, 12 + (1 - lo), 2, 3 - (1 - lo)), outline)
	# Körper
	draw_rect(Rect2(4, 7, 8, 6), outline)
	draw_rect(Rect2(5, 8, 6, 4), body_color)
	# Kopf
	draw_rect(Rect2(4, 1, 8, 7), outline)
	draw_rect(Rect2(5, 2, 6, 5), skin)
	draw_rect(Rect2(5, 1, 6, 2), body_color.darkened(0.4))
	# Blickrichtung
	match facing:
		Vector2i.DOWN:
			draw_rect(Rect2(6, 4, 1, 1), outline)
			draw_rect(Rect2(9, 4, 1, 1), outline)
		Vector2i.LEFT:
			draw_rect(Rect2(5, 4, 1, 1), outline)
		Vector2i.RIGHT:
			draw_rect(Rect2(10, 4, 1, 1), outline)
		Vector2i.UP:
			draw_rect(Rect2(5, 2, 6, 4), body_color.darkened(0.4))
