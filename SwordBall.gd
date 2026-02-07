extends WeaponBall
class_name SwordBall

func _ready() -> void:
	super._ready()
	ball_name = "SWORD"
	weight = 1.0
	damage_increment = 1.0
	random_jump_chance_per_second *= 1.1
	weapon_hit_knockback = 480.0
