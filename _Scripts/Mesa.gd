extends Node2D

# --- REFERENCIAS ---
@onready var mano = $MiMano 
@onready var label_puntos = $CanvasLayer/PuntajeLabel
@onready var reproductor = $AudioStreamPlayer


# --- CONFIGURACIÓN VISUAL ---
var ancho_ficha: float = 50.0 
var alto_ficha: float = 97.0 
var separacion: float = 0.0

# --- MODIFICADORES DE PUNTAJE (Power-ups / Reliquias) ---
@export var multiplicador_capicua: int = 3

# --- CONFIGURACIÓN SONORA ---
@export var Sfx_PonerFicha = AudioStream

# --- ESTADO DEL JUEGO (DATOS) ---
var extremo_izquierdo: int = -1
var extremo_derecho: int = -1
var es_primer_turno: bool = true
var suma_total_puntos: int = 0

# --- ESTADO VISUAL ---
var borde_izquierdo_x: float = 0.0
var borde_derecho_x: float = 0.0

# --- NUEVO: ESTADO DE LA MESA ---
# Variable para saber si el mouse está sobre la zona válida
var mouse_sobre_mesa: bool = false

func _ready():
	if mano:
		mano.intento_de_jugada.connect(_validar_jugada)
	else:
		print("ERROR: No se encontró el nodo Mano")

# --- NUEVAS FUNCIONES: CONTROL DE ZONA (Conectadas desde el Editor) ---

func _on_zona_mesa_mouse_entered():
	mouse_sobre_mesa = true

func _on_zona_mesa_mouse_exited():
	mouse_sobre_mesa = false

# ESTA FUNCIÓN PERMITE JUGAR HACIENDO CLIC EN LA MESA
func _on_zona_mesa_input_event(_viewport, event, _shape_idx):
	# Si hacemos clic izquierdo en la mesa...
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# ... y tenemos una ficha seleccionada en la mano...
		if mano.ficha_seleccionada_actual != null:
			print("Clic en mesa con ficha seleccionada. Intentando jugar...")
			# ... intentamos jugarla directamente.
			_validar_jugada(mano.ficha_seleccionada_actual)


# --- ÁRBITRO: ¿ES LEGAL LA JUGADA? ---
# --- ÁRBITRO: ¿ES LEGAL LA JUGADA? ---
# --- ÁRBITRO: ¿ES LEGAL LA JUGADA? ---
func _validar_jugada(ficha: Ficha):
	
	if not mouse_sobre_mesa:
		print("Jugada cancelada: Ficha soltada fuera de la mesa.")
		return

	print("Analizando ficha: ", ficha.valor_izq, "-", ficha.valor_der)
	
	if es_primer_turno:
		print("¡Primera jugada aceptada!")
		jugar_ficha(ficha, "centro")
		return

	# 1. Evaluamos DE QUÉ LADO soltó el jugador la ficha
	var posicion_mouse_x = get_local_mouse_position().x
	var intencion_izquierda = (posicion_mouse_x < 0)
	
	# 2. Evaluamos DÓNDE cabe legalmente
	var cabe_izq = (ficha.valor_der == extremo_izquierdo or ficha.valor_izq == extremo_izquierdo)
	var cabe_der = (ficha.valor_izq == extremo_derecho or ficha.valor_der == extremo_derecho)
	var es_capicua = (cabe_izq and cabe_der)

	# 3. LÓGICA DE CAPICÚA
	if es_capicua:
		print("¡CAPICÚA! Bono activado.")
		# Decidimos el lado basándonos en dónde soltó el mouse el jugador y activamos el bono (true)
		if intencion_izquierda:
			print("Capicúa jugada a la Izquierda por elección del jugador.")
			jugar_ficha(ficha, "izquierda", true)
		else:
			print("Capicúa jugada a la Derecha por elección del jugador.")
			jugar_ficha(ficha, "derecha", true)
		return

	# 4. LÓGICA NORMAL (No es capicúa)
	if intencion_izquierda and cabe_izq:
		print("¡Conecta por la Izquierda (Intención respetada)!")
		jugar_ficha(ficha, "izquierda")
		return
	elif not intencion_izquierda and cabe_der:
		print("¡Conecta por la Derecha (Intención respetada)!")
		jugar_ficha(ficha, "derecha")
		return
		
	# 5. AUTO-CORRECCIÓN AMIGABLE (Quality of Life)
	if cabe_izq:
		print("¡Conecta por la Izquierda (Auto-corregido)!")
		jugar_ficha(ficha, "izquierda")
		return
	if cabe_der:
		print("¡Conecta por la Derecha (Auto-corregido)!")
		jugar_ficha(ficha, "derecha")
		return
	
	print("Jugada ILEGAL: Números no coinciden. Vuelve a la mano.")
	
		# --- VISUALIZADOR (RESTO DEL CÓDIGO IGUAL QUE ANTES) ---
	
