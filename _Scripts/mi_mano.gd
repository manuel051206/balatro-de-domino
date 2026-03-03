extends Node2D

# --- SEÑALES --- 
signal intento_de_jugada(ficha: Ficha)

# --- CONFIGURACIÓN Y REFERENCIAS ---
# 'escena_ficha': Es el molde (.tscn) que usaremos para crear copias de las fichas.
@export var escena_ficha: PackedScene 
@export var carpeta_imagenes: String = "res://_art" 
@export var separacion_fichas: float = 70.0 

# --- ESTADO DE LA MANO ---
# 'fichas_en_mano': Lista para llevar el control de los objetos creados.
# 'ficha_seleccionada_actual': Referencia única para saber cuál ficha está activa.
# pozo_de_fichas': Aquí guardaremos las fichas que no se han repartido
var fichas_en_mano: Array = []
var ficha_seleccionada_actual: Ficha = null
var pozo_de_fichas: Array = []

func _ready():
	pass # generar_mano_inicial()

# --- GENERACIÓN DE FICHAS ---
# Limpia la mesa y genera 7 fichas ÚNICAS usando una "bolsa" mezclada.
func generar_mano_inicial():
	# 1. Limpieza
	for hijo in get_children():
		hijo.queue_free()
	fichas_en_mano.clear()
	ficha_seleccionada_actual = null 
	pozo_de_fichas.clear() # Limpiamos el pozo por si estamos reiniciando el juego
	
	# 2. Llenar el pozo con las 28 fichas posibles
	for i in range(7):
		for j in range(i, 7):
			pozo_de_fichas.append([i, j])
	
	# 3. Barajamos el pozo
	pozo_de_fichas.shuffle()
	
	# 4. Repartimos las primeras 7 fichas
	for k in range(7):
		# pop_back() hace dos cosas a la vez: lee el último elemento de la lista, y lo BORRA de la lista.
		# Así nos aseguramos de que esa ficha ya no esté en el pozo.
		var datos = pozo_de_fichas.pop_back() 
		crear_ficha(datos[0], datos[1])
	
	# 5. Ordenar visualmente
	organizar_mano()

# --- FÁBRICA DE FICHAS ---
# Instancia la ficha, carga su textura dinámica y conecta las señales.
func crear_ficha(v1: int, v2: int) -> Ficha:
	var nueva_ficha = escena_ficha.instantiate()
	add_child(nueva_ficha)
	fichas_en_mano.append(nueva_ficha)
	
	# Carga dinámica de recursos (Strings formateados para la ruta)
	var ruta = "%s/%d-%d.png" % [carpeta_imagenes, v1, v2]
	var tex = load(ruta)
	if tex: nueva_ficha.setup(v1, v2, tex)
	
	# CONEXIÓN DE SEÑALES (El "Sistema Nervioso")
	# Escuchamos dos eventos:
	# 1. click_en_ficha: Cuando el jugador hace un clic rápido (soltar).
	nueva_ficha.click_en_ficha.connect(_on_ficha_click)
	# 2. empezando_interaccion: Apenas el jugador pone el dedo encima (presionar).
	nueva_ficha.empezando_interaccion.connect(_on_ficha_interactuada)
	# 3. Cuando la ficha grite "me soltaron", ejecutamos una función local
	nueva_ficha.ficha_soltada.connect(_on_ficha_soltada_drag)
	
	return nueva_ficha

# --- MATEMÁTICAS DE POSICIONAMIENTO ---
# Calcula la posición de cada ficha para centrarlas respecto a la Cámara (0,0).
func organizar_mano():
	if fichas_en_mano.is_empty(): return
	
	var cantidad = fichas_en_mano.size()
	# Calculamos el ancho total del abanico de fichas
	var ancho_total = (cantidad - 1) * separacion_fichas
	
	# El punto de inicio es la mitad del ancho hacia la izquierda (negativo)
	var inicio_x = - (ancho_total / 2)
	var altura_y = 200.0 
	
	for i in range(cantidad):
		var ficha = fichas_en_mano[i]
		# Asignamos su posición ideal (posicionDefault) para que la ficha sepa dónde volver
		var pos_x = inicio_x + (i * separacion_fichas)
		ficha.posicionDefault = Vector2(pos_x, altura_y)

# --- LÓGICA DE CONTROL Y SELECCIÓN ---

# EVENTO 1: Interacción Inmediata (Al presionar/arrastrar)
# Objetivo: Si toco una ficha nueva, olvidar inmediatamente la anterior.
func _on_ficha_interactuada(ficha_tocada: Ficha):
	if ficha_seleccionada_actual != null and ficha_seleccionada_actual != ficha_tocada:
		ficha_seleccionada_actual.deseleccionar()
		ficha_seleccionada_actual = null

