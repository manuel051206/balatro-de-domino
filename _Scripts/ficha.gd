class_name Ficha extends Area2D

# --- SEÑALES ---
# Avisamos al juego que esta ficha fue interactuada
signal click_en_ficha(ficha: Ficha)
signal soltada_en_posicion(ficha: Ficha)

# --- CONFIGURACIÓN (Editables en el Inspector) ---
@export_group("Configuración Visual")
@export var velocidad_retorno: float = 25.0
@export var escala_base: Vector2 = Vector2(1, 1)
@export var aumento_seleccion: float = 30.0 # Porcentaje de aumento

# --- DATOS DE LA FICHA (Lógica del Dominó) ---
var valor_izq: int = 6
var valor_der: int = 6

# --- ESTADO INTERNO ---
var arrastrando: bool = false
var seleccionado: bool = false
var offset: Vector2 = Vector2.ZERO # el offset va a ser (0,0) al empezar.
var posicionDefault: Vector2 = Vector2.ZERO
var posicion_inicial_click: Vector2 = Vector2.ZERO # Guardará dónde estaba la ficha cuando hiciste clic

@onready var sprite: Sprite2D = $Sprite # Asumiendo que tienes un Sprite2D hijo

func _ready():
	# Si no se ha definido una posición externa, usamos la actual
	if posicionDefault == Vector2.ZERO:
		posicionDefault = position
	
	scale = escala_base
	
	var pantalla = get_viewport_rect().size #calcular el tamaÑo de la pantalla


	#calcular coordenadas

	position = Vector2(pantalla.x/2, pantalla.y - 150)

	posicionDefault = position





# Función para inyectar datos (Como vimos en el paso anterior)
func setup(v_izq: int, v_der: int, textura: Texture2D):
	valor_izq = v_izq
	valor_der = v_der
	if sprite:
		sprite.texture = textura
	# Ajustamos el nombre para facilitar el debug
	name = "Ficha_%d_%d" % [valor_izq, valor_der]

# Tu función auxiliar (Tipada para mejorar rendimiento)
func Porcentaje(porciento: float, numero: float) -> float:
	var resultado = numero * (porciento * 0.01) 
	return resultado

func _process(delta):
	if arrastrando:
		# Mover con el mouse
		global_position = get_global_mouse_position() - offset
	else:
		# Efecto magnético de retorno (Lerp)
		global_position = global_position.lerp(posicionDefault, velocidad_retorno * delta)

# Esta función maneja el cambio visual SOLO cuando es necesario (Event Driven)
func actualizar_visuales():
	# LOGICA VISUAL UNIFICADA:
	if seleccionado or arrastrando:
		# Usamos create_tween para animaciones suaves (Juice tipo Balatro)
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var nueva_escala_x = escala_base.x + Porcentaje(aumento_seleccion, escala_base.x)
		var nueva_escala_y = escala_base.y + Porcentaje(aumento_seleccion, escala_base.y)
		
		# Animamos la escala en 0.1 segundos
		tween.tween_property(self, "scale", Vector2(nueva_escala_x, nueva_escala_y), 0.1)
		z_index = 10 # Traer al frente
	else:
		# Volver a la normalidad
		var tween = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", escala_base, 0.2)
		z_index = 0 # volver a la capa default


func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			
			# CUANDO PRESIONAS (DOWN)
			if event.pressed:
				arrastrando = true
				
				# Guardamos la posición exacta al momento de dar click
				posicion_inicial_click = global_position
				
				# basicamente el offset sera: posicion mouse - posicion ficha
				offset = get_global_mouse_position() - global_position 
				
				actualizar_visuales() # Actualizamos aspecto
				print("Click Presionado en ", name)

			# CUANDO SUELTAS (UP)
			else:
				arrastrando = false
				
				# Calculamos cuánto se movió la ficha desde que hiciste click hasta que soltaste.
				var distancia_movida = global_position.distance_to(posicion_inicial_click)
				
				# Si se movió menos de 5 píxeles, asumimos que fue un CLIC DE SELECCIÓN
				if distancia_movida < 5:
					# Interruptor: Si era false se vuelve true, si era true se vuelve false.
					seleccionado = not seleccionado
					
					# AVISAMOS AL JUEGO
					click_en_ficha.emit(self)
					print("Ficha Seleccionada/Deseleccionada")
				
				# Si se movió más de 5 píxeles, fue un ARRASTRE.
				else:
					soltada_en_posicion.emit(self)
					print("Ficha Arrastrada y Soltada")
				
				actualizar_visuales() # Actualizamos aspecto al soltar
