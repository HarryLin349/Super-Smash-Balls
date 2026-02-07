@tool
extends Node2D
class_name PlayerIcon

@export var icon_size := Vector2(90.0, 90.0)
@export var frame_rotation_deg := -20.0
@export var weapon_offset_px := Vector2.ZERO
@export var weapon_rotation_deg := 20.0
@export var ball_scale_ratio := 1.0
var ball_scale_multiplier: float = 1.0
@export var weapon_scale_ratio := 1.2
var weapon_scale_multiplier: float = 1.4
@export var name_font_size := 50
@export var name_outline_size := 20

@onready var frame: ColorRect = $Frame
@onready var ball_icon: BallIcon = $Ball
@onready var weapon_sprite: Sprite2D = $Weapon
@onready var name_label: Label = $NameLabel
@onready var stat_label: Label = $StatLabel

var _ball_ref: Ball = null

func _ready() -> void:
	_apply_layout()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_apply_layout()
	else:
		_update_stat_label()

func setup(ball: Ball, frame_color: Color, _name_tex: Texture2D = null, _name_scale_value: float = 1.0) -> void:
	_ball_ref = ball
	if frame != null:
		var color_value := frame_color
		color_value.a = 0.8
		frame.color = color_value
	if ball != null:
		if ball_icon != null:
			ball_icon.set_color(ball.ball_color)
		var weapon_tex := _find_weapon_texture(ball)
		if weapon_tex != null:
			weapon_sprite.texture = weapon_tex
		if name_label != null:
			name_label.text = ball.ball_name.to_upper()
		_update_stat_label()
	_apply_layout()

func _apply_layout() -> void:
	var size_value := icon_size
	if typeof(size_value) != TYPE_VECTOR2:
		size_value = Vector2(90.0, 90.0)
	if frame != null:
		frame.size = size_value
		frame.pivot_offset = size_value * 0.5
		frame.rotation = deg_to_rad(frame_rotation_deg)
		# Center the frame around the icon's origin.
		frame.position = -size_value * 0.5
	var center := Vector2.ZERO
	if ball_icon != null:
		ball_icon.position = center + Vector2(size_value.x * 0.05, size_value.y * 0.05 + 10)
		var scale_mult := ball_scale_multiplier
		if typeof(scale_mult) != TYPE_FLOAT and typeof(scale_mult) != TYPE_INT:
			scale_mult = 1.0
		ball_icon.radius = min(size_value.x, size_value.y) * 0.5 * ball_scale_ratio * float(scale_mult)
		ball_icon.queue_redraw()
	if weapon_sprite != null:
		weapon_sprite.rotation = deg_to_rad(weapon_rotation_deg)
		weapon_sprite.position = center + Vector2(size_value.x * 0.32, -size_value.y * 0.1) + weapon_offset_px
		var weapon_tex := weapon_sprite.texture
		if weapon_tex != null:
			var weapon_size := weapon_tex.get_size()
			if weapon_size.x > 0.0 and weapon_size.y > 0.0:
				var target_weapon : float = min(size_value.x, size_value.y) * weapon_scale_ratio
				var weapon_scale : float = target_weapon / max(weapon_size.x, weapon_size.y)
				var weapon_mult := weapon_scale_multiplier
				if typeof(weapon_mult) != TYPE_FLOAT and typeof(weapon_mult) != TYPE_INT:
					weapon_mult = 1.0
				weapon_scale *= float(weapon_mult)
				weapon_sprite.scale = Vector2(weapon_scale, weapon_scale)
	if name_label != null:
		name_label.add_theme_font_size_override("font_size", name_font_size)
		name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		name_label.add_theme_constant_override("outline_size", name_outline_size)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		name_label.size = name_label.get_minimum_size()
		name_label.pivot_offset = Vector2.ZERO
		name_label.position = Vector2(center.x - name_label.size.x * 0.5, size_value.y * 0.5 + 6.0)
	if stat_label != null:
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		stat_label.size = stat_label.get_minimum_size()
		stat_label.pivot_offset = Vector2.ZERO
		var name_height := 0.0
		if name_label != null:
			name_height = name_label.size.y
		stat_label.position = Vector2(center.x - stat_label.size.x * 0.5, size_value.y * 0.5 + 6.0 + name_height + 6.0)
		_update_stat_label()

func _update_stat_label() -> void:
	if stat_label == null or _ball_ref == null:
		return
	stat_label.add_theme_color_override("font_color", _ball_ref.ball_color)
	if _ball_ref is SwordBall:
		var weapon := _ball_ref as WeaponBall
		stat_label.text = "Damage: " + str(int(round(weapon.damage)))
	elif _ball_ref is DaggerBall:
		var weapon := _ball_ref as WeaponBall
		var spin_value := (weapon.weapon_rotation_speed - 5.0) / 2.0 + 1.0
		stat_label.text = "Spin: " + str(snappedf(spin_value, 0.1))
	elif _ball_ref is RapierBall:
		var rapier := _ball_ref as RapierBall
		stat_label.text = "Tip DMG: " + str(int(round(rapier.tipper_damage)))
	else:
		stat_label.text = ""

func _find_weapon_texture(ball: Ball) -> Texture2D:
	var sprite := ball.get_node_or_null("SwordPivot/Sword/Sprite2D")
	if sprite is Sprite2D:
		return sprite.texture
	return null
