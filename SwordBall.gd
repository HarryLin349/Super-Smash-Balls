extends Ball
class_name SwordBall

var _last_clash_ms := 0

@export var sword_rotation_speed := 3.8
@export var sword_orbit_radius := 30.0
@export var clash_impulse := 260.0

@onready var sword_pivot: Node2D = $SwordPivot
@onready var sword: Area2D = $SwordPivot/Sword
@onready var sfx_slash: AudioStreamPlayer2D = $SfxSlash
@onready var sfx_clash: AudioStreamPlayer2D = $SfxClash

func _ready() -> void:
	super._ready()

	sword.position = Vector2(sword_orbit_radius, 0.0)
	sword.body_entered.connect(_on_sword_body_entered)
	sword.area_entered.connect(_on_sword_area_entered)
	sword.monitoring = true
	sword.monitorable = true

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	sword_pivot.rotation += sword_rotation_speed * delta

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
