extends Node2D

@export var arena_size := 520.0
@export var wall_thickness := 18.0

@onready var ball_left: SwordBall = $BallLeft
@onready var ball_right: SwordBall = $BallRight
@onready var wall_bottom: StaticBody2D = $Walls/WallBottom
@onready var left_stats: Label = $UI/LeftStats
@onready var right_stats: Label = $UI/RightStats

func _ready() -> void:
	call_deferred("_layout_arena")
	_setup_balls()
	_connect_signals()
	_update_stats(ball_left.ball_id, ball_left.damage_taken, ball_left.damage)
	_update_stats(ball_right.ball_id, ball_right.damage_taken, ball_right.damage)

func _layout_arena() -> void:
	var viewport_size := get_viewport_rect().size
	var arena_size_value: float = arena_size
	var half: float = arena_size_value * 0.5
	var center := viewport_size * 0.5

	var floor_position := Vector2(viewport_size.x * 0.5, center.y + half + wall_thickness * 0.5)
	var floor_width := viewport_size.x * 3.0
	_set_wall(wall_bottom, floor_position, Vector2(floor_width, wall_thickness))

	var floor_y := floor_position.y - wall_thickness * 0.5
	ball_left.position = Vector2(center.x - arena_size_value * 0.2, floor_y - ball_left.radius)
	ball_right.position = Vector2(center.x + arena_size_value * 0.2, floor_y - ball_right.radius)
	ball_left.stage_center = center
	ball_right.stage_center = center
	ball_left.floor_y = floor_y
	ball_right.floor_y = floor_y

func _setup_balls() -> void:
	ball_left.ball_id = 1
	ball_left.ball_color = Color(0.9, 0.2, 0.2)
	ball_right.ball_id = 2
	ball_right.ball_color = Color(0.2, 0.8, 0.2)
	ball_right.sword_rotation_speed = -abs(ball_right.sword_rotation_speed)

func _connect_signals() -> void:
	ball_left.damage_taken_changed.connect(_on_damage_taken_changed)
	ball_left.damage_changed.connect(_on_damage_changed)
	ball_right.damage_taken_changed.connect(_on_damage_taken_changed)
	ball_right.damage_changed.connect(_on_damage_changed)

func _set_wall(wall: StaticBody2D, position_value: Vector2, size: Vector2) -> void:
	var collision_shape: CollisionShape2D = wall.get_node("CollisionShape2D")
	var shape := collision_shape.shape
	if shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = shape
		rect_shape.size = size
	wall.position = position_value
	wall.collision_layer = 1
	wall.collision_mask = 1
	var material := PhysicsMaterial.new()
	material.bounce = 0.0
	material.friction = 0.0
	wall.physics_material_override = material
	if wall.has_node("Visual"):
		var visual: ColorRect = wall.get_node("Visual")
		visual.color = Color(0, 0, 0)
		visual.size = size
		visual.position = -size * 0.5

func _on_damage_taken_changed(ball_id: int, damage_taken: int) -> void:
	var damage_value := ball_left.damage if ball_id == 1 else ball_right.damage
	_update_stats(ball_id, damage_taken, damage_value)

func _on_damage_changed(ball_id: int, damage: int) -> void:
	var damage_taken_value := ball_left.damage_taken if ball_id == 1 else ball_right.damage_taken
	_update_stats(ball_id, damage_taken_value, damage)

func _update_stats(ball_id: int, damage_taken: int, damage: int) -> void:
	var text := "Damage Taken: %d\nDamage: %d" % [damage_taken, damage]
	if ball_id == 1:
		left_stats.text = text
	else:
		right_stats.text = text
