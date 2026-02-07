extends WeaponBall
class_name RapierBall

@export var base_damage := 1.0
@export var tipper_damage := 1.0
@export var tipper_damage_increment := 1.0
@export var tipper_lockout_time := 0.5
@export var tipper_increment_cooldown := 0.1
@export var tipper_trigger_cooldown := 0.5
@export var rapier_knockback := 320.0

@onready var tip_area: Area2D = $SwordPivot/Sword/Tip
@onready var sfx_tipper: AudioStreamPlayer2D = $SfxTipper

var _tipper_lockout := 0.0
var _last_hilt_hit_ms := 0
var _last_tipper_increment_ms := 0
var _last_tipper_trigger_ms := 0
var _direction_timer := 0.0
var _direction_angles := PackedFloat32Array([
	0.0,
	PI * 0.25,
	PI * 0.5,
	PI * 0.75,
	PI,
	PI * 1.25,
	PI * 1.5,
	PI * 1.75
])
var _cardinal_tween: Tween = null
var _orbit_time := 0.0
var _orbit_amplitude := 16.0
var _orbit_period := 0.5

func _ready() -> void:
	super._ready()
	ball_name = "RAPIER"
	weapon_rotation_speed = 0.0
	max_double_jumps = 2
	weapon_hit_knockback = rapier_knockback
	random_jump_chance_per_second *= 1.2
	damage = base_damage
	damage_increment = 0.0
	if tip_area != null:
		tip_area.body_entered.connect(_on_tip_body_entered)
	_set_random_direction()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# Keep the ball itself from tilting.
	angular_velocity = 0.0
	rotation = 0.0
	_tipper_lockout = max(_tipper_lockout - delta, 0.0)
	_orbit_time += delta
	var phase := (_orbit_time / _orbit_period) * TAU
	var offset := sin(phase) * _orbit_amplitude
	weapon.position = Vector2(weapon_orbit_radius + offset, 0.0)
	_direction_timer += delta
	if _direction_timer >= 1.0:
		_direction_timer -= 1.0
		_set_random_direction()

func _set_random_direction() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var idx := rng.randi_range(0, _direction_angles.size() - 1)
	var target := _direction_angles[idx]
	if _cardinal_tween != null and _cardinal_tween.is_valid():
		_cardinal_tween.kill()
	_cardinal_tween = get_tree().create_tween()
	_cardinal_tween.tween_property(weapon_pivot, "rotation", target, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_weapon_body_entered(body: Node) -> void:
	if body == self:
		return
	if body is Ball:
		var ball: Ball = body
		_last_hilt_hit_ms = Time.get_ticks_msec()
		_swing_hit(ball, false)

func _on_tip_body_entered(body: Node) -> void:
	if body == self:
		return
	if body is Ball:
		var ball: Ball = body
		var now := Time.get_ticks_msec()
		if now - _last_hilt_hit_ms <= 0.2:
			return
		var can_trigger_tipper := now - _last_tipper_trigger_ms >= int(tipper_trigger_cooldown * 1000.0)
		var use_tipper := _tipper_lockout <= 0.0 and can_trigger_tipper
		_swing_hit(ball, use_tipper)

func _swing_hit(target: Ball, use_tipper: bool) -> void:
	sfx_slash.play()
	_hit_stop()
	var dmg := base_damage
	if use_tipper:
		dmg = tipper_damage
		if sfx_tipper != null:
			sfx_tipper.play()
		_last_tipper_trigger_ms = Time.get_ticks_msec()
	else:
		_tipper_lockout = tipper_lockout_time
	target.take_damage(dmg, self, weapon_hit_knockback)
	var now := Time.get_ticks_msec()
	if now - _last_tipper_increment_ms >= int(tipper_increment_cooldown * 1000.0):
		tipper_damage += tipper_damage_increment
		_last_tipper_increment_ms = now
	emit_signal("damage_changed", ball_id, damage)
