extends WeaponBall
class_name SwordBall

func _ready() -> void:
	super._ready()
	weight = 1.0
	damage_increment = 0.2
	weapon_hit_knockback = 480.0
