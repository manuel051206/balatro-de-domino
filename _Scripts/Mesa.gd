extends Node2D

# --- REFERENCIAS ---
@onready var mano = $MiMano 
@onready var label_puntos = $CanvasLayer/PuntajeLabel
@onready var label_puntos_mano = $CanvasLayer/PuntosManoLabel
@onready var label_objetivo = $CanvasLayer/ObjetivoLabel 
@onready var label_ronda = $CanvasLayer/RondaLabel       
@onready var reproductor = $AudioStreamPlayer
@onready var boton_pozo = $CanvasLayer2/BotonPozo
@onready var label_robos = $CanvasLayer/RobosLabel

# --- CONFIGURACIÓN VISUAL ---
var ancho_ficha: float = 50.0 
var alto_ficha: float = 97.0 
var separacion: float = 0.0

# --- CONFIGURACIÓN DE LA PARTIDA ---
@export_category("Reglas de Partida")
@export var modo_debug: bool = true 
@export var rondas_maximas: int = 3
@export var robos_maximos: int = 3
@export var puntaje_objetivo_base: int = 150

@export_category("Multiplicadores")
@export var multiplicador_capicua: int = 3
@export var multiplicador_global_castigo: int = 5 

# --- CONFIGURACIÓN SONORA ---
@export var Sfx_PonerFicha = AudioStream

# --- ESTADO DE LA PARTIDA ---
var mesa_actual: int = 1
var ronda_actual: int = 1
var puntos_ronda_actual: int = 0 
var robos_restantes: int = 3
var juego_terminado: bool = false

# --- ESTADO DEL JUEGO (DATOS) ---
var extremo_izquierdo: int = -1
var extremo_derecho: int = -1
var es_primer_turno: bool = true
var suma_total_puntos: int = 0
var historial_jugadas: Array = []

# --- LÍMITES DE LA PANTALLA (El "Radar") ---
var limite_izquierdo_x: float = -450.0 
var limite_derecho_x: float = 450.0

# --- ESTADO VISUAL 2D (Máquina de Estados) ---
var estado_izq: int = 0 
var estado_der: int = 0

var es_primer_regreso_izq: bool = false
var es_primer_regreso_der: bool = false

var ultima_ficha_izq: Ficha = null
var ultima_ficha_der: Ficha = null

var nivel_y_izq: float = 0.0
var nivel_y_der: float = 0.0

var mouse_sobre_mesa: bool = false

func _ready():
	if mano:
		mano.intento_de_jugada.connect(_validar_jugada)
	# Intentamos cargar la partida
	if SaveManager.cargar_partida():
		var datos = SaveManager.datos_partida
		mesa_actual = int(datos.get("mesa_actual", 1))
		ronda_actual = int(datos.get("ronda_actual", 1))
		robos_restantes = int(datos.get("robos_restantes", robos_maximos))
		suma_total_puntos = int(datos.get("suma_total_puntos", 0))
		puntos_ronda_actual = int(datos.get("puntos_ronda_actual", 0))
		puntaje_objetivo_base = int(datos.get("puntaje_objetivo_base", puntaje_objetivo_base))
		print("🔍 DEBUG LECTURA JSON - Objetivo leído: ", puntaje_objetivo_base)
		# Extraemos el historial y lo reconstruimos
		historial_jugadas = datos.get("historial_jugadas", [])
		if not historial_jugadas.is_empty():
			reconstruir_serpiente(historial_jugadas)
		# ¡Le damos a la mano su estado guardado!
		if mano:
			var mano_guardada = datos.get("fichas_en_mano", [])
			var pozo_guardado = datos.get("pozo_de_fichas", [])
			mano.cargar_estado(mano_guardada, pozo_guardado)
	
	else:
		#Si NO hay partida, inicializamos normal
		robos_restantes = robos_maximos
		if mano:
			mano.generar_mano_inicial() # Ahora la Mesa da la orden de empezar
	actualizar_ui()

# --- FUNCIONES: CONTROL DE ZONA ---
func _on_zona_mesa_mouse_entered(): mouse_sobre_mesa = true
func _on_zona_mesa_mouse_exited(): mouse_sobre_mesa = false

func _on_zona_mesa_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if mano.ficha_seleccionada_actual != null:
			_validar_jugada(mano.ficha_seleccionada_actual)

