extends Area2D
class_name TriggerArea

@export var tag := "generic"
@export var once := false
@export var wait_for_exit := false
@export var actions: Array[TriggerAction] = []

var _fired := false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if _fired and (once or wait_for_exit):
		return
	if not body.is_in_group("ball"):
		return

	_fired = true

	for a in actions:
		a.execute(body, self)

	if once:
		monitoring = false  # permanent disable after first trigger

func _on_body_exited(body):
	if wait_for_exit and body.is_in_group("ball"):
		_fired = false
