extends Node2D

var arrastrando = false
var offset = Vector2.ZERO #el offset va a ser (0,0) al empezar. (para que la ficha no snappee a la posicion del mouse, sino que se agarre desde cualquier parte de la ficha)
var posicionDefault = Vector2.ZERO
var seleccionado = false
var escalaX = 2
var escalaY = 2
var posicion_inicial_click = Vector2.ZERO #Guardará dónde estaba la ficha cuando hiciste clic para comparar después

func Porcentaje(porciento, numero):
	var resultado = numero * (porciento * 0.01) 
	return resultado

func _process(delta):
	if arrastrando == true:
		global_position = get_global_mouse_position() - offset
	else:
		global_position = lerp(global_position, posicionDefault, 25*delta)

	# LOGICA VISUAL UNIFICADA:
	# Si está seleccionada O si la estoy arrastrando, se pone grande.
	if seleccionado == true or arrastrando == true:
		scale = Vector2(escalaX + Porcentaje(30, escalaX), escalaY + Porcentaje(30, escalaY)) #subirle el tamaño un poco cuando esta seleccionada
		z_index = 1 # Traer al frente
	else:
		scale = Vector2(escalaX, escalaY) #volver a escala default
		z_index = 0 #volver a la capa default

func _ready():
	var pantalla = get_viewport_rect().size #calcular el tamaÑo de la pantalla
	
	#calcular coordenadas
	position = Vector2(pantalla.x/2, pantalla.y - 150)
	posicionDefault = position
	
	scale = Vector2(escalaX, escalaY)

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			
			# CUANDO PRESIONAS (DOWN)
			if event.pressed:
				arrastrando = true
				
				# Guardamos la posición exacta al momento de dar click
				posicion_inicial_click = global_position
				
				#basicamente el offset sera: posicion mouse - posicion ficha
				offset = get_global_mouse_position() - global_position 
				
				print("Click Presionado")

			# CUANDO SUELTAS (UP)
			else:
				arrastrando = false
				
				# Calculamos cuánto se movió la ficha desde que hiciste click hasta que soltaste.
				var distancia_movida = global_position.distance_to(posicion_inicial_click)
				
				# Si se movió menos de 5 píxeles, asumimos que fue un CLIC DE SELECCIÓN (No querías arrastrar)
				if distancia_movida < 5:
					# Interruptor: Si era false se vuelve true, si era true se vuelve false.
					seleccionado = not seleccionado
					print("Ficha Seleccionada/Deseleccionada")
				
				# Si se movió más de 5 píxeles, fue un ARRASTRE.
				else:
					print("Ficha Arrastrada y Soltada")
