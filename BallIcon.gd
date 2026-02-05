extends Node2D
class_name BallIcon

@export var radius := 20.0
@export var color := Color(1, 1, 1, 1)
@export var outline_thickness := 3.0
@export var outline_color := Color(0, 0, 0, 1)
@export var gradient_tilt_deg := 20.0
@export var gradient_darkening := 0.18
@export var gradient_blue_boost := 0.15

func _ready() -> void:
	queue_redraw()

func set_color(value: Color) -> void:
	color = value
	queue_redraw()

func _draw() -> void:
	if outline_thickness > 0.0:
		draw_circle(Vector2.ZERO, radius + outline_thickness, outline_color)
	_draw_gradient_ball()

func _draw_gradient_ball() -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var segments := 40
	var tilt := deg_to_rad(gradient_tilt_deg)
	for i in range(segments):
		var t := float(i) / float(segments)
		var ang := t * TAU
		var p := Vector2(cos(ang), sin(ang)) * radius
		points.append(p)
		# Rotate point to evaluate gradient along the tilted axis.
		var rp := p.rotated(-tilt)
		var grad_t := clampf((rp.y / radius + 1.0) * 0.5, 0.0, 1.0)
		var bottom_tint := Color(0.0, 0.0, gradient_blue_boost, 0.0)
		var darkened := color.darkened(gradient_darkening)
		var bottom_color := darkened + bottom_tint
		colors.append(color.lerp(bottom_color, grad_t))
	draw_polygon(points, colors)
