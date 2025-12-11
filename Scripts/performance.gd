extends Label

func _process(_delta):
	# 1. Get FPS
	var fps = Engine.get_frames_per_second()
	
	# 2. Get Draw Calls (The most important number for Web)
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	# 3. Get Total Objects (How many meshes are actually being seen)
	var objects = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	
	# 4. Update the text
	text = "FPS: %d\nDraw Calls: %d\nObjects: %d" % [fps, draw_calls, objects]
	
	# Color coding for quick feedback
	if draw_calls < 500:
		modulate = Color.GREEN # Safe for Web
	elif draw_calls < 1000:
		modulate = Color.YELLOW # Warning
	else:
		modulate = Color.RED # Danger Zone (Lag likely on mobile/web)
