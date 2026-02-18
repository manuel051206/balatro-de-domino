extends Node2D

# --- REFERENCIAS ---
@onready var mano = $MiMano 
@onready var label_puntos = $CanvasLayer/PuntajeLabel
@onready var reproductor = $AudioStreamPlayer


# --- CONFIGURACIÓN VISUAL ---
var ancho_ficha: float = 50.0 
var alto_ficha: float = 97.0 
var separacion: float = 0.0

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
func _validar_jugada(ficha: Ficha):
	
	# RESTRICCIÓN 1: ¿Estamos jugando sobre la mesa?
	# Si se intentó jugar arrastrando (drag & drop), verificamos dónde está el mouse.
	# (Si fue por clic directo, mouse_sobre_mesa ya será true).
	if not mouse_sobre_mesa:
		print("Jugada cancelada: Ficha soltada fuera de la mesa.")
		# No hacemos nada, la ficha volverá a la mano sola.
		return

	print("Analizando ficha: ", ficha.valor_izq, "-", ficha.valor_der)
	
	# REGLA 2: Primer turno
	if es_primer_turno:
		print("¡Primera jugada aceptada!")
		jugar_ficha(ficha, "centro")
		return

	# REGLA 3: Izquierda
	if ficha.valor_der == extremo_izquierdo or ficha.valor_izq == extremo_izquierdo:
		print("¡Conecta por la Izquierda!")
		jugar_ficha(ficha, "izquierda")
		return

	# REGLA 4: Derecha
	if ficha.valor_izq == extremo_derecho or ficha.valor_der == extremo_derecho:
		print("¡Conecta por la Derecha!")
		jugar_ficha(ficha, "derecha")
		return
	
	print("Jugada ILEGAL: Números no coinciden. Vuelve a la mano.")

# --- VISUALIZADOR (RESTO DEL CÓDIGO IGUAL QUE ANTES) ---
func jugar_ficha(ficha: Ficha, lado: String):
	
	var es_doble = (ficha.valor_izq == ficha.valor_der)
	var ancho_ocupado_por_esta_ficha = ancho_ficha if es_doble else alto_ficha
	
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
		var nueva_x = borde_izquierdo_x - (ancho_ocupado_por_esta_ficha / 2.0) - separacion
		ficha.posicionDefault = Vector2(nueva_x, 0)
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
		ficha.posicionDefault = Vector2(nueva_x, 0)
		borde_derecho_x += (ancho_ocupado_por_esta_ficha + separacion)

	finalizar_jugada(ficha)

func finalizar_jugada(ficha: Ficha):
	ficha.bloquear()
	# 1. SUMA MATEMÁTICA
	# Sumamos los dos lados de la ficha colocada al total
	suma_total_puntos += (ficha.valor_izq + ficha.valor_der)
	
	# 2. ACTUALIZAR INTERFAZ
	# Convertimos el número a texto y lo mostramos
	if label_puntos:
		label_puntos.text = "Puntos en Mesa: %d" % suma_total_puntos
	
	
	# Limpieza de referencia (tu código anterior)
	if mano.ficha_seleccionada_actual == ficha:
		mano.ficha_seleccionada_actual = null
	
		# --- SONIDO: PONER FICHA ---
	reproductor.stream = Sfx_PonerFicha
	# Pequeña variación de tono para realismo
	reproductor.pitch_scale = randf_range(0.95, 1.05)
	reproductor.play()
	
		
	print("MESA ACTUAL: ", extremo_izquierdo, " ... ", extremo_derecho)
