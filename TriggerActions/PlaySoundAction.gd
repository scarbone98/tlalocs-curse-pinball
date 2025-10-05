# PlaySoundAction.gd
extends TriggerAction
class_name PlaySoundAction
@export var sound: AudioStream
func execute(ball, trigger) -> void:
	if sound:
		var p := AudioStreamPlayer.new()
		trigger.add_child(p)
		p.stream = sound
		p.play()
