extends Node2D

@export var arena_size := 520.0
@export var wall_thickness := 60.0
@export var arena_offset_y := -100.0
@export var platform_width := 140.0
@export var platform_height := 20.0
@export var platform_inset := -45.0
@export var platform_height_offset := 40.0
@export var out_of_bounds_min_x := -100.0
@export var out_of_bounds_max_x := 1000.0
@export var slowmo_scale := 0.5
@export var slowmo_duration := 1.0

@onready var ball_left: SwordBall = $BallLeft
@onready var ball_right: DaggerBall = $BallRight
@onready var wall_bottom: StaticBody2D = $Walls/WallBottom
@onready var wall_top: StaticBody2D = $Walls/WallTop
@onready var wall_left: Wall = $Walls/WallLeft
@onready var wall_right: Wall = $Walls/WallRight
@onready var platform_left: StaticBody2D = $Platforms/PlatformLeft
@onready var platform_right: StaticBody2D = $Platforms/PlatformRight
@onready var left_stats: Label = $UI/LeftStats
@onready var right_stats: Label = $UI/RightStats
@onready var game_label: Label = $UI/GameLabel
@onready var wall_left_x_label: Label = $UI/WallLeftX
@onready var wall_right_x_label: Label = $UI/WallRightX

var walldist := 58

var _stats_timer := 0.0
var _game_over := false

func _ready() -> void:
	call_deferred("_layout_arena")
	_setup_balls()
	_connect_signals()
	_update_stats(ball_left.ball_id, ball_left.damage_taken, ball_left.damage)
	_update_stats(ball_right.ball_id, ball_right.damage_taken, ball_right.damage)
	_setup_game_label()

func _process(delta: float) -> void:
	if not _game_over:
		_check_out_of_bounds()
	_stats_timer += delta
	if _stats_timer >= 0.1:
		_stats_timer = 0.0
		_update_stats_for_ball(ball_left)
		_update_stats_for_ball(ball_right)

func _layout_arena() -> void:
	var viewport_size := get_viewport_rect().size
	var arena_size_value: float = arena_size
	var half: float = arena_size_value * 0.5
	var center := viewport_size * 0.5 + Vector2(0.0, arena_offset_y)

	var floor_position := Vector2(viewport_size.x * 0.5, center.y + half + wall_thickness * 0.5)
	var floor_width := viewport_size.x * 3.0
	_set_wall(wall_bottom, floor_position, Vector2(floor_width, wall_thickness))
	var ceiling_position := Vector2(viewport_size.x * 0.5, center.y - half - wall_thickness * 0.5)
	_set_wall(wall_top, ceiling_position, Vector2(floor_width, wall_thickness))
	var wall_height := arena_size_value + wall_thickness * 2.0
	_set_wall(wall_left, Vector2(0.0 - wall_thickness * 0.5 + walldist, center.y), Vector2(wall_thickness, wall_height))
	_set_wall(wall_right, Vector2(viewport_size.x + wall_thickness * 0.5 - walldist, center.y), Vector2(wall_thickness, wall_height))

	var floor_y := floor_position.y - wall_thickness * 0.5
	ball_left.position = Vector2(center.x - arena_size_value * 0.2, floor_y - ball_left.radius)
	ball_right.position = Vector2(center.x + arena_size_value * 0.2, floor_y - ball_right.radius)
	ball_left.stage_center = center
	ball_right.stage_center = center
	ball_left.floor_y = floor_y
	ball_right.floor_y = floor_y
	_update_wall_x_labels()

	var platform_y := center.y + platform_height_offset
	var left_x := center.x - arena_size_value * 0.5 + platform_inset + platform_width * 0.5
	var right_x := center.x + arena_size_value * 0.5 - platform_inset - platform_width * 0.5
	_set_platform(platform_left, Vector2(left_x, platform_y), Vector2(platform_width, platform_height))
	_set_platform(platform_right, Vector2(right_x, platform_y), Vector2(platform_width, platform_height))

func _check_out_of_bounds() -> void:
	if is_instance_valid(ball_left) and _is_out_of_bounds(ball_left.global_position.x):
		_handle_out_of_bounds(ball_left)
		return
	if is_instance_valid(ball_right) and _is_out_of_bounds(ball_right.global_position.x):
		_handle_out_of_bounds(ball_right)

