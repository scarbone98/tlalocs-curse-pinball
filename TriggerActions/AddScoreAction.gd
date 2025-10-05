# AddScoreAction.gd
extends TriggerAction
class_name AddScoreAction
@export var amount: int = 100
func execute(ball, trigger) -> void:
	PinballEvents.add_score.emit(amount)  # via autoload (below)
