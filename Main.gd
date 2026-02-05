extends Node2D

@export var arena_size := 520.0
@export var wall_thickness := 60.0
@export var arena_offset_y := -100.0
@export var platform_width := 140.0
@export var platform_height := 20.0
@export var platform_inset := -45.0
@export var platform_height_offset := 60.0
var sprite_scale := 1.0
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
@onready var player1_label: Label = $UI/Player1Label
@onready var player2_label: Label = $UI/Player2Label
@onready var vs_sprite: Sprite2D = $UI/VsSprite

var walldist := 58

var _game_over := false
var player1: Ball = null
var player2: Ball = null

func _ready() -> void:
	call_deferred("_layout_arena")
	_setup_balls()
	_connect_signals()
	_setup_game_label()
	_setup_player_labels()

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
	_set_wall(wall_bottom, floor_position, Vector2(floor_width + 10, wall_thickness))
	var ceiling_position := Vector2(viewport_size.x * 0.5, center.y - half - wall_thickness * 0.5)
	_set_wall(wall_top, ceiling_position, Vector2(viewport_size.x, wall_thickness))
	var wall_height := arena_size_value
	_set_wall(wall_left, Vector2(0.0 - wall_thickness * 0.5 + walldist, center.y), Vector2(wall_thickness, wall_height))
	_set_wall(wall_right, Vector2(viewport_size.x + wall_thickness * 0.5 - walldist, center.y), Vector2(wall_thickness, wall_height))

	if arena_background != null:
		arena_background.position = Vector2.ZERO
		arena_background.size = viewport_size

	var ceiling_top_y := ceiling_position.y - wall_thickness * 0.5
	_layout_player_labels(ceiling_top_y, viewport_size.x)

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
	if is_instance_valid(ball_left):
		if _is_out_of_bounds(ball_left.global_position.x):
			_handle_out_of_bounds(ball_left, false)
			return
		if _is_below_screen(ball_left):
			_handle_out_of_bounds(ball_left, true)
			return
	if is_instance_valid(ball_right):
		if _is_out_of_bounds(ball_right.global_position.x):
			_handle_out_of_bounds(ball_right, false)
			return
		if _is_below_screen(ball_right):
			_handle_out_of_bounds(ball_right, true)

func _is_out_of_bounds(x_value: float) -> bool:
	return x_value < out_of_bounds_min_x or x_value > out_of_bounds_max_x

func _is_below_screen(ball: Ball) -> bool:
	var viewport_height := get_viewport_rect().size.y
	return ball.global_position.y - ball.radius > viewport_height

func _handle_out_of_bounds(ball, fell_below: bool) -> void:
	_game_over = true
	if is_instance_valid(ball):
		var effect_color: Color = ball.ball_color
		var ball_pos: Vector2 = ball.global_position
		if sfx_ko != null:
			sfx_ko.play()
		ball.queue_free()
		var effect_pos := ball_pos
		var direction := Vector2.RIGHT
		if fell_below:
			var viewport_size := get_viewport_rect().size
			effect_pos = Vector2(ball_pos.x, viewport_size.y)
			direction = Vector2.UP
		_spawn_ko_effect(effect_color, effect_pos, direction)
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
	player1 = ball_left
	player2 = ball_right

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
		visual.z_index = -6
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
				sprite_scale = scale_value
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
		visual.color = Color(0, 0, 0, 0)
		visual.size = size
		visual.position = -size * 0.5
	if platform.has_node("PlatformSprite"):
		var platform_sprite: Sprite2D = platform.get_node("PlatformSprite")
		var floor_scale := 1.0
		if wall_bottom != null and wall_bottom.has_node("FloorSprite"):
			var floor_sprite: Sprite2D = wall_bottom.get_node("FloorSprite")
			var floor_tex := floor_sprite.texture
			if floor_tex != null:
				var floor_tex_size := floor_tex.get_size()
				if floor_tex_size.x > 0.0:
					floor_scale = (arena_size + 130) / floor_tex_size.x
		var scaled := floor_scale * sprite_scale
		var x_scale := -scaled if platform == platform_right else scaled
		platform_sprite.scale = Vector2(x_scale, scaled)
		platform_sprite.position = Vector2.ZERO


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