func _is_out_of_bounds(x_value: float) -> bool:
	return x_value < out_of_bounds_min_x or x_value > out_of_bounds_max_x

func _handle_out_of_bounds(ball) -> void:
	_game_over = true
	if is_instance_valid(ball):
		ball.queue_free()
	_show_game_label()
	_trigger_slowmo()

func _setup_balls() -> void:
	ball_left.ball_id = 1
	ball_left.ball_color = Color(0.9, 0.2, 0.2)
	ball_right.ball_id = 2
	ball_right.ball_color = Color(0.2, 0.8, 0.2)
	ball_right.set_spin_direction(-1.0)

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
		if wall is Wall:
			visual.color = wall.normal_color
		else:
			visual.color = Color(0, 0, 0, 1)
		visual.size = size
		visual.position = -size * 0.5
	if wall.has_node("Sensor/CollisionShape2D"):
		var sensor_shape: CollisionShape2D = wall.get_node("Sensor/CollisionShape2D")
		var sensor_rect := sensor_shape.shape
		if sensor_rect is RectangleShape2D:
			var rect_sensor: RectangleShape2D = sensor_rect
			rect_sensor.size = size

func _set_platform(platform: StaticBody2D, position_value: Vector2, size: Vector2) -> void:
	var collision_shape: CollisionShape2D = platform.get_node("CollisionShape2D")
	var shape := collision_shape.shape
	if shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = shape
		rect_shape.size = size
	collision_shape.one_way_collision = true
	collision_shape.one_way_collision_margin = 8.0
	platform.position = position_value
	if platform.has_node("Visual"):
		var visual: ColorRect = platform.get_node("Visual")
		visual.color = Color(0, 0, 0, 1)
		visual.size = size
		visual.position = -size * 0.5

func _on_damage_taken_changed(ball_id: int, damage_taken: float) -> void:
	var damage_value := ball_left.damage if ball_id == 1 else ball_right.damage
	_update_stats(ball_id, damage_taken, damage_value)

func _on_damage_changed(ball_id: int, damage: float) -> void:
	var damage_taken_value := ball_left.damage_taken if ball_id == 1 else ball_right.damage_taken
	_update_stats(ball_id, damage_taken_value, damage)

func _update_stats(ball_id: int, damage_taken: float, damage: float) -> void:
	var rotation_value := ball_left.get_spin_speed() if ball_id == 1 else ball_right.get_spin_speed()
	var speed_value := ball_left.linear_velocity.length() if ball_id == 1 else ball_right.linear_velocity.length()
	var text := "Damage Taken: %.1f\nDamage: %.1f\nSpin: %.2f\nSpeed: %.1f" % [damage_taken, damage, rotation_value, speed_value]
	if ball_id == 1:
		left_stats.text = text
	else:
		right_stats.text = text

func _update_stats_for_ball(ball) -> void:
	if not is_instance_valid(ball):
		return
	_update_stats(ball.ball_id, ball.damage_taken, ball.damage)

func _setup_game_label() -> void:
	game_label.text = "GAME!"
	game_label.visible = false
	game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_label.add_theme_font_size_override("font_size", 64)
	game_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	game_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	game_label.add_theme_constant_override("outline_size", 8)
	game_label.anchor_left = 0.0
	game_label.anchor_top = 0.0
	game_label.anchor_right = 1.0
	game_label.anchor_bottom = 1.0
	game_label.offset_left = 0.0
	game_label.offset_top = 0.0
	game_label.offset_right = 0.0
	game_label.offset_bottom = 0.0

func _show_game_label() -> void:
	game_label.visible = true

func _trigger_slowmo() -> void:
	var previous_scale := Engine.time_scale
	Engine.time_scale = slowmo_scale
	var timer := get_tree().create_timer(slowmo_duration, true, false, true)
	timer.timeout.connect(func() -> void:
		Engine.time_scale = previous_scale
	)

func _update_wall_x_labels() -> void:
	wall_left_x_label.text = "Wall L X: %.1f" % wall_left.global_position.x
	wall_right_x_label.text = "Wall R X: %.1f" % wall_right.global_position.x
