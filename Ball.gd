extends RigidBody2D
class_name Ball

signal damage_taken_changed(ball_id: int, damage_taken: float)

@export var ball_id := 1
@export var ball_color := Color(0.9, 0.2, 0.2)
@export var radius := 40.0
@export var hit_pause_time := 0.2
@export var hit_pause_scale := 0.1
@export var hit_flash_time := 0.08
@export var apex_double_jump_chance := 0.2
@export var apex_jump_impulse := 700.0
@export var apex_horizontal_impulse := 60.0
@export var attraction_force := 800.0
@export var damage_knockback_impulse := 280.0
@export var stage_center := Vector2.ZERO
@export var ball_bounce_damp := 0.13
@export var floor_y := 0.0
@export var random_jump_chance_per_second := 0.6
@export var random_jump_impulse := 700.0
@export var random_jump_horizontal_impulse := 60.0
@export var hitstun_base_time := 0.5
@export var hitstun_per_damage := 0.005
@export var hitstun_tint_strength := 0.35
@export var hitstun_trail_interval := 0.08
@export var hitstun_trail_lifetime := 0.4
@export var attraction_speed_cap := 300.0
@export var hitstun_drag_window := 0.2
@export var hitstun_drag_strength := 900.0
@export var double_jump_ring_duration := 0.5
@export var max_double_jumps := 1
@export var weight := 1.0
@export var damage_knockback_cooldown := 0.0 # prev 0.12 to prevent chains

static var _hit_stop_active := false
var _flash_timer := 0.0
var _last_velocity := Vector2.ZERO
var _apex_cooldown := 0.0
var _jump_cooldown := 0.0
var _hitstun_time_left := 0.0
var _in_hitstun := false
var _trail_timer := 0.0
var _double_jumps_used := 0
var _suppress_knockback_until := 0
var _last_damage_knockback_ms := 0
var _smoke_texture: Texture2D = null
var _last_hitstun_bounce_ms := 0

var damage_taken := 0.0

@onready var hp_label: Label = $HpLabel
@onready var hitstun_trail_layer: Node2D = $HitstunTrailLayer
@onready var sfx_floor_tom: AudioStreamPlayer2D = $SfxFloorTom

func _ready() -> void:
	var material := PhysicsMaterial.new()
	material.bounce = 0.0
	material.friction = 0.6
	physics_material_override = material
	gravity_scale = 1.4
	linear_damp = 0.0
	angular_damp = 0.0

	_set_collision_radius()
	linear_velocity = _random_velocity()
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	_smoke_texture = _make_smoke_texture()
	queue_redraw()
	_update_hp_label()
	emit_signal("damage_taken_changed", ball_id, damage_taken)
	_setup_hp_label()

func _physics_process(delta: float) -> void:
	_apex_cooldown = max(_apex_cooldown - delta, 0.0)
	_jump_cooldown = max(_jump_cooldown - delta, 0.0)
	if _hitstun_time_left > 0.0:
		_hitstun_time_left = max(_hitstun_time_left - delta, 0.0)
	if _in_hitstun and _hitstun_time_left <= 0.0:
		_set_hitstun(false)
	if _is_on_floor() and _double_jumps_used > 0:
		_double_jumps_used = 0
	if _in_hitstun and _hitstun_time_left <= hitstun_drag_window:
		_apply_hitstun_drag()
	if _in_hitstun:
		_trail_timer -= delta
		if _trail_timer <= 0.0:
			_spawn_hitstun_particle()
			_trail_timer = hitstun_trail_interval
	_check_apex_double_jump()
	_check_random_jump(delta)
	_apply_attraction_force()
	if _flash_timer > 0.0:
		_flash_timer = max(_flash_timer - delta, 0.0)
		queue_redraw()
	_update_hp_label_transform()
	_last_velocity = linear_velocity

