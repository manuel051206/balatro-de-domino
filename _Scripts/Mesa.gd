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
	
	# NUEVA LÓGICA DE CAPICÚA:
	# Verificamos que un lado de la ficha sea igual al extremo izquierdo Y el otro al derecho.
	var es_capicua = (
		(ficha.valor_izq == extremo_izquierdo and ficha.valor_der == extremo_derecho) or 
		(ficha.valor_der == extremo_izquierdo and ficha.valor_izq == extremo_derecho)
	)

	# 3. LÓGICA DE CAPICÚA
	if es_capicua:
		# NUEVO PRINT DE DEBUG: Explica exactamente el porqué
		print("¡CAPICÚA DETECTADA! -> Ficha [%d-%d] empata perfectamente con los extremos de la mesa [%d...%d]" % [ficha.valor_izq, ficha.valor_der, extremo_izquierdo, extremo_derecho])
		
		# Decidimos el lado basándonos en dónde soltó el mouse el jugador y activamos el bono (true)
		if intencion_izquierda:
			print("- Se decidió colocar a la Izquierda por elección del jugador.")
			jugar_ficha(ficha, "izquierda", true)
		else:
			print("- Se decidió colocar a la Derecha por elección del jugador.")
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
	var pos_rebote: Vector2 
	var rotacion_final: float = 0.0 # ¡NUEVO! Guardamos la rotación en vez de aplicarla de golpe
	
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
			rotacion_final = 0
			extremo_izquierdo = ficha.valor_izq 
		else:
			if ficha.valor_der == extremo_izquierdo:
				rotacion_final = -90
				extremo_izquierdo = ficha.valor_izq
			else:
				rotacion_final = 90
				extremo_izquierdo = ficha.valor_der
		
		var nueva_x = borde_izquierdo_x - (ancho_ocupado_por_esta_ficha / 2.0) - separacion
		pos_final = Vector2(nueva_x, 0)
		pos_rebote = Vector2(borde_derecho_x + (ancho_ocupado_por_esta_ficha / 2.0) + separacion, 0)
		
		borde_izquierdo_x -= (ancho_ocupado_por_esta_ficha + separacion)

	elif lado == "derecha":
		if es_doble:
			rotacion_final = 0
			extremo_derecho = ficha.valor_der
		else:
			if ficha.valor_izq == extremo_derecho:
				rotacion_final = -90
				extremo_derecho = ficha.valor_der
			else:
				rotacion_final = 90
				extremo_derecho = ficha.valor_izq
				
		var nueva_x = borde_derecho_x + (ancho_ocupado_por_esta_ficha / 2.0) + separacion
		pos_final = Vector2(nueva_x, 0)
		pos_rebote = Vector2(borde_izquierdo_x - (ancho_ocupado_por_esta_ficha / 2.0) - separacion, 0)
		
		borde_derecho_x += (ancho_ocupado_por_esta_ficha + separacion)

	# --- BIFURCACIÓN DE ANIMACIÓN ---
	if es_capicua:
		# Le pasamos la rotación final a la animación
		_animar_rebote_capicua(ficha, pos_final, pos_rebote, rotacion_final)
	else:
		# Si es una jugada normal, la rotamos de golpe y la soltamos (como siempre)
		ficha.rotation_degrees = rotacion_final
		ficha.posicionDefault = pos_final
		finalizar_jugada(ficha, false)


func finalizar_jugada(ficha: Ficha, es_capicua: bool = false):
	ficha.bloquear()
	
	if mano:
		mano.quitar_ficha_jugada(ficha)
	
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
	
	
func _animar_rebote_capicua(ficha: Ficha, pos_final: Vector2, pos_rebote: Vector2, rotacion_final: float):
	# 1. Preparación: Tomamos control total de la ficha
	ficha.arrastrando = false
	ficha.en_animacion_especial = true
	ficha.z_index = 50 
	
	var tween = create_tween()
	
	# --- FASE 1: EL VUELO ACROBÁTICO ---
	# En lugar de subir desde donde está, calculamos un punto en el aire EXACTAMENTE arriba de su meta.
	var pos_elevada = pos_final + Vector2(0, -60)
	
	# Vuela hacia el punto elevado (0.3s)
	tween.tween_property(ficha, "global_position", pos_elevada, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# MIENTRAS vuela, gira en el aire hasta acomodarse a su rotación perfecta
	tween.parallel().tween_property(ficha, "rotation_degrees", rotacion_final, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# MIENTRAS vuela, se hace un 30% más grande
	tween.parallel().tween_property(ficha, "scale", ficha.escala_base * 1.3, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# --- FASE 2: EL PRIMER IMPACTO ---
	tween.tween_property(ficha, "global_position", pos_final, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(_reproducir_sonido_rebote) 
	tween.tween_property(ficha, "scale", ficha.escala_base * Vector2(1.2, 0.8), 0.05)
	
	# --- FASE 3: EL VIAJE DE REBOTE ---
	tween.tween_property(ficha, "global_position", pos_rebote, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(ficha, "scale", ficha.escala_base * 1.3, 0.1) 
	
	tween.tween_callback(_reproducir_sonido_rebote) 
	tween.tween_property(ficha, "scale", ficha.escala_base * Vector2(1.2, 0.8), 0.05) 
	
	# --- FASE 4: REGRESO TRIUNFAL ---
	tween.tween_property(ficha, "global_position", pos_final, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ficha, "scale", ficha.escala_base, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# --- FINAL: DEVOLVER EL CONTROL ---
	tween.tween_callback(func():
		ficha.en_animacion_especial = false
		ficha.posicionDefault = pos_final
		ficha.rotation_degrees = rotacion_final # Seguro final por si acaso
		finalizar_jugada(ficha, true) 
	)

func _reproducir_sonido_rebote():
	# Reutilizamos el sonido de poner ficha, pero con un tono agudo para que suene a "rebote"
	reproductor.stream = Sfx_PonerFicha
	reproductor.pitch_scale = randf_range(1.3, 1.5)
	reproductor.play()


func _on_boton_pozo_pressed():
	print("Botón del Pozo presionado")
	#Guardamos la coordenada del mundo donde se hizo el clic
	var posicion_origen = get_global_mouse_position()
	# Le damos la orden al gerente de la mano para que robe una ficha
	if mano:
		mano.robar_del_pozo(posicion_origen)
