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
var fichas_en_mano: Array = []
var ficha_seleccionada_actual: Ficha = null

func _ready():
	generar_mano_inicial()

# --- GENERACIÓN DE FICHAS ---
# Limpia la mesa y genera 7 fichas ÚNICAS usando una "bolsa" mezclada.
func generar_mano_inicial():
	# 1. Limpieza: Borramos fichas anteriores.
	for hijo in get_children():
		hijo.queue_free()
	fichas_en_mano.clear()
	ficha_seleccionada_actual = null 
	
	# --- NUEVA LÓGICA: BOLSA DE DOMINÓ ---
	var bolsa_de_fichas = []
	
	# A. Generamos las 28 fichas posibles (del 0-0 al 6-6)
	# Usamos dos bucles para crear pares únicos (0-0, 0-1... hasta 6-6)
	for i in range(7):      # i va de 0 a 6
		for j in range(i, 7): # j va de i a 6 (evita repetir 1-0 si ya existe 0-1)
			bolsa_de_fichas.append([i, j])
	
	# B. Barajamos la bolsa (Shuffle)
	bolsa_de_fichas.shuffle()
	
	# C. Sacamos las primeras 7 fichas de la bolsa mezclada
	for k in range(7):
		var datos = bolsa_de_fichas[k] # Obtenemos el par [a, b]
		crear_ficha(datos[0], datos[1])
	
	# 3. Orden: Una vez creadas, las acomodamos en pantalla.
	organizar_mano()

# --- FÁBRICA DE FICHAS ---
# Instancia la ficha, carga su textura dinámica y conecta las señales.
func crear_ficha(v1: int, v2: int):
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
		ficha.position = ficha.posicionDefault

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