func _draw() -> void:
	var draw_color := ball_color
	if _flash_timer > 0.0:
		draw_color = Color(1, 1, 1)
	elif _in_hitstun:
		draw_color = ball_color.lerp(Color(1, 1, 1), hitstun_tint_strength)
	draw_circle(Vector2.ZERO, radius, draw_color)

func take_damage(amount: float, source: Ball = null, knockback_impulse: float = -1.0) -> void:
	damage_taken = maxf(damage_taken + amount, 0.0)
	_flash_timer = hit_flash_time
	_update_hp_label()
	emit_signal("damage_taken_changed", ball_id, damage_taken)
	_enter_hitstun()
	if source != null:
		if Time.get_ticks_msec() < _suppress_knockback_until:
			return
		var now := Time.get_ticks_msec()
		if now - _last_damage_knockback_ms < int(damage_knockback_cooldown * 1000.0):
			return
		_last_damage_knockback_ms = now
		linear_velocity *= 0.1
		var direction := (global_position - source.global_position).normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		direction = direction.rotated(_random_knockback_variance())
		var weight_scale: float = 1.0 / maxf(weight, 0.1)
		var base_impulse := damage_knockback_impulse
		if knockback_impulse >= 0.0:
			base_impulse = knockback_impulse
		var scaled_impulse: float = base_impulse * (1.0 + float(damage_taken) * 0.05) * weight_scale
		apply_impulse(direction * scaled_impulse)

func suppress_knockback(duration_seconds: float) -> void:
	_suppress_knockback_until = Time.get_ticks_msec() + int(duration_seconds * 1000.0)

func is_in_hitstun() -> bool:
	return _in_hitstun

func _on_body_entered(body: Node) -> void:
	if body is Ball:
		linear_velocity *= ball_bounce_damp
	if _in_hitstun and (body is Wall or body is Floor):
		_play_hitstun_bounce_sfx()

func _hit_stop() -> void:
	if _hit_stop_active:
		return
	_hit_stop_active = true
	var previous_scale := Engine.time_scale
	Engine.time_scale = hit_pause_scale
	var timer := get_tree().create_timer(hit_pause_time, true, false, true)
	timer.timeout.connect(func() -> void:
		Engine.time_scale = previous_scale
		_hit_stop_active = false
	)

func _enter_hitstun() -> void:
	var duration := hitstun_base_time + float(damage_taken) * hitstun_per_damage
	if _in_hitstun:
		_hitstun_time_left = max(_hitstun_time_left, duration)
		return
	_hitstun_time_left = duration
	_set_hitstun(true)

func _set_hitstun(active: bool) -> void:
	_in_hitstun = active
	var material := physics_material_override
	if material == null:
		material = PhysicsMaterial.new()
		physics_material_override = material
	if active:
		material.bounce = 1.0
		material.friction = 0.1
	else:
		material.bounce = 0.0
		material.friction = 0.6
	if active:
		_trail_timer = 0.0
	queue_redraw()

func _update_hp_label() -> void:
	hp_label.text = str(int(round(damage_taken)))

func _setup_hp_label() -> void:
	hp_label.add_theme_font_size_override("font_size", 32)
	hp_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	hp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	hp_label.add_theme_constant_override("outline_size", 12)
	hp_label.pivot_offset = hp_label.size * 0.5

func _update_hp_label_transform() -> void:
	hp_label.rotation = -rotation

func _play_hitstun_bounce_sfx() -> void:
	if sfx_floor_tom == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_hitstun_bounce_ms < 80:
		return
	_last_hitstun_bounce_ms = now
	sfx_floor_tom.pitch_scale = randf_range(0.8, 1.2)
	sfx_floor_tom.play()

