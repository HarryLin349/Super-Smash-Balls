extends StaticBody2D
class_name Wall

@export var pass_through_speed := 420.0
@export var pass_through_time := 0.5
@export var flash_time := 0.12
@export var normal_color := Color(0, 0, 0, 0)
@export var bounce_color := Color(1, 1, 1, 1)
@export var pass_color := Color(1, 0, 0, 1)

@onready var visual: ColorRect = $Visual
@onready var sensor: Area2D = $Sensor

static var _slowmo_active := false

func _ready() -> void:
	visual.color = normal_color
	sensor.body_entered.connect(_on_sensor_body_entered)

func _on_sensor_body_entered(body: Node) -> void:
	if not (body is Ball):
		return
	var ball: Ball = body
	var speed := ball.linear_velocity.length()
	if ball.is_in_hitstun() and speed >= pass_through_speed:
		_allow_pass_through(ball)
		_flash(pass_color)
		_slowmo()
	else:
		_flash(bounce_color)

func _allow_pass_through(ball: Ball) -> void:
	ball.add_collision_exception_with(self)
	var timer := get_tree().create_timer(0.15)
	timer.timeout.connect(func() -> void:
		ball.remove_collision_exception_with(self)
	)

func _flash(color: Color) -> void:
	visual.color = color
	# Debug: keep a faint trace so we can see the wall flash in action.
	if color == normal_color:
		visual.color = Color(1, 1, 1, 0.05)
	var tween := get_tree().create_tween()
	tween.tween_property(visual, "color", normal_color, flash_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _slowmo() -> void:
	if _slowmo_active:
		return
	_slowmo_active = true
	Engine.time_scale = 0.5
	var timer := get_tree().create_timer(pass_through_time, true, false, true)
	timer.timeout.connect(func() -> void:
		Engine.time_scale = 1.0
		_slowmo_active = false
	)
