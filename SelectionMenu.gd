extends CanvasLayer
class_name SelectionMenu

signal ball_type_selected(ball_type: String)

@onready var title_label: Label = $Root/TitleLabel
@onready var sword_button: Button = $Root/Panel/Buttons/SwordButton
@onready var rapier_button: Button = $Root/Panel/Buttons/RapierButton
@onready var dagger_button: Button = $Root/Panel/Buttons/DaggerButton

func _ready() -> void:
	sword_button.pressed.connect(func() -> void:
		ball_type_selected.emit("SwordBall")
	)
	rapier_button.pressed.connect(func() -> void:
		ball_type_selected.emit("RapierBall")
	)
	dagger_button.pressed.connect(func() -> void:
		ball_type_selected.emit("DaggerBall")
	)

func set_prompt(text: String) -> void:
	if title_label != null:
		title_label.text = text

func set_buttons_enabled(enabled: bool) -> void:
	if sword_button != null:
		sword_button.disabled = not enabled
	if rapier_button != null:
		rapier_button.disabled = not enabled
	if dagger_button != null:
		dagger_button.disabled = not enabled