func _spawn_hitstun_particle() -> void:
	var particle := Sprite2D.new()
	particle.texture = _smoke_texture
	particle.modulate = Color(1, 1, 1, 1.0)
	particle.scale = Vector2(1.5, 1.5)
	particle.z_index = -5
	var host := get_tree().current_scene if get_tree().current_scene != null else hitstun_trail_layer
	host.add_child(particle)
	particle.global_position = global_position

	var tween := get_tree().create_tween()
	tween.tween_property(particle, "scale", Vector2.ZERO, hitstun_trail_lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(particle, "modulate:a", 0.0, hitstun_trail_lifetime)
	tween.tween_callback(particle.queue_free)

func _make_smoke_texture() -> Texture2D:
	if _smoke_texture != null:
		return _smoke_texture
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(15.5, 15.5)
	var radius := 14.0
	for y in range(32):
		for x in range(32):
			var pos := Vector2(float(x), float(y))
			if pos.distance_to(center) <= radius:
				image.set_pixel(x, y, Color(1, 1, 1, 1))
	var texture := ImageTexture.create_from_image(image)
	return texture

func _spawn_double_jump_ring() -> void:
	var ring := Sprite2D.new()
	ring.texture = _smoke_texture
	ring.modulate = Color(1, 1, 1, 0.9)
	ring.scale = Vector2.ZERO
	ring.z_index = -2
	var host := get_tree().current_scene if get_tree().current_scene != null else hitstun_trail_layer
	host.add_child(ring)
	ring.global_position = global_position

	var target_size := Vector2(radius * 2.4, radius * 0.4)
	var texture_size := ring.texture.get_size()
	var target_scale := Vector2(target_size.x / texture_size.x, target_size.y / texture_size.y)

	var tween := get_tree().create_tween()
	tween.tween_property(ring, "scale", target_scale, double_jump_ring_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, double_jump_ring_duration)
	tween.tween_callback(ring.queue_free)

func _set_collision_radius() -> void:
	var shape = $CollisionShape2D.shape
	if shape is CircleShape2D:
		shape.radius = radius

func _random_velocity() -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return Vector2.ZERO
	#return Vector2(rng.randf_range(-220.0, 220.0), rng.randf_range(-220.0, 220.0))

func _check_apex_double_jump() -> void:
	if _apex_cooldown > 0.0:
		return
	if _double_jumps_used >= max_double_jumps:
		return
	if _is_on_floor():
		return
	if _last_velocity.y < 0.0 and linear_velocity.y >= 0.0 and abs(linear_velocity.y) < 40.0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		if rng.randf() <= apex_double_jump_chance:
			var horizontal_dir := stage_center.x - global_position.x
			var x_dir := 0.0
			if abs(horizontal_dir) > 0.01:
				x_dir = signf(horizontal_dir)
			var x_impulse := x_dir * apex_horizontal_impulse
			apply_impulse(Vector2(x_impulse, -apex_jump_impulse))
			_spawn_double_jump_ring()
			_apex_cooldown = 0.3
			_double_jumps_used += 1

func _check_random_jump(delta: float) -> void:
	if _jump_cooldown > 0.0:
		return
	if not _is_on_floor():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() <= random_jump_chance_per_second * delta:
		var x_impulse := rng.randf_range(-random_jump_horizontal_impulse, random_jump_horizontal_impulse)
		apply_impulse(Vector2(x_impulse, -random_jump_impulse))
		_jump_cooldown = 0.35

func _random_knockback_variance() -> float:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return deg_to_rad(rng.randf_range(-15.0, 15.0))

func _apply_attraction_force() -> void:
	var direction := stage_center - global_position
	if direction.length() < 0.01:
		return
	var attraction_dir := direction.normalized()
	var speed_along := linear_velocity.dot(attraction_dir)
	if speed_along < attraction_speed_cap:
		apply_force(attraction_dir * attraction_force)

func _apply_hitstun_drag() -> void:
	var speed := linear_velocity.length()
	if speed < 1.0:
		return
	var drag_dir := -linear_velocity.normalized()
	var drag_scale: float = clampf(speed / attraction_speed_cap, 0.3, 1.0)
	apply_force(drag_dir * hitstun_drag_strength * drag_scale)

func _is_on_floor() -> bool:
	return global_position.y + radius >= floor_y - 1.0 and abs(linear_velocity.y) < 20.0
