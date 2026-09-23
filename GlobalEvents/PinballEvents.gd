# PinballEvents.gd (set as Autoload/Singleton)
extends Node

signal add_score(points: int)          # +N points
signal set_score(value: int)           # absolute set (e.g., on reset)
signal lives_changed(lives: int)       # update lives display
signal ball_drained()                  # when ball hits death zone
signal toast(message: String)          # quick UI message
signal launch_available(available: bool) # ball is resting on the plunger
signal launch_requested()              # on-screen launch button pressed
signal game_over(final_score: int, is_new_best: bool)
