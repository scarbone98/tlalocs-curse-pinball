# PinballEvents.gd (set as Autoload/Singleton)
extends Node

signal add_score(points: int)          # +N points
signal set_score(value: int)           # absolute set (e.g., on reset)
signal lives_changed(lives: int)       # update lives display
signal ball_drained()                  # when ball hits death zone
signal toast(message: String)          # quick UI message
signal launch_available(available: bool) # ball is resting on the plunger
signal launch_pressed()                # on-screen launch button held down
signal launch_released()               # on-screen launch button let go
signal launch_power_changed(power: float, charging: bool) # plunger meter
signal ball_launched()                 # plunger fired
signal game_over(final_score: int, is_new_best: bool)
signal scored_at(points: int, world_pos: Vector2) # base points awarded at a spot, for popups
signal multiplier_changed(multiplier: int)
signal curse_changed(active: bool)
signal ramp_made(side: String, combo: int) # ball went over a side ramp and back down
signal ball_left_ramp(ball: RigidBody2D) # a ball bounced out of a ramp mouth; gates forget it
signal spirit_caught()                  # a water spirit was caught
signal top_lanes_completed()           # all three top lanes lit
signal objective_changed(text: String) # the journey's current goal, shown under the score
