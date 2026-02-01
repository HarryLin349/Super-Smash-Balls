extends Node2D

@export var arena_size := 520.0
@export var wall_thickness := 18.0

@onready var ball_left: Ball = $BallLeft
@onready var ball_right: Ball = $BallRight
@onready var wall_top: StaticBody2D = $Walls/WallTop
@onready var wall_bottom: StaticBody2D = $Walls/WallBottom
@onready var wall_left: StaticBody2D = $Walls/WallLeft
@onready var wall_right: StaticBody2D = $Walls/WallRight
@onready var left_stats: Label = $UI/LeftStats
@onready var right_stats: Label = $UI/RightStats

func _ready() -> void:
	call_deferred("_layout_arena")
	_setup_balls()
	_connect_signals()
	_update_stats(ball_left.ball_id, ball_left.hp, ball_left.damage)
	_update_stats(ball_right.ball_id, ball_right.hp, ball_right.damage)

func _layout_arena() -> void:
	var viewport_size := get_viewport_rect().size
	var arena_size_value: float = arena_size
	var half: float = arena_size_value * 0.5
	var center := viewport_size * 0.5

	_set_wall(wall_top, center + Vector2(0, -half - wall_thickness * 0.5), Vector2(arena_size_value + wall_thickness * 2.0, wall_thickness))
	_set_wall(wall_bottom, center + Vector2(0, half + wall_thickness * 0.5), Vector2(arena_size_value + wall_thickness * 2.0, wall_thickness))
	_set_wall(wall_left, center + Vector2(-half - wall_thickness * 0.5, 0), Vector2(wall_thickness, arena_size_value + wall_thickness * 2.0))
	_set_wall(wall_right, center + Vector2(half + wall_thickness * 0.5, 0), Vector2(wall_thickness, arena_size_value + wall_thickness * 2.0))

	ball_left.position = center + Vector2(-arena_size_value * 0.2, -arena_size_value * 0.15)
	ball_right.position = center + Vector2(arena_size_value * 0.2, -arena_size_value * 0.15)

func _setup_balls() -> void:
	ball_left.ball_id = 1
	ball_left.ball_color = Color(0.9, 0.2, 0.2)
	ball_right.ball_id = 2
	ball_right.ball_color = Color(0.2, 0.8, 0.2)
	ball_right.sword_rotation_speed = -abs(ball_right.sword_rotation_speed)

func _connect_signals() -> void:
	ball_left.hp_changed.connect(_on_hp_changed)
	ball_left.damage_changed.connect(_on_damage_changed)
	ball_right.hp_changed.connect(_on_hp_changed)
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
	material.bounce = 1.0
	material.friction = 0.0
	wall.physics_material_override = material
	if wall.has_node("Visual"):
		var visual: ColorRect = wall.get_node("Visual")
		visual.color = Color(0, 0, 0)
		visual.size = size
		visual.position = -size * 0.5

func _on_hp_changed(ball_id: int, hp: int) -> void:
	var damage_value := ball_left.damage if ball_id == 1 else ball_right.damage
	_update_stats(ball_id, hp, damage_value)

func _on_damage_changed(ball_id: int, damage: int) -> void:
	var hp_value := ball_left.hp if ball_id == 1 else ball_right.hp
	_update_stats(ball_id, hp_value, damage)

func _update_stats(ball_id: int, hp: int, damage: int) -> void:
	var text := "HP: %d\nDamage: %d" % [hp, damage]
	if ball_id == 1:
		left_stats.text = text
	else:
		right_stats.text = text
