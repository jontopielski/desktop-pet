extends Node2D

signal pet_changed
signal faced_down

enum State { IDLE, ROAM, DRAG, SLEEP, PET, WANDER, ANGRY }

const state_starting_deck = [ State.IDLE, State.IDLE, State.IDLE, State.ROAM, State.SLEEP, State.SLEEP, State.WANDER, State.WANDER ]
const blink_starting_deck = [ 1, 2, 3, 4 ]
const invert_shader = preload("res://src/Invert.tres")

@export var speed: float = 100.0
@export var angle_speed: float = 2.0
@export var scale_multiplier: float = 1.0: set = set_scale_multiplier, get = get_scale_multiplier
@export var is_polygon_visible: bool = false: set = set_is_polygon_visible, get = get_is_polygon_visible
@export var reset_polygon: bool = false: set = set_reset_polygon, get = get_reset_polygon
@export var y_offset: float = 0.0

var state = State.IDLE
var last_state = State.IDLE
var direction = Vector2.ZERO
var prev_direction = Vector2.ZERO
var wander_direction = Vector2.DOWN
var drag_last_sprite_pos = Vector2.ZERO
var drag_last_mouse_pos = Vector2.ZERO
var angle = 0.0
var delta_sum = 0.0
var blink_countdown = 2

var state_deck = []
var blink_deck = []

func set_is_polygon_visible(value):
	is_polygon_visible = value
	if has_node("Polygon2D"):
		$Polygon2D.visible = value
	pet_changed.emit()

func get_is_polygon_visible():
	return is_polygon_visible

func set_scale_multiplier(value):
	scale_multiplier = value
	scale = Vector2(value, value)
	pet_changed.emit()

func get_scale_multiplier():
	return scale_multiplier

func set_reset_polygon(_value):
	setup_polygon()

func get_reset_polygon():
	return reset_polygon

func toggle_inverted():
	if !$Sprite.material:
		$Sprite.material = invert_shader
		$StackedSprite.shader = invert_shader
	else:
		$Sprite.material = null
		$StackedSprite.shader = null

func _ready():
	randomize()
	change_state(State.IDLE)
	set_is_polygon_visible(is_polygon_visible)

func _process(delta):
	if Engine.is_editor_hint():
		return
	handle_debug_inputs()
	handle_state(delta)
	handle_y_offset()
	if $Button.get_global_rect().encloses(Rect2(get_global_mouse_position(), Vector2.ZERO)) and Input.is_action_just_pressed("right_click"):
		get_tree().quit()
	if $Button.button_pressed and has_dragged_sprite():
		if state != State.DRAG:
			setup_polygon(true)
			change_state(State.DRAG)
		position = drag_last_sprite_pos + (get_global_mouse_position() - drag_last_mouse_pos)

func pop_state_deck():
	if state_deck.is_empty():
		state_deck = state_starting_deck.duplicate()
		state_deck.shuffle()
	var next_state = state_deck.pop_front()
	return next_state

func peek_state_deck():
	if state_deck.is_empty():
		state_deck = state_starting_deck.duplicate()
		state_deck.shuffle()
	return state_deck.front()

func handle_y_offset():
	if $AnimationPlayer.current_animation == "bob_up_down":
		$StackedSprite.position.y = y_offset
	else:
		$StackedSprite.position.y = 0.0

func has_dragged_sprite():
	return get_global_mouse_position() != drag_last_mouse_pos

func handle_debug_inputs():
	if !OS.is_debug_build():
		return
	if Input.is_action_just_pressed("idle_state"):
		change_state(State.IDLE)
		$StateChangeTimer.start()
	if Input.is_action_just_pressed("roam_state"):
		change_state(State.ROAM)
		$StateChangeTimer.start()
	if Input.is_action_just_pressed("sleep_state"):
		change_state(State.SLEEP)
		$StateChangeTimer.start()
	if Input.is_action_just_pressed("wander_state"):
		change_state(State.WANDER)
		$StateChangeTimer.start()

func handle_state(delta):
	delta_sum += delta
	prev_direction = direction
	match state:
		State.ROAM:
			angle += delta * angle_speed
			if last_state == State.WANDER or last_state == State.ROAM:
				direction = lerp(direction, Vector2(cos(angle), sin(angle)), 1.0 * delta)
			else:
				direction = Vector2(cos(angle), sin(angle))
			position += direction * speed * delta
			$StackedSprite.set_sprite_rotation(direction.angle() + deg_to_rad(-90))
			$StackedSprite.show(); $Sprite.hide();
			var check_angle = Vector2.DOWN.rotated(deg_to_rad(3.5)).angle()
			if prev_direction.angle() < check_angle and direction.angle() > check_angle:
				faced_down.emit()
		State.WANDER:
			if is_out_of_bounds() and $WanderRotateTimer.is_stopped():
				wander_direction = wander_direction.rotated(PI)
				$WanderRotateTimer.start()
			direction = lerp(direction, wander_direction + Vector2(sin(delta_sum), sin(delta_sum)), 1.0 * delta)
			position += direction * 7.5 * delta
			$StackedSprite.set_sprite_rotation(direction.angle() + deg_to_rad(-90))
			$StackedSprite.show(); $Sprite.hide();
	position.x = clamp(position.x, 12, get_viewport_rect().size.x - 12)
	position.y = clamp(position.y, 24, get_viewport_rect().size.y - 4)