# --- ÁRBITRO: ¿ES LEGAL LA JUGADA? ---
func _validar_jugada(ficha: Ficha):
	if juego_terminado:
		return
	if not mouse_sobre_mesa: return

	if es_primer_turno:
		jugar_ficha(ficha, "centro")
		return

	var posicion_mouse_x = get_local_mouse_position().x
	var intencion_izquierda = (posicion_mouse_x < 0)
	
	var cabe_izq = (ficha.valor_der == extremo_izquierdo or ficha.valor_izq == extremo_izquierdo)
	var cabe_der = (ficha.valor_izq == extremo_derecho or ficha.valor_der == extremo_derecho)
	
	var es_capicua = (
		(ficha.valor_izq == extremo_izquierdo and ficha.valor_der == extremo_derecho) or 
		(ficha.valor_der == extremo_izquierdo and ficha.valor_izq == extremo_derecho)
	)

	if es_capicua:
		if intencion_izquierda: jugar_ficha(ficha, "izquierda", true)
		else: jugar_ficha(ficha, "derecha", true)
		return

	if intencion_izquierda and cabe_izq:
		jugar_ficha(ficha, "izquierda")
		return
	elif not intencion_izquierda and cabe_der:
		jugar_ficha(ficha, "derecha")
		return
		
	if cabe_izq:
		jugar_ficha(ficha, "izquierda")
		return
	if cabe_der:
		jugar_ficha(ficha, "derecha")
		return
	
# --- SISTEMA ANTI-TRAMPAS ---
func jugador_tiene_jugada_valida() -> bool:
	if es_primer_turno: 
		return true
		
	for ficha in mano.fichas_en_mano:
		var cabe_izq = (ficha.valor_izq == extremo_izquierdo or ficha.valor_der == extremo_izquierdo)
		var cabe_der = (ficha.valor_izq == extremo_derecho or ficha.valor_der == extremo_derecho)
		
		if cabe_izq or cabe_der:
			return true 
			
	return false 

# --- EL GERENTE VISUAL ---
func jugar_ficha(ficha: Ficha, lado: String, es_capicua: bool = false, es_reconstruccion: bool = false):
	# Guarda el historial si es una jugada real
	if not es_reconstruccion:
		historial_jugadas.append({"v1": ficha.valor_izq, "v2": ficha.valor_der, "lado": lado})
	
	var es_doble = (ficha.valor_izq == ficha.valor_der)
	var pos_final: Vector2
	var pos_rebote: Vector2 
	var rotacion_final: float = 0.0 
	
	if es_primer_turno:
		extremo_izquierdo = ficha.valor_izq
		extremo_derecho = ficha.valor_der
		es_primer_turno = false
		
		ficha.posicionDefault = Vector2.ZERO
		ficha.rotation_degrees = 0.0 if es_doble else -90.0
		
		ultima_ficha_izq = ficha
		ultima_ficha_der = ficha
		nivel_y_izq = 0.0
		nivel_y_der = 0.0
		estado_izq = 0
		estado_der = 0
		es_primer_regreso_izq = false
		es_primer_regreso_der = false
		
		finalizar_jugada(ficha, false, es_reconstruccion)
		return
	
	var datos = _calcular_geometria(ficha, lado, es_doble)
	
	pos_final = datos["pos"]
	rotacion_final = datos["rot"]
	pos_rebote = datos["rebote"]
	
	if lado == "izquierda": ultima_ficha_izq = ficha
	elif lado == "derecha": ultima_ficha_der = ficha
	
	if es_reconstruccion:
		# En reconstrucción, ignoramos animaciones capicúa y encajamos de golpe
		ficha.rotation_degrees = rotacion_final
		ficha.posicionDefault = pos_final
		ficha.global_position = pos_final
		finalizar_jugada(ficha, false, true)
		return

	if es_capicua:
		_animar_rebote_capicua(ficha, pos_final, pos_rebote, rotacion_final)
	else:
		ficha.rotation_degrees = rotacion_final
		ficha.posicionDefault = pos_final
		finalizar_jugada(ficha, false)