func _setup_player_labels() -> void:
	_update_player_labels()
	if player1_label != null:
		player1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		player1_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		player1_label.add_theme_font_size_override("font_size", 60)
		player1_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		player1_label.add_theme_constant_override("outline_size", 32)
	if player2_label != null:
		player2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		player2_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		player2_label.add_theme_font_size_override("font_size", 60)
		player2_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		player2_label.add_theme_constant_override("outline_size", 32)

func _update_player_labels() -> void:
	if player1_label != null:
		player1_label.text = player1.ball_name.to_upper() if player1 != null else "PLAYER 1"
	if player2_label != null:
		player2_label.text = player2.ball_name.to_upper() if player2 != null else "PLAYER 2"

func _layout_player_labels(ceiling_top_y: float, viewport_width: float) -> void:
	_update_player_labels()
	var band_height : float = max(0.0, ceiling_top_y)
	var top_offset : float = 10.0
	if band_height > 0.0 and player1_label != null:
		top_offset = (band_height - player1_label.get_minimum_size().y) * 0.5
	if player1_label != null:
		player1_label.anchor_left = 0.0
		player1_label.anchor_right = 0.0
		player1_label.anchor_top = 0.0
		player1_label.anchor_bottom = 0.0
		player1_label.offset_left = 20.0
		player1_label.offset_top = top_offset
	if player2_label != null:
		player2_label.anchor_left = 0.0
		player2_label.anchor_right = 0.0
		player2_label.anchor_top = 0.0
		player2_label.anchor_bottom = 0.0
		player2_label.offset_left = viewport_width - 20.0 - player2_label.get_minimum_size().x
		if band_height > 0.0:
			player2_label.offset_top = (band_height - player2_label.get_minimum_size().y) * 0.5
		else:
			player2_label.offset_top = 10.0
	if vs_sprite != null:
		var vs_tex := vs_sprite.texture
		var vs_size := Vector2.ZERO
		if vs_tex != null:
			var base_size := vs_tex.get_size()
			var scaled := sprite_scale
			if base_size.y > 0.0:
				var fit_scale : float = 1.0
				if band_height > 0.0:
					fit_scale = min(1.0, band_height / base_size.y)
				scaled *= fit_scale
			vs_sprite.scale = Vector2(scaled, scaled)
			vs_size = base_size * scaled
		var vs_y := (band_height - vs_size.y) * 0.5 if band_height > 0.0 else 10.0
		vs_sprite.position = Vector2(viewport_width * 0.5, vs_y + vs_size.y * 0.5)
		vs_sprite.z_as_relative = false
		vs_sprite.z_index = 5
		vs_sprite.visible = true
		vs_sprite.modulate = Color(1, 1, 1, 1)

func _show_game_label() -> void:
	game_label.visible = true

func _trigger_slowmo() -> void:
	var previous_scale := Engine.time_scale
	Engine.time_scale = slowmo_scale
	var timer := get_tree().create_timer(slowmo_duration, true, false, true)
	timer.timeout.connect(func() -> void:
		Engine.time_scale = previous_scale
	)


func _spawn_ko_effect(base_color: Color, position_value: Vector2, direction: Vector2) -> void:
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
	var dir := direction
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT if position_value.x < viewport_center_x else Vector2.LEFT
	var stages := PackedFloat32Array([1.0, 0.7, 0.95, 0.4, 0.8, 0.6, 0.6, 0.0])
	var stage_duration := 0.08
	for i in range(spikes):
		var t := (float(i) + 0.5) / float(spikes)
		var y_pos : float = lerp(-half * 0.3, half * 0.3, t)
		var x_pos : float = lerp(-half * 0.3, half * 0.3, t)
		var length := rng.randf_range(total_length * 0.8, total_length * 1.0)
		var thickness := rng.randf_range(10.0, 18.0)
		var tri := Polygon2D.new()
		tri.color = base_color.lerp(Color(1, 1, 1, 1), rng.randf_range(0.3, 0.8))
		if abs(dir.y) > 0.0:
			tri.polygon = PackedVector2Array([
				Vector2(x_pos - thickness * 0.5, 0.0),
				Vector2(x_pos + thickness * 0.5, 0.0),
				dir * length + Vector2(x_pos, 0.0)
			])
		else:
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
				if abs(dir.y) > 0.0:
					tri.polygon = PackedVector2Array([
						Vector2(x_pos - thickness * 0.5, 0.0),
						Vector2(x_pos + thickness * 0.5, 0.0),
						dir * value + Vector2(x_pos, 0.0)
					])
				else:
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