func is_roughly_approx(vec_one, vec_two):
	return abs(vec_one.x - vec_two.x) < 0.05 and abs(vec_one.y - vec_two.y) < 0.05

func is_out_of_bounds():
	if position.x < 24 or position.x > get_viewport_rect().size.x - 24:
		return true
	if position.y < 36 or position.y > get_viewport_rect().size.y - 24:
		return true
	return false

func change_state(next_state):
	if state != State.DRAG and state != State.PET:
		last_state = state
	state = next_state
	if next_state != State.ROAM and next_state != State.WANDER:
		$Sprite.show()
		$StackedSprite.visible = false
	$StateChangeTimer.wait_time = randf_range(4, 8)
	match next_state:
		State.IDLE:
			$AnimationPlayer.play("idle")
		State.ROAM:
			if last_state != State.ROAM and last_state != State.WANDER:
				angle = Vector2.DOWN.angle()
			$AnimationPlayer.play("bob_up_down")
		State.WANDER:
			if last_state != State.ROAM and last_state != State.WANDER:
				direction = Vector2.DOWN
			if randi() % 3 == 0:
				wander_direction = wander_direction.rotated(PI)
			$AnimationPlayer.play("bob_up_down")
		State.DRAG:
			$StateChangeTimer.paused = true
			$AnimationPlayer.play("drag")
		State.SLEEP:
			$AnimationPlayer.play("sleep_intro")
			$AnimationPlayer.queue("sleep_loop")
		State.PET:
			$StateChangeTimer.paused = true
			$AnimationPlayer.play("pet")
		State.ANGRY:
			$StateChangeTimer.paused = true
			$AnimationPlayer.play("angry")

var next_polygon = PackedVector2Array([])
func setup_polygon(is_dragging=false):
	var stacked_sprite = find_child("StackedSprite")
	var first_child = stacked_sprite.get_child(0)
	var last_child = stacked_sprite.get_child(stacked_sprite.get_child_count() - 1)
	var sprite_width = last_child.texture.get_width() / last_child.hframes
	var half_width = sprite_width / 2.0
	if is_dragging:
		next_polygon = PackedVector2Array([last_child.position - Vector2(half_width, sprite_width), last_child.position + Vector2(sprite_width + half_width, -sprite_width),
			first_child.position + Vector2(sprite_width + half_width, sprite_width), first_child.position + Vector2(-half_width, sprite_width)])
	else:
		next_polygon = PackedVector2Array([last_child.position - Vector2(half_width / 3.0, half_width), last_child.position + Vector2(sprite_width + half_width / 3.0, -half_width),
			first_child.position + Vector2(sprite_width + half_width / 3.0, half_width), first_child.position + Vector2(-half_width / 3.0, half_width)])
	for i in range(0, len(next_polygon)):
		next_polygon[i].x -= half_width
	$Polygon2D.polygon = next_polygon

func _on_button_down():
	$UpdateTimer.wait_time = 0.025
	$UpdateTimer.start()
	drag_last_mouse_pos = get_global_mouse_position()
	drag_last_sprite_pos = position

func _on_button_button_up():
	$UpdateTimer.wait_time = 0.05
	$UpdateTimer.start()
	if state == State.DRAG:
		setup_polygon(false)
		$StateChangeTimer.paused = false
		change_state(State.IDLE)
	elif !has_dragged_sprite() and !state == State.PET:
		change_state(State.PET)

func _on_state_change_timer_timeout():
	var next_state = peek_state_deck()
	match state:
		State.IDLE:
			await $AnimationPlayer.animation_finished
		State.ROAM:
			if next_state != State.ROAM and next_state != State.WANDER:
				$FaceDownTimeoutTimer.start()
				await faced_down
				$FaceDownTimeoutTimer.stop()
		State.WANDER:
			if next_state != State.ROAM and next_state != State.WANDER:
				$FaceDownTimeoutTimer.start()
				change_state(State.ROAM)
				await faced_down
				$FaceDownTimeoutTimer.stop()
		State.SLEEP:
			if $AnimationPlayer.current_animation == "sleep_loop":
				await $AnimationPlayer.animation_finished
			$AnimationPlayer.play("sleep_outro")
			await $AnimationPlayer.animation_finished
	change_state(pop_state_deck())
	$StateChangeTimer.start()

func _on_update_timer_timeout():
	pet_changed.emit()

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "sleep_loop":
		$AnimationPlayer.play("sleep_loop")
	if anim_name == "pet":
		$StateChangeTimer.paused = false
		if last_state == State.SLEEP:
			change_state(State.IDLE)
		else:
			change_state(last_state)
	if anim_name == "idle":
		blink_countdown -= 1
		if blink_countdown <= 0:
			if blink_deck.is_empty():
				blink_deck = blink_starting_deck.duplicate()
				blink_deck.shuffle()
			blink_countdown = blink_deck.pop_front()
			$AnimationPlayer.play("idle_blink")
		else:
			$AnimationPlayer.play("idle")
	if anim_name == "idle_blink":
		$AnimationPlayer.play("idle")

func _on_face_down_timeout_timer_timeout():
	faced_down.emit()