# --- EL INGENIERO DE LA SERPIENTE (V9 - GEOMETRÍA REAL Y CUADRANTES) ---
func _calcular_geometria(ficha: Ficha, lado: String, es_doble: bool) -> Dictionary:
	var resultado = {"pos": Vector2.ZERO, "rot": 0.0, "rebote": Vector2.ZERO}

	if lado == "izquierda":
		var last_center = ultima_ficha_izq.posicionDefault
		
		if estado_izq == 0 and (last_center.x - alto_ficha) < limite_izquierdo_x:
			estado_izq = 1 

		# --- ROTACIONES ---
		if estado_izq == 0:
			if es_doble:
				resultado["rot"] = 0 
				extremo_izquierdo = ficha.valor_izq 
			else:
				resultado["rot"] = -90 if ficha.valor_der == extremo_izquierdo else 90
				extremo_izquierdo = ficha.valor_izq if ficha.valor_der == extremo_izquierdo else ficha.valor_der
				
		elif estado_izq == 1:
			if es_doble:
				resultado["rot"] = 0 
				extremo_izquierdo = ficha.valor_izq
			else:
				resultado["rot"] = 180 if ficha.valor_izq == extremo_izquierdo else 0
				extremo_izquierdo = ficha.valor_der if ficha.valor_izq == extremo_izquierdo else ficha.valor_izq
				
		elif estado_izq == 2:
			if es_doble:
				resultado["rot"] = 90 if es_primer_regreso_izq else 0
				extremo_izquierdo = ficha.valor_izq
			else:
				resultado["rot"] = 90 if ficha.valor_der == extremo_izquierdo else -90
				extremo_izquierdo = ficha.valor_izq if ficha.valor_der == extremo_izquierdo else ficha.valor_der

		# --- TAMAÑOS Y ESTADO DE LA ANTERIOR ---
		var rot_abs = int(abs(resultado["rot"])) % 180
		var es_vert = (rot_abs == 0)
		var new_w = ancho_ficha if es_vert else alto_ficha
		var new_h = alto_ficha if es_vert else ancho_ficha

		var old_rot_abs = int(abs(round(ultima_ficha_izq.rotation_degrees / 90.0) * 90)) % 180
		var old_es_vert = (old_rot_abs == 0)
		var old_w = ancho_ficha if old_es_vert else alto_ficha
		var old_h = alto_ficha if old_es_vert else ancho_ficha
		var cx = last_center.x
		var cy = last_center.y

		# --- POSICIONES EXACTAS ---
		if estado_izq == 0: 
			resultado["pos"] = Vector2(cx - (old_w/2.0) - separacion - (new_w/2.0), cy)
		elif estado_izq == 1: 
			# Se ancla justo encima del cuadrito izquierdo (-old_w / 4)
			var shift_x = 0.0 if old_es_vert else (-old_w / 4.0)
			resultado["pos"] = Vector2(cx + shift_x, cy - (old_h/2.0) - separacion - (new_h/2.0))
			estado_izq = 2
			es_primer_regreso_izq = true 
		elif estado_izq == 2: 
			if es_primer_regreso_izq:
				# Se ancla a la derecha de la mitad superior de la esquina (-old_h / 4)
				var shift_y = (-old_h / 4.0) if old_es_vert else 0.0
				resultado["pos"] = Vector2(cx + (old_w/2.0) + separacion + (new_w/2.0), cy + shift_y)
				nivel_y_izq = resultado["pos"].y
				es_primer_regreso_izq = false
			else:
				resultado["pos"] = Vector2(cx + (old_w/2.0) + separacion + (new_w/2.0), nivel_y_izq)
		
		resultado["rebote"] = ultima_ficha_der.posicionDefault 

	elif lado == "derecha":
		var last_center = ultima_ficha_der.posicionDefault
		
		if estado_der == 0 and (last_center.x + alto_ficha) > limite_derecho_x:
			estado_der = 1 

		# --- ROTACIONES ---
		if estado_der == 0:
			if es_doble:
				resultado["rot"] = 0 
				extremo_derecho = ficha.valor_der
			else:
				resultado["rot"] = -90 if ficha.valor_izq == extremo_derecho else 90
				extremo_derecho = ficha.valor_der if ficha.valor_izq == extremo_derecho else ficha.valor_izq
				
		elif estado_der == 1:
			if es_doble:
				resultado["rot"] = 0 
				extremo_derecho = ficha.valor_der
			else:
				resultado["rot"] = 0 if ficha.valor_izq == extremo_derecho else 180
				extremo_derecho = ficha.valor_der if ficha.valor_izq == extremo_derecho else ficha.valor_izq
				
		elif estado_der == 2:
			if es_doble:
				resultado["rot"] = 90 if es_primer_regreso_der else 0
				extremo_derecho = ficha.valor_der
			else:
				resultado["rot"] = 90 if ficha.valor_izq == extremo_derecho else -90
				extremo_derecho = ficha.valor_der if ficha.valor_izq == extremo_derecho else ficha.valor_izq

		# --- TAMAÑOS Y ESTADO DE LA ANTERIOR ---
		var rot_abs = int(abs(resultado["rot"])) % 180
		var es_vert = (rot_abs == 0)
		var new_w = ancho_ficha if es_vert else alto_ficha
		var new_h = alto_ficha if es_vert else ancho_ficha

		var old_rot_abs = int(abs(round(ultima_ficha_der.rotation_degrees / 90.0) * 90)) % 180
		var old_es_vert = (old_rot_abs == 0)
		var old_w = ancho_ficha if old_es_vert else alto_ficha
		var old_h = alto_ficha if old_es_vert else ancho_ficha
		var cx = last_center.x
		var cy = last_center.y

		# --- POSICIONES EXACTAS ---
		if estado_der == 0: 
			resultado["pos"] = Vector2(cx + (old_w/2.0) + separacion + (new_w/2.0), cy)
		elif estado_der == 1: 
			# Se ancla justo debajo del cuadrito derecho (+old_w / 4)
			var shift_x = 0.0 if old_es_vert else (old_w / 4.0)
			resultado["pos"] = Vector2(cx + shift_x, cy + (old_h/2.0) + separacion + (new_h/2.0))
			estado_der = 2
			es_primer_regreso_der = true 
		elif estado_der == 2: 
			if es_primer_regreso_der:
				# Se ancla a la izquierda de la mitad inferior de la esquina (+old_h / 4)
				var shift_y = (old_h / 4.0) if old_es_vert else 0.0
				resultado["pos"] = Vector2(cx - (old_w/2.0) - separacion - (new_w/2.0), cy + shift_y)
				nivel_y_der = resultado["pos"].y
				es_primer_regreso_der = false
			else:
				resultado["pos"] = Vector2(cx - (old_w/2.0) - separacion - (new_w/2.0), nivel_y_der)
		
		resultado["rebote"] = ultima_ficha_izq.posicionDefault 

	return resultado