func jugar_ficha(ficha: Ficha, lado: String, es_capicua: bool = false):
	var es_doble = (ficha.valor_izq == ficha.valor_der)
	var ancho_ocupado_por_esta_ficha = ancho_ficha if es_doble else alto_ficha
	
	var pos_final: Vector2
	var pos_rebote: Vector2 # Guardará la coordenada del lado contrario para el rebote
	
	if es_primer_turno:
		extremo_izquierdo = ficha.valor_izq
		extremo_derecho = ficha.valor_der
		es_primer_turno = false
		ficha.posicionDefault = Vector2.ZERO
		if es_doble: ficha.rotation_degrees = 0
		else: ficha.rotation_degrees = -90
		borde_izquierdo_x = - (ancho_ocupado_por_esta_ficha / 2.0)
		borde_derecho_x =   (ancho_ocupado_por_esta_ficha / 2.0)
		finalizar_jugada(ficha)
		return

	if lado == "izquierda":
		if es_doble:
			ficha.rotation_degrees = 0
			extremo_izquierdo = ficha.valor_izq 
		else:
			if ficha.valor_der == extremo_izquierdo:
				ficha.rotation_degrees = -90
				extremo_izquierdo = ficha.valor_izq
			else:
				ficha.rotation_degrees = 90
				extremo_izquierdo = ficha.valor_der
		
		# Calculamos dónde va a quedar
		var nueva_x = borde_izquierdo_x - (ancho_ocupado_por_esta_ficha / 2.0) - separacion
		pos_final = Vector2(nueva_x, 0)
		# Calculamos el rebote visual en la derecha
		pos_rebote = Vector2(borde_derecho_x + (ancho_ocupado_por_esta_ficha / 2.0) + separacion, 0)
		
		borde_izquierdo_x -= (ancho_ocupado_por_esta_ficha + separacion)

	elif lado == "derecha":
		if es_doble:
			ficha.rotation_degrees = 0
			extremo_derecho = ficha.valor_der
		else:
			if ficha.valor_izq == extremo_derecho:
				ficha.rotation_degrees = -90
				extremo_derecho = ficha.valor_der
			else:
				ficha.rotation_degrees = 90
				extremo_derecho = ficha.valor_izq
				
		var nueva_x = borde_derecho_x + (ancho_ocupado_por_esta_ficha / 2.0) + separacion
		pos_final = Vector2(nueva_x, 0)
		# Calculamos el rebote visual en la izquierda
		pos_rebote = Vector2(borde_izquierdo_x - (ancho_ocupado_por_esta_ficha / 2.0) - separacion, 0)
		
		borde_derecho_x += (ancho_ocupado_por_esta_ficha + separacion)

	# --- BIFURCACIÓN DE ANIMACIÓN ---
	if es_capicua:
		_animar_rebote_capicua(ficha, pos_final, pos_rebote)
	else:
		ficha.posicionDefault = pos_final
		finalizar_jugada(ficha, false)


func finalizar_jugada(ficha: Ficha, es_capicua: bool = false):
	ficha.bloquear()
	
	# --- 1. MOTOR DE PUNTUACIÓN ---
	# Calculamos los puntos base (la suma de los números de la ficha jugada)
	var puntos_base = ficha.valor_izq + ficha.valor_der
	var puntos_a_sumar = puntos_base
	
	# Aplicamos modificadores si corresponde
	if es_capicua:
		puntos_a_sumar = puntos_base * multiplicador_capicua
		print("🔥 ¡BONO CAPICÚA! Puntos base: ", puntos_base, " x ", multiplicador_capicua, " = ", puntos_a_sumar)
		
		# [Espacio reservado: Aquí luego llamaremos a la animación de la ficha rebotando]
	
	# Añadimos al banco total
	suma_total_puntos += puntos_a_sumar
	
	# --- 2. ACTUALIZAR INTERFAZ ---
	if label_puntos:
		label_puntos.text = "Puntos en Mesa: %d" % suma_total_puntos
	
	# --- 3. LIMPIEZA Y SONIDO ---
	if mano.ficha_seleccionada_actual == ficha:
		mano.ficha_seleccionada_actual = null
	
	reproductor.stream = Sfx_PonerFicha
	reproductor.pitch_scale = randf_range(0.95, 1.05)
	reproductor.play()
	
	print("MESA ACTUAL: ", extremo_izquierdo, " ... ", extremo_derecho)

	
func _animar_rebote_capicua(ficha: Ficha, pos_final: Vector2, pos_rebote: Vector2):
	# 1. Preparamos la ficha para que no interfiera el _process
	ficha.arrastrando = false
	ficha.en_animacion_especial = true
	ficha.z_index = 20 # Para que pase por encima de las demás durante el rebote
	
	# 2. Creamos la secuencia (Tween)
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var tiempo_golpe = 0.25 # Qué tan rápido viaja
	
	# GOLPE 1: Va al lado elegido
	tween.tween_property(ficha, "global_position", pos_final, tiempo_golpe)
	tween.tween_callback(_reproducir_sonido_rebote)
	
	# GOLPE 2: Viaja cruzando toda la mesa hasta el otro extremo
	tween.tween_property(ficha, "global_position", pos_rebote, tiempo_golpe * 1.5) # Un poco más lento porque recorre más distancia
	tween.tween_callback(_reproducir_sonido_rebote)
	
	# GOLPE 3: Vuelve al lado original
	tween.tween_property(ficha, "global_position", pos_final, tiempo_golpe * 1.5)
	
	# FINAL: Restablece estados y finaliza la jugada sumando el bono
	tween.tween_callback(func():
		ficha.en_animacion_especial = false
		ficha.posicionDefault = pos_final
		finalizar_jugada(ficha, true) # true = es capicua, aplica el bono
	)

func _reproducir_sonido_rebote():
	# Reutilizamos el sonido de poner ficha, pero con un tono agudo para que suene a "rebote"
	reproductor.stream = Sfx_PonerFicha
	reproductor.pitch_scale = randf_range(1.3, 1.5)
	reproductor.play()
