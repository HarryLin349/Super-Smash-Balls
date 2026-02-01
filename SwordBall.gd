extends WeaponBall
class_name SwordBall

func _ready() -> void:
	super._ready()
	weight = 1.0
	damage_increment = 1.0
	random_jump_chance_per_second *= 1.2
	damage_knockback_impulse = 500
