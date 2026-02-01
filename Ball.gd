extends RigidBody2D
class_name Ball

signal hp_changed(ball_id: int, hp: int)
signal damage_changed(ball_id: int, damage: int)

@export var ball_id := 1
@export var ball_color := Color(0.9, 0.2, 0.2)
@export var radius := 40.0
@export var sword_rotation_speed := 3.8
@export var sword_orbit_radius := 36.0
@export var clash_impulse := 360.0
@export var hit_pause_time := 0.2
@export var hit_pause_scale := 0.1
@export var hit_flash_time := 0.08
@export var apex_double_jump_chance := 0.2
@export var apex_jump_impulse := 420.0
@export var apex_horizontal_impulse := 180.0
@export var attraction_force := 35.0

var _last_clash_ms := 0
static var _hit_stop_active := false
var _flash_timer := 0.0
var _last_velocity := Vector2.ZERO
var _apex_cooldown := 0.0

var hp := 100
var damage := 1

@onready var sword_pivot: Node2D = $SwordPivot
@onready var sword: Area2D = $SwordPivot/Sword
@onready var sfx_slash: AudioStreamPlayer2D = $SfxSlash
@onready var sfx_clash: AudioStreamPlayer2D = $SfxClash
@onready var hp_label: Label = $HpLabel

func _ready() -> void:
	var material := PhysicsMaterial.new()
	material.bounce = 1.0
	material.friction = 0.0
	physics_material_override = material
	gravity_scale = 1.0
	linear_damp = 0.0
	angular_damp = 0.0

	_set_collision_radius()
	linear_velocity = _random_velocity()
	add_to_group("balls")

	sword.position = Vector2(radius * 2, 0.0)
	sword.body_entered.connect(_on_sword_body_entered)
	sword.area_entered.connect(_on_sword_area_entered)
	sword.monitoring = true
	sword.monitorable = true

	queue_redraw()
	_update_hp_label()
	emit_signal("hp_changed", ball_id, hp)
	emit_signal("damage_changed", ball_id, damage)

func _physics_process(delta: float) -> void:
	sword_pivot.rotation += sword_rotation_speed * delta
	_apex_cooldown = max(_apex_cooldown - delta, 0.0)
	_check_apex_double_jump()
	_apply_attraction_force()
	if _flash_timer > 0.0:
		_flash_timer = max(_flash_timer - delta, 0.0)
		queue_redraw()
	_last_velocity = linear_velocity

func _draw() -> void:
	var draw_color := ball_color if _flash_timer <= 0.0 else Color(1, 1, 1)
	draw_circle(Vector2.ZERO, radius, draw_color)

func take_damage(amount: int) -> void:
	hp = max(hp - amount, 0)
	_flash_timer = hit_flash_time
	_update_hp_label()
	emit_signal("hp_changed", ball_id, hp)

func _on_sword_body_entered(body: Node) -> void:
	if body == self:
		return
	if body is Ball:
		sfx_slash.play()
		_hit_stop()
		body.take_damage(damage)
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

func _update_hp_label() -> void:
	hp_label.text = str(hp)

func _set_collision_radius() -> void:
	var shape = $CollisionShape2D.shape
	if shape is CircleShape2D:
		shape.radius = radius

func _random_velocity() -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return Vector2(rng.randf_range(-220.0, 220.0), rng.randf_range(-220.0, 220.0))

func _check_apex_double_jump() -> void:
	if _apex_cooldown > 0.0:
		return
	if _last_velocity.y < 0.0 and linear_velocity.y >= 0.0 and abs(linear_velocity.y) < 40.0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		if rng.randf() <= apex_double_jump_chance:
			var x_impulse := rng.randf_range(-apex_horizontal_impulse, apex_horizontal_impulse)
			apply_impulse(Vector2(x_impulse, -apex_jump_impulse))
			_apex_cooldown = 0.3

func _apply_attraction_force() -> void:
	var other_ball := _get_other_ball()
	if other_ball == null:
		return
	var direction := (other_ball.global_position - global_position)
	if abs(direction.x) < 0.01:
		return
	var x_dir: float = signf(direction.x)
	apply_force(Vector2(x_dir * attraction_force, 0.0))

func _get_other_ball() -> Ball:
	var balls: Array[Node] = get_tree().get_nodes_in_group("balls")
	for node: Node in balls:
		if node is Ball and node != self:
			return node
	return null
