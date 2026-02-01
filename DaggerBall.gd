extends WeaponBall
class_name DaggerBall

@export var dagger_rotation_multiplier := 2.0
@export var dagger_damage_impulse_multiplier := 0.5
@export var dagger_rotation_increment := 3

func _ready() -> void:
	super._ready()
	sword_rotation_speed *= dagger_rotation_multiplier
	damage_knockback_impulse *= dagger_damage_impulse_multiplier
	damage_increment = 0.0
	max_double_jumps = 2
	weight = 0.8
	random_jump_chance_per_second *= 1.6
	apex_double_jump_chance *= 1.8
	attraction_force *= 1.2
	attraction_speed_cap *= 1.2

func _on_sword_body_entered(body: Node) -> void:
	super._on_sword_body_entered(body)
	if body is Ball and body != self:
		sword_rotation_speed += dagger_rotation_increment