# --- FINALIZACIÓN Y ANIMACIÓN ---
func finalizar_jugada(ficha: Ficha, es_capicua: bool = false, es_reconstruccion: bool = false):
	ficha.bloquear()
	
	# Si es un fantasma reconstruyéndose, terminamos aquí para no duplicar puntos
	if es_reconstruccion: 
		return
	
	if mano: mano.quitar_ficha_jugada(ficha)
	
	var puntos_base = ficha.valor_izq + ficha.valor_der
	var puntos_a_sumar = puntos_base
	
	if es_capicua:
		puntos_a_sumar = puntos_base * multiplicador_capicua
	
	# Sumamos al banco total y a la mano actual
	suma_total_puntos += puntos_a_sumar
	puntos_ronda_actual += puntos_a_sumar
	actualizar_ui()
	
	if mano.ficha_seleccionada_actual == ficha: mano.ficha_seleccionada_actual = null
	
	reproductor.stream = Sfx_PonerFicha
	reproductor.pitch_scale = randf_range(0.95, 1.05)
	reproductor.play()
	
	guardar_estado_actual() # Guarda tras cada jugada
	verificar_victoria()
	
func _animar_rebote_capicua(ficha: Ficha, pos_final: Vector2, pos_rebote: Vector2, rotacion_final: float):
	ficha.arrastrando = false
	ficha.en_animacion_especial = true
	ficha.z_index = 50 
	
	var tween = create_tween()
	var pos_elevada = pos_final + Vector2(0, -60)
	
	tween.tween_property(ficha, "global_position", pos_elevada, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ficha, "rotation_degrees", rotacion_final, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ficha, "scale", ficha.escala_base * 1.3, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(ficha, "global_position", pos_final, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(_reproducir_sonido_rebote) 
	tween.tween_property(ficha, "scale", ficha.escala_base * Vector2(1.2, 0.8), 0.05)
	
	tween.tween_property(ficha, "global_position", pos_rebote, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(ficha, "scale", ficha.escala_base * 1.3, 0.1) 
	
	tween.tween_callback(_reproducir_sonido_rebote) 
	tween.tween_property(ficha, "scale", ficha.escala_base * Vector2(1.2, 0.8), 0.05) 
	
	tween.tween_property(ficha, "global_position", pos_final, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ficha, "scale", ficha.escala_base, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	tween.tween_callback(func():
		ficha.en_animacion_especial = false
		ficha.posicionDefault = pos_final
		ficha.rotation_degrees = rotacion_final 
		finalizar_jugada(ficha, true) 
	)

func _reproducir_sonido_rebote():
	reproductor.stream = Sfx_PonerFicha
	reproductor.pitch_scale = randf_range(1.3, 1.5)
	reproductor.play()

func _on_boton_pozo_pressed():
	if juego_terminado:
		return
	if not modo_debug:
		if jugador_tiene_jugada_valida():
			_animar_temblor_boton()
			return
			
		if robos_restantes <= 0:
			_animar_temblor_boton()
			return

	var posicion_origen = get_global_mouse_position()
	if mano: 
		mano.robar_del_pozo(posicion_origen)
		
		if not modo_debug:
			robos_restantes -= 1
			actualizar_ui()
			guardar_estado_actual() # Guarda en el instante en que robas

# --- EL ÁRBITRO DE LA PARTIDA---
func verificar_victoria():
	if modo_debug: return false

	if suma_total_puntos >= puntaje_objetivo_base:
		var castigo_fantasma = _calcular_castigo_escalera(true)
		var puntaje_neto = suma_total_puntos - castigo_fantasma
		
		if puntaje_neto >= puntaje_objetivo_base:
			# NUEVO: Mensaje claro en consola para saber qué pasó
			print("🏆 ¡MESA SUPERADA! Puntos logrados: ", puntaje_neto, " / Objetivo: ", puntaje_objetivo_base)
			
			_calcular_castigo_escalera(false) 
			suma_total_puntos = puntaje_neto
			actualizar_ui()
			avanzar_siguiente_mesa()
			return true

	return false

# --- SISTEMA DE CASTIGO: LA ESCALERA DE DOLOR ---
func _calcular_castigo_escalera(_silencioso: bool = false) -> int:
	if not mano or mano.fichas_en_mano.is_empty():
		return 0

	var fichas = mano.fichas_en_mano.duplicate()
	fichas.sort_custom(func(a, b): return (a.valor_izq + a.valor_der) > (b.valor_izq + b.valor_der))

	var castigo_total = 0

	for i in range(fichas.size()):
		var ficha = fichas[i]
		var valor_base = ficha.valor_izq + ficha.valor_der
		var penalizacion = 0

		if i == 0: penalizacion = valor_base * 1
		elif i == 1: penalizacion = valor_base * 2
		else: penalizacion = valor_base * multiplicador_global_castigo

		castigo_total += penalizacion
		
	return castigo_total

func terminar_ronda():
# Si ya ganamos o perdimos, el botón no hace nada
	if modo_debug or juego_terminado: return

	var castigo = _calcular_castigo_escalera()
	if castigo > 0:
		suma_total_puntos -= castigo
		if suma_total_puntos < 0: 
			suma_total_puntos = 0
		_animar_temblor_boton()
		
	# Verificamos si ganaste gracias a sobrevivir al castigo
	if verificar_victoria():
		return # Si ganaste, verificar_victoria ya hizo el trabajo. Cortamos aquí.
		
	# Aumentamos el contador de la mano (ronda)
	ronda_actual += 1
	# Reiniciamos los puntos de esta mano específica y los robos
	puntos_ronda_actual = 0
	robos_restantes = robos_maximos
	
	if ronda_actual <= rondas_maximas:
		if mano:
			mano.nueva_ronda()
		actualizar_ui()
		# Guardamos AQUÍ, DESPUÉS de repartir la nueva mano
		guardar_estado_actual()
	else:
# ¡GAME OVER REAL!
		juego_terminado = true
		actualizar_ui()
		print("GAME OVER - No alcanzaste los puntos.")
		# Aseguramos que la interfaz diga Game Over
		if label_ronda: label_ronda.text = "¡GAME OVER!"
		
		# ---> OPCIONAL PERO RECOMENDADO: Borramos la partida guardada porque perdió <---
		SaveManager.borrar_partida()
		# ---> NUEVO: Esperamos 3 segundos para que lea el mensaje y lo mandamos al menú
		await get_tree().create_timer(3.0).timeout
		get_tree().change_scene_to_file("res://_Scenes/MainMenu.tscn") # Asegúrate de que esta ruta sea la correcta

func _on_boton_siguiente_ronda_pressed():
	terminar_ronda()
	
# --- ACTUALIZADOR DE INTERFAZ ---
func actualizar_ui():
	
	# Mostrar Total y Mano Actual
	if label_puntos: label_puntos.text = "Banco Total: %d" % suma_total_puntos
	if label_puntos_mano: label_puntos_mano.text = "Puntos de esta Mano: %d" % puntos_ronda_actual
	
	if modo_debug:
		if label_objetivo: label_objetivo.text = "Objetivo: INF (Debug)"
		if label_ronda: label_ronda.text = "Manos: INF (Debug)"
		if label_robos: label_robos.text = "Robos: INF (Debug)"
	else:
		if label_objetivo: label_objetivo.text = "Objetivo: %d" % puntaje_objetivo_base
		if label_ronda: label_ronda.text = "Mano: %d / %d" % [ronda_actual, rondas_maximas]
		if label_robos: label_robos.text = "Robos: %d" % robos_restantes

# --- TRANSICIÓN DE NIVEL ---
func avanzar_siguiente_mesa():
	historial_jugadas.clear()
	mesa_actual += 1
	ronda_actual = 1
	puntos_ronda_actual = 0 # <--- Añade esto
	robos_restantes = robos_maximos
	suma_total_puntos = 0
	puntaje_objetivo_base = int(puntaje_objetivo_base * 1.5) 
	
	for hijo in get_children():
		if hijo is Ficha:
			hijo.queue_free()
			
	es_primer_turno = true
	extremo_izquierdo = -1
	extremo_derecho = -1
	estado_izq = 0
	estado_der = 0
	nivel_y_izq = 0.0
	nivel_y_der = 0.0
	es_primer_regreso_izq = false
	es_primer_regreso_der = false
	ultima_ficha_izq = null
	ultima_ficha_der = null
	
	if mano:
		mano.generar_mano_inicial()
		
	actualizar_ui()
	guardar_estado_actual()
	print("💾 DEBUG GUARDADO - Nuevo objetivo guardado: ", puntaje_objetivo_base)

# --- ANIMACIONES DE INTERFAZ ---
func _animar_temblor_boton():
	if not boton_pozo: return
	var pos_original = boton_pozo.position
	var fuerza = 15.0 
	var tiempo = 0.05 
	var tween = create_tween()
	tween.tween_property(boton_pozo, "position:x", pos_original.x - fuerza, tiempo)
	tween.tween_property(boton_pozo, "position:x", pos_original.x + fuerza, tiempo * 2)
	tween.tween_property(boton_pozo, "position:x", pos_original.x - fuerza, tiempo * 2)
	tween.tween_property(boton_pozo, "position:x", pos_original.x + fuerza, tiempo * 2)
	tween.tween_property(boton_pozo, "position:x", pos_original.x, tiempo)
# --- SISTEMA DE GUARDADO ---
func guardar_estado_actual():
	if modo_debug: return # No guardamos si estamos testeando
	
	# Empaquetamos todo lo que queremos recordar en un diccionario
	var estado_a_guardar = {
		"mesa_actual": mesa_actual,
		"ronda_actual": ronda_actual,
		"robos_restantes": robos_restantes,
		"suma_total_puntos": suma_total_puntos,
		"puntos_ronda_actual": puntos_ronda_actual,
		"puntaje_objetivo_base": puntaje_objetivo_base,
		"historial_jugadas": historial_jugadas,
		"fichas_en_mano": mano.obtener_datos_mano() if mano else [],
		"pozo_de_fichas": mano.pozo_de_fichas if mano else [],
		
	}
	# Le enviamos el paquete al cerebro global
	SaveManager.guardar_partida(estado_a_guardar)
# --- RECONSTRUCCIÓN DE PARTIDA GUARDADA ---
func reconstruir_serpiente(historial: Array):
	es_primer_turno = true # Aseguramos que la mesa inicie virgen
	
	for jugada in historial:
		var v1 = int(jugada["v1"])
		var v2 = int(jugada["v2"])
		var lado = jugada["lado"]
		
		# 1. Instanciamos la ficha visual (usando el molde de la mano)
		var nueva_ficha = mano.escena_ficha.instantiate()
		add_child(nueva_ficha) # La añadimos a la mesa
		
		# 2. Le pegamos su textura original
		var ruta = "%s/%d-%d.png" % [mano.carpeta_imagenes, v1, v2]
		var tex = load(ruta)
		if tex: nueva_ficha.setup(v1, v2, tex)
		
		# 3. Mandamos a que el Ingeniero la posicione en modo silencioso
		jugar_ficha(nueva_ficha, lado, false, true)
