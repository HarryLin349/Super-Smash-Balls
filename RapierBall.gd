extends WeaponBall
class_name RapierBall

@export var base_damage := 1.0
@export var tipper_damage := 3.0
@export var tipper_damage_increment := 2.0
@export var tipper_lockout_time := 0.5
@export var rapier_knockback := 320.0

@onready var tip_area: Area2D = $SwordPivot/Sword/Tip
@onready var sfx_tipper: AudioStreamPlayer2D = $SfxTipper

var _tipper_lockout := 0.0
var _last_hilt_hit_ms := 0

func _ready() -> void:
	super._ready()
	ball_name = "RAPIER"
	weapon_rotation_speed *= 0.9
	max_double_jumps = 2
	weapon_hit_knockback = rapier_knockback
	damage = base_damage
	damage_increment = 0.0
	if tip_area != null:
		tip_area.body_entered.connect(_on_tip_body_entered)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_tipper_lockout = max(_tipper_lockout - delta, 0.0)

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
		var use_tipper := _tipper_lockout <= 0.0
		_swing_hit(ball, use_tipper)

func _swing_hit(target: Ball, use_tipper: bool) -> void:
	sfx_slash.play()
	_hit_stop()
	var dmg := base_damage
	if use_tipper:
		dmg = tipper_damage
		if sfx_tipper != null:
			sfx_tipper.play()
	else:
		_tipper_lockout = tipper_lockout_time
	target.take_damage(dmg, self, weapon_hit_knockback)
	tipper_damage += tipper_damage_increment
	emit_signal("damage_changed", ball_id, damage)