# EVENTO 2: Clic Confirmado (Al soltar rápido)
# Objetivo: Decidir si seleccionamos o deseleccionamos la ficha actual.
func _on_ficha_click(ficha_tocada: Ficha):
	
	# Caso A: Toqué la misma que ya tenía -> La apago (Deseleccionar).
	if ficha_seleccionada_actual == ficha_tocada:
		ficha_tocada.deseleccionar()
		ficha_seleccionada_actual = null
		return

	# Caso B: Es una nueva selección.
	# (Nota: La limpieza de la anterior ya ocurrió en el evento de interacción,
	# pero reforzamos la deselección aquí por seguridad).
	if ficha_seleccionada_actual != null:
		ficha_seleccionada_actual.deseleccionar()
	
	# Encendemos la nueva
	ficha_tocada.seleccionar()
	ficha_seleccionada_actual = ficha_tocada

# Esta función recibe el aviso de la ficha y lo retransmite hacia arriba (al Main)
func _on_ficha_soltada_drag(ficha: Ficha):
	intento_de_jugada.emit(ficha)
	
# --- ROBAR DEL POZO ANIMADO ---
# Ahora recibe la coordenada desde donde debe salir volando
func robar_del_pozo(posicion_origen: Vector2):
	
	if pozo_de_fichas.is_empty():
		print("El pozo está vacío.")
		return 

	var datos = pozo_de_fichas.pop_back()
	
	# 1. Creamos la ficha y la guardamos en una variable
	var nueva_ficha = crear_ficha(datos[0], datos[1])
	
	# 2. Preparativos iniciales
	nueva_ficha.global_position = posicion_origen # Nace en el botón
	nueva_ficha.scale = Vector2(0.1, 0.1)         # Nace chiquitita
	nueva_ficha.en_animacion_especial = true      # Pausamos sus físicas automáticas
	
	# 3. Organizamos la mano (Esto le calcula su "posicionDefault" a donde debe ir)
	organizar_mano()
	
	# 4. ¡ACCIÓN! Creamos el Tween paralelo
	var tween = create_tween().set_parallel(true)
	
	# A. Animamos el viaje (TRANS_BACK hace que se pase un poquito y vuelva, como un rebote)
	tween.tween_property(nueva_ficha, "global_position", nueva_ficha.posicionDefault, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# B. Animamos el crecimiento (TRANS_ELASTIC para que "salte" visualmente)
	tween.tween_property(nueva_ficha, "scale", nueva_ficha.escala_base, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# 5. Cuando todo termine, desbloqueamos la ficha
	tween.chain().tween_callback(func():
		nueva_ficha.en_animacion_especial = false
	)
	
	print("Robaste la ficha: ", datos[0], "-", datos[1])
	
	# 5. DEBUG: Mensajes útiles para la consola
	print("Robaste la ficha: ", datos[0], "-", datos[1])
	print("Fichas restantes en el pozo: ", pozo_de_fichas.size())
	
# --- OLVIDAR FICHA JUGADA ---
func quitar_ficha_jugada(ficha: Ficha):
	# Borramos la ficha de nuestra lista interna
	fichas_en_mano.erase(ficha)
	# Reacomodamos la mano para cerrar el hueco que dejó
	organizar_mano()

# --- NUEVA RONDA (DESCARTAR Y ROBAR) ---
func nueva_ronda():
	# 1. Limpiar las fichas actuales de la mano (descartarlas)
	for ficha in fichas_en_mano:
		ficha.queue_free()
	fichas_en_mano.clear()
	ficha_seleccionada_actual = null
	
	# 2. Calcular cuántas podemos robar (máximo 7, o las que queden en el pozo)
	var fichas_a_robar = min(7, pozo_de_fichas.size())
	
	if fichas_a_robar == 0:
		print("¡No quedan fichas en el pozo para una nueva ronda!")
		return
	
	# 3. Robamos las fichas nuevas
	for i in range(fichas_a_robar):
		var datos = pozo_de_fichas.pop_back()
		crear_ficha(datos[0], datos[1])
	
	# 4. Acomodamos la nueva mano
	organizar_mano()
	print("Nueva ronda iniciada. Fichas repartidas: ", fichas_a_robar)
	print("Fichas restantes en el pozo: ", pozo_de_fichas.size())

# --- SISTEMA DE GUARDADO ---
func obtener_datos_mano() -> Array:
	var datos = []
	for ficha in fichas_en_mano:
		datos.append({"v1": ficha.valor_izq, "v2": ficha.valor_der})
	return datos

func cargar_estado(fichas_guardadas: Array, pozo_guardado: Array):
	# 1. Limpiamos cualquier rastro anterior
	for hijo in get_children():
		hijo.queue_free()
	fichas_en_mano.clear()
	ficha_seleccionada_actual = null
	
	# 2. Restauramos el pozo exacto
	pozo_de_fichas = pozo_guardado.duplicate()
	
	# 3. Recreamos las fichas exactas en tu mano
	for datos in fichas_guardadas:
		crear_ficha(int(datos["v1"]), int(datos["v2"]))
		
	organizar_mano()
