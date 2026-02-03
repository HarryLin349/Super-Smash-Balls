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
@onready var arena_background: ColorRect = $ArenaBackground
@onready var platform_left: StaticBody2D = $Platforms/PlatformLeft
@onready var platform_right: StaticBody2D = $Platforms/PlatformRight
@onready var sfx_ko: AudioStreamPlayer = $SfxKo
@onready var sfx_victory: AudioStreamPlayer = $SfxVictory
@onready var game_label: Label = $UI/GameLabel

var walldist := 58

var _game_over := false

func _ready() -> void:
	call_deferred("_layout_arena")
	_setup_balls()
	_connect_signals()
	_setup_game_label()

func _process(delta: float) -> void:
	if not _game_over:
		_check_out_of_bounds()

func _layout_arena() -> void:
	var viewport_size := get_viewport_rect().size
	var arena_size_value: float = arena_size
	var half: float = arena_size_value * 0.5
	var center := viewport_size * 0.5 + Vector2(0.0, arena_offset_y)

	var floor_position := Vector2(viewport_size.x * 0.5, center.y + half + wall_thickness * 0.5)
	var floor_width := viewport_size.x - 120
	_set_wall(wall_bottom, floor_position, Vector2(floor_width, wall_thickness))
	var ceiling_position := Vector2(viewport_size.x * 0.5, center.y - half - wall_thickness * 0.5)
	_set_wall(wall_top, ceiling_position, Vector2(floor_width, wall_thickness))
	var wall_height := arena_size_value + wall_thickness * 2.0
	_set_wall(wall_left, Vector2(0.0 - wall_thickness * 0.5 + walldist, center.y), Vector2(wall_thickness, wall_height))
	_set_wall(wall_right, Vector2(viewport_size.x + wall_thickness * 0.5 - walldist, center.y), Vector2(wall_thickness, wall_height))

	if arena_background != null:
		arena_background.position = center - Vector2(arena_size_value, arena_size_value * 0.5)
		arena_background.size = Vector2(arena_size_value *2, arena_size_value)

	var floor_y := floor_position.y - wall_thickness * 0.5
	ball_left.position = Vector2(center.x - arena_size_value * 0.2, floor_y - ball_left.radius)
	ball_right.position = Vector2(center.x + arena_size_value * 0.2, floor_y - ball_right.radius)
	ball_left.stage_center = center
	ball_right.stage_center = center
	ball_left.floor_y = floor_y
	ball_right.floor_y = floor_y

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
		var effect_color: Color = ball.ball_color
		var ball_pos: Vector2 = ball.global_position
		if sfx_ko != null:
			sfx_ko.play()
		ball.queue_free()
		_spawn_ko_effect(effect_color, ball_pos)
		if sfx_victory != null:
			sfx_victory.play()
	_show_game_label()
	_trigger_slowmo()

func _setup_balls() -> void:
	ball_left.ball_id = 1
	ball_left.ball_color = Color(0.9, 0.2, 0.2)
	ball_right.ball_id = 2
	ball_right.ball_color = Color(0.2, 0.8, 0.2)
	ball_right.set_spin_direction(-1.0)

func _connect_signals() -> void:
	pass

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
	if wall == wall_bottom and wall.has_node("FloorSprite"):
		var floor_sprite: Sprite2D = wall.get_node("FloorSprite")
		var tex := floor_sprite.texture
		if tex != null:
			var tex_size := tex.get_size()
			if tex_size.x > 0.0:
				var scale_value := (arena_size + 130) / tex_size.x
				floor_sprite.scale = Vector2(scale_value, scale_value)
		floor_sprite.position = Vector2(0, 50)
		floor_sprite.z_index = -5
		if wall.has_node("Visual"):
			var bottom_visual: ColorRect = wall.get_node("Visual")
			bottom_visual.color = Color(0, 0, 0, 0)
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
	pass

func _on_damage_changed(ball_id: int, damage: float) -> void:
	pass

func _setup_game_label() -> void:
	game_label.text = "GAME!"
	game_label.visible = false
	game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_label.add_theme_font_size_override("font_size", 64)
	game_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	game_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	game_label.add_theme_constant_override("outline_size", 24)
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


func _spawn_ko_effect(base_color: Color, position_value: Vector2) -> void:
	var host := get_tree().current_scene if get_tree().current_scene != null else self
	var effect := Node2D.new()
	effect.z_index = 20
	host.add_child(effect)

	var viewport_center_x := get_viewport_rect().size.x * 0.5
	var distance_to_center : int = abs(position_value.x - viewport_center_x)
	var x := clampf(position_value.x, out_of_bounds_min_x, out_of_bounds_max_x)
	effect.global_position = Vector2(x, position_value.y)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spikes := 18
	var total_length : float = max(315.0, distance_to_center * 0.9)
	var half := total_length * 0.5
	var dir := Vector2.RIGHT if position_value.x < viewport_center_x else Vector2.LEFT
	var stages := PackedFloat32Array([1.0, 0.7, 0.95, 0.4, 0.8, 0.6, 0.6, 0.0])
	var stage_duration := 0.08
	for i in range(spikes):
		var t := (float(i) + 0.5) / float(spikes)
		var y_pos : float = lerp(-half * 0.3, half * 0.3, t)
		var length := rng.randf_range(total_length * 0.8, total_length * 1.0)
		var thickness := rng.randf_range(10.0, 18.0)
		var tri := Polygon2D.new()
		tri.color = base_color.lerp(Color(1, 1, 1, 1), rng.randf_range(0.3, 0.8))
		tri.polygon = PackedVector2Array([
			Vector2(0.0, y_pos - thickness * 0.5),
			Vector2(0.0, y_pos + thickness * 0.5),
			dir * length + Vector2(0.0, y_pos)
		])
		tri.z_index = 21
		effect.add_child(tri)
		var tween := get_tree().create_tween()
		for stage in stages:
			var target := length * stage
			tween.tween_method(func(value: float) -> void:
				tri.polygon = PackedVector2Array([
					Vector2(0.0, y_pos - thickness * 0.5),
					Vector2(0.0, y_pos + thickness * 0.5),
					dir * value + Vector2(0.0, y_pos)
				])
			, length, target, stage_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var final_tween := get_tree().create_tween()
	var total_time := stage_duration * float(stages.size())
	final_tween.tween_interval(total_time)
	final_tween.tween_callback(effect.queue_free)
