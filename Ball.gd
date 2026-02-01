extends RigidBody2D
class_name Ball

signal damage_taken_changed(ball_id: int, damage_taken: int)
signal damage_changed(ball_id: int, damage: int)

@export var ball_id := 1
@export var ball_color := Color(0.9, 0.2, 0.2)
@export var radius := 30.0
@export var sword_rotation_speed := 3.8
@export var sword_orbit_radius := 36.0
@export var clash_impulse := 260.0
@export var hit_pause_time := 0.2
@export var hit_pause_scale := 0.1
@export var hit_flash_time := 0.08
@export var apex_double_jump_chance := 0.2
@export var apex_jump_impulse := 220.0
@export var apex_horizontal_impulse := 60.0
@export var attraction_force := 800.0
@export var damage_knockback_impulse := 280.0
@export var stage_center := Vector2.ZERO
@export var ball_bounce_damp := 0.13
@export var floor_y := 0.0
@export var random_jump_chance_per_second := 0.6
@export var random_jump_impulse := 620.0
@export var random_jump_horizontal_impulse := 60.0
@export var hitstun_base_time := 0.5
@export var hitstun_per_damage := 0.005
@export var hitstun_tint_strength := 0.35

var _last_clash_ms := 0
static var _hit_stop_active := false
var _flash_timer := 0.0
var _last_velocity := Vector2.ZERO
var _apex_cooldown := 0.0
var _jump_cooldown := 0.0
var _hitstun_time_left := 0.0
var _in_hitstun := false

var damage_taken := 0
var damage := 1

@onready var sword_pivot: Node2D = $SwordPivot
@onready var sword: Area2D = $SwordPivot/Sword
@onready var sfx_slash: AudioStreamPlayer2D = $SfxSlash
@onready var sfx_clash: AudioStreamPlayer2D = $SfxClash
@onready var hp_label: Label = $HpLabel
@onready var hitstun_trail: GPUParticles2D = $HitstunTrail

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

	sword.position = Vector2(radius * 2, 0.0)
	sword.body_entered.connect(_on_sword_body_entered)
	sword.area_entered.connect(_on_sword_area_entered)
	sword.monitoring = true
	sword.monitorable = true

	_setup_hitstun_trail()

	queue_redraw()
	_update_hp_label()
	emit_signal("damage_taken_changed", ball_id, damage_taken)
	emit_signal("damage_changed", ball_id, damage)

func _physics_process(delta: float) -> void:
	sword_pivot.rotation += sword_rotation_speed * delta
	_apex_cooldown = max(_apex_cooldown - delta, 0.0)
	_jump_cooldown = max(_jump_cooldown - delta, 0.0)
	if _hitstun_time_left > 0.0:
		_hitstun_time_left = max(_hitstun_time_left - delta, 0.0)
	if _in_hitstun and _hitstun_time_left <= 0.0:
		_set_hitstun(false)
	_check_apex_double_jump()
	_check_random_jump(delta)
	_apply_attraction_force()
	if _flash_timer > 0.0:
		_flash_timer = max(_flash_timer - delta, 0.0)
		queue_redraw()
	_last_velocity = linear_velocity

func _draw() -> void:
	var draw_color := ball_color
	if _flash_timer > 0.0:
		draw_color = Color(1, 1, 1)
	elif _in_hitstun:
		draw_color = ball_color.lerp(Color(1, 1, 1), hitstun_tint_strength)
	draw_circle(Vector2.ZERO, radius, draw_color)

func take_damage(amount: int, source: Ball = null) -> void:
	damage_taken = max(damage_taken + amount, 0)
	_flash_timer = hit_flash_time
	_update_hp_label()
	emit_signal("damage_taken_changed", ball_id, damage_taken)
	_enter_hitstun()
	if source != null:
		var direction := (global_position - source.global_position).normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		var scaled_impulse := damage_knockback_impulse * (1.0 + float(damage_taken) * 0.05)
		apply_impulse(direction * scaled_impulse)

func _on_body_entered(body: Node) -> void:
	if body is Ball:
		linear_velocity *= ball_bounce_damp

func _on_sword_body_entered(body: Node) -> void:
	if body == self:
		return
	if body is Ball:
		sfx_slash.play()
		_hit_stop()
		body.take_damage(damage, self)
		damage += 1
		emit_signal("damage_changed", ball_id, damage)

func _on_sword_area_entered(area: Area2D) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_clash_ms < 120:
		return
	if area == sword:
		return
	var other_ball := _find_ball_owner(area)
	if other_ball == null or other_ball == self:
		return
	_last_clash_ms = now
	sword_rotation_speed = -sword_rotation_speed
	sfx_clash.play()
	var direction := (global_position - other_ball.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	apply_impulse(direction * clash_impulse)
	other_ball._on_clash_from(self)

func _on_clash_from(other_ball: Ball) -> void:
	_last_clash_ms = Time.get_ticks_msec()
	sword_rotation_speed = -sword_rotation_speed
	var direction := (global_position - other_ball.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.LEFT
	apply_impulse(direction * clash_impulse)

func _find_ball_owner(node: Node) -> Ball:
	var current: Node = node
	for i in range(4):
		if current is Ball:
			return current
		if current == null:
			return null
		current = current.get_parent()
	return null

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
	hitstun_trail.emitting = active
	queue_redraw()

func _update_hp_label() -> void:
	hp_label.text = str(damage_taken)

func _setup_hitstun_trail() -> void:
	var texture := _make_smoke_texture()
	hitstun_trail.texture = texture
	hitstun_trail.z_index = -1

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = 180.0
	material.initial_velocity_min = 10.0
	material.initial_velocity_max = 60.0
	material.scale_min = 0.5
	material.scale_max = 1.0
	material.color = Color(1, 1, 1, 0.9)
	material.gravity = Vector3.ZERO
	material.damping_min = 0.0
	material.damping_max = 0.0

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_curve_texture := CurveTexture.new()
	scale_curve_texture.curve = scale_curve
	material.scale_curve = scale_curve_texture

	hitstun_trail.process_material = material

func _make_smoke_texture() -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(7.5, 7.5)
	var radius := 7.0
	for y in range(16):
		for x in range(16):
			var pos := Vector2(float(x), float(y))
			if pos.distance_to(center) <= radius:
				image.set_pixel(x, y, Color(1, 1, 1, 1))
	var texture := ImageTexture.create_from_image(image)
	return texture

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
			_apex_cooldown = 0.3

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

func _apply_attraction_force() -> void:
	var direction := stage_center - global_position
	if direction.length() < 0.01:
		return
	apply_force(direction.normalized() * attraction_force)

func _is_on_floor() -> bool:
	return global_position.y + radius >= floor_y - 1.0 and abs(linear_velocity.y) < 20.0
