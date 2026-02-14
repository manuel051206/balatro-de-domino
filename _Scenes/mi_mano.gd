extends Node2D

# --- REFERENCIAS ---
# Esto es una variable "vacía" que espera recibir un archivo .tscn
@export var escena_ficha: PackedScene

# --- CONFIGURACIÓN ---
@export var carpeta_imagenes: String = "res://_art" 
@export var separacion_fichas: float = 70.0

# --- ESTADO ---
# Una lista para llevar la cuenta de los hijos que hemos creado
var fichas_en_mano: Array = []

func crear_ficha(v1: int, v2: int):
	# 1. INSTANCIACIÓN (Usar el molde)
	# Creamos una copia del molde en la Memoria RAM.
	# Aún NO existe en el juego visualmente. Es un fantasma en la memoria.
	var nueva_ficha = escena_ficha.instantiate()
	
	# 2. EL ÁRBOL DE NODOS (Darle vida)
	# Ahora la agregamos como hija de este nodo (Mano).
	# En este momento, aparece en la pantalla (probablemente en la esquina 0,0).
	add_child(nueva_ficha)
	
	# La guardamos en nuestra lista personal
	fichas_en_mano.append(nueva_ficha)
	
	# 3. CARGA DINÁMICA DE RECURSOS (Buscar la imagen)
	# Construimos el texto: "res://_art" + "/" + "0" + "-" + "1" + ".png"
	var ruta_imagen = "%s/%d-%d.png" % [carpeta_imagenes, v1, v2]
	
	# 'load()' va al disco duro, busca el archivo y lo sube a la RAM como Textura.
	var textura_cargada = load(ruta_imagen)
	
	# --- CONTROL DE ERRORES (Programación Defensiva) ---
	# ¿Qué pasa si pides la ficha 9-9 y la imagen no existe? El juego explotaría.
	# Con esto, evitamos el crash y nos avisa en la consola.
	if textura_cargada == null:
		push_error("¡CUIDADO! No encontré la imagen: " + ruta_imagen)
		return # Abortamos la misión para esta ficha
	
	# 4. INYECCIÓN DE DEPENDENCIAS
	# Llamamos a la función 'setup' que creamos en el paso anterior.
	# Le damos su cerebro (números) y su ropa (textura).
	nueva_ficha.setup(v1, v2, textura_cargada)
	
	
	
func organizar_mano():
	# Si no hay fichas, no hacemos nada (evita dividir por cero o errores)
	if fichas_en_mano.is_empty():
		return
		
	var pantalla_size = get_viewport_rect().size
	var cantidad_fichas = fichas_en_mano.size()
	
	# CALCULO DEL ANCHO TOTAL
	# Imagina que cada ficha está separada 70px.
	# Si tengo 3 fichas, tengo 2 espacios entre ellas.
	# Ancho total = (3 - 1) * 70 = 140px de distancia entre la primera y la última.
	var ancho_total_ocupado = (cantidad_fichas - 1) * separacion_fichas
	
	# CALCULO DEL PUNTO DE INICIO (El extremo izquierdo)
	# Centro de pantalla (500) - Mitad del ancho del grupo (70) = 430.
	# Empezaremos a dibujar en el pixel 430.
	var inicio_x = (pantalla_size.x / 2) - (ancho_total_ocupado / 2)
	
	# Altura fija: Un poco arriba del fondo
	var altura_y = pantalla_size.y - 100 
	
	# BUCLE DE POSICIONAMIENTO
	# 'i' va a valer 0, luego 1, luego 2...
	for i in range(cantidad_fichas):
		var ficha = fichas_en_mano[i]
		
		# Formula: Posición Inicial + (Número de ficha * Separación)
		# Ficha 0: 430 + (0 * 70) = 430
		# Ficha 1: 430 + (1 * 70) = 500 (Justo en el centro)
		# Ficha 2: 430 + (2 * 70) = 570
		var nueva_posicion = Vector2(inicio_x + (i * separacion_fichas), altura_y)
		
		# Le decimos a la ficha: "Esta es tu nueva casa por defecto"
		ficha.posicionDefault = nueva_posicion
		
		# Y la movemos ahí inmediatamente
		ficha.position = nueva_posicion


func _ready():
	generar_mano_inicial()

func generar_mano_inicial():
	# 1. Limpieza (Por si reiniciamos el juego sin recargar la escena)
	for hijo in get_children():
		hijo.queue_free() # queue_free borra el nodo de la memoria de forma segura
	fichas_en_mano.clear()
	
	# 2. Bucle de creación (7 veces)
	for i in range(7):
		# randi_range(0, 6) tira un dado de 7 caras (0 al 6)
		var dado1 = randi_range(0, 6)
		var dado2 = randi_range(0, 6)
		
		# NORMALIZACIÓN DE DATOS
		# Tú tienes el archivo "0-1.png", pero NO tienes "1-0.png".
		# Si el random saca (1, 0), el juego fallaría al buscar la imagen.
		# Por eso usamos min() y max().
		# min(1, 0) da 0. max(1, 0) da 1. -> Resultado: 0, 1.
		var v_min = min(dado1, dado2)
		var v_max = max(dado1, dado2)
		
		crear_ficha(v_min, v_max)
	
	# 3. Una vez creadas todas, las organizamos
	organizar_mano()
