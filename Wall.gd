extends StaticBody2D
class_name Wall

@export var max_hp := 100
@export var flash_time := 0.12
@export var normal_color := Color(0.1, 0.1, 0.1, 1)
@export var bounce_color := Color(1, 1, 1, 1)
@export var damage_color := Color(1, 0.6, 0.2, 1)

@onready var visual: ColorRect = $Visual
@onready var sensor: Area2D = $Sensor
@onready var hp_label: Label = $Visual/HpLabel

var hp := 0

func _ready() -> void:
	hp = max_hp
	visual.color = normal_color
	sensor.body_entered.connect(_on_sensor_body_entered)
	_update_hp_label()
	if hp_label != null:
		hp_label.anchor_left = 0.0
		hp_label.anchor_top = 0.0
		hp_label.anchor_right = 1.0
		hp_label.anchor_bottom = 1.0
		hp_label.offset_left = 0.0
		hp_label.offset_top = 0.0
		hp_label.offset_right = 0.0
		hp_label.offset_bottom = 0.0
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp_label.add_theme_font_size_override("font_size", 28)
		hp_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		hp_label.z_index = 10
		hp_label.z_as_relative = false

func _on_sensor_body_entered(body: Node) -> void:
	if not (body is Ball):
		return
	var ball: Ball = body
	var speed := ball.linear_velocity.length()
	if ball.is_in_hitstun():
		var damage := int(ceil(abs(speed / 60.0)))
		if damage > 0:
			hp -= damage
			if hp <= 0:
				_disable_wall()
			else:
				_flash(damage_color)
				_update_hp_label()
		else:
			_flash(bounce_color)
	else:
		_flash(bounce_color)

func _flash(color: Color) -> void:
	visual.color = color
	var tween := get_tree().create_tween()
	tween.tween_property(visual, "color", normal_color, flash_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _disable_wall() -> void:
	visual.visible = false
	if hp_label != null:
		hp_label.visible = false
	collision_layer = 0
	collision_mask = 0
	if has_node("CollisionShape2D"):
		var collision_shape: CollisionShape2D = $CollisionShape2D
		collision_shape.disabled = true
	if has_node("Sensor"):
		sensor.monitoring = false
		sensor.monitorable = false

func _update_hp_label() -> void:
	if hp_label == null:
		return
	hp_label.text = str(hp)
