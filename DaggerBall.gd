extends WeaponBall
class_name DaggerBall

@export var dagger_rotation_multiplier := 2.0
@export var dagger_damage_impulse_multiplier := 0.5
@export var dagger_rotation_increment := 1.0
@export var dagger_rotation_soft_cap := 45.0

func _ready() -> void:
	super._ready()
	weapon_rotation_speed *= dagger_rotation_multiplier
	damage_knockback_impulse *= dagger_damage_impulse_multiplier
	damage_increment = 0.0
	max_double_jumps = 2
	weight = 0.8
	random_jump_chance_per_second *= 1.6
	apex_double_jump_chance *= 1.8
	attraction_force *= 1.2
	attraction_speed_cap *= 1.2
	weapon_hit_knockback = 224.0

func _on_weapon_body_entered(body: Node) -> void:
	super._on_weapon_body_entered(body)
	if body is Ball and body != self:
		var current := absf(weapon_rotation_speed)
		var t := clampf((dagger_rotation_soft_cap - current) / dagger_rotation_soft_cap, 0.1, 1.0)
		weapon_rotation_speed = current + dagger_rotation_increment * t
