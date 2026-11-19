extends CanvasLayer
## Schwarzblende für Szenenwechsel. Autoload "Fade".

var _rect: ColorRect


func _ready() -> void:
	layer = 90
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.position = Vector2(-50, -50)
	_rect.size = Vector2(500, 330)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)


func fade_out(time: float = 0.25) -> void:
	var t := create_tween()
	t.tween_property(_rect, "modulate:a", 1.0, time)
	await t.finished


func fade_in(time: float = 0.25) -> void:
	var t := create_tween()
	t.tween_property(_rect, "modulate:a", 0.0, time)
	await t.finished


## Kurzes Aufblitzen zu Beginn eines Kampfes.
func flash() -> void:
	_rect.color = Color.WHITE
	var t := create_tween()
	for i in 2:
		t.tween_property(_rect, "modulate:a", 0.8, 0.06)
		t.tween_property(_rect, "modulate:a", 0.0, 0.06)
	await t.finished
	_rect.color = Color.BLACK
