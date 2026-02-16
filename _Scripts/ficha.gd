class_name Ficha extends Area2D

# --- SEÑALES (COMUNICACIÓN) ---
# click_en_ficha: Se emite al SOLTAR si el movimiento fue corto (< 5px).
signal click_en_ficha(ficha: Ficha)      
# empezando_interaccion: Se emite inmediatamente al PRESIONAR el click.
signal empezando_interaccion(ficha: Ficha) 

# --- CONFIGURACIÓN VISUAL ---
@export var escala_base: Vector2 = Vector2(1, 1)
@export var aumento_seleccion: float = 20.0 

# --- DATOS Y ESTADO ---
var valor_izq: int = -1
var valor_der: int = -1
var seleccionado: bool = false
var posicionDefault: Vector2 = Vector2.ZERO # La "casa" a donde vuelve la ficha

# Variables para lógica de arrastre
var arrastrando: bool = false
var offset_mouse: Vector2 = Vector2.ZERO
var posicion_inicio_click: Vector2 = Vector2.ZERO 

@onready var sprite: Sprite2D = $Sprite

func _ready():
	scale = escala_base

# Inicializador (Constructor manual)
func setup(v1, v2, tex):
	valor_izq = v1
	valor_der = v2
	if sprite: sprite.texture = tex
	name = "Ficha_%d_%d" % [valor_izq, valor_der] # Nombre útil para debug

# --- BUCLE FÍSICO (FRAME A FRAME) ---
func _process(delta):
	if arrastrando:
		# Si el mouse la tiene agarrada, sigue al mouse directamente.
		global_position = get_global_mouse_position() - offset_mouse
	else:
		# Si está libre, vuelve flotando a su posición asignada (Efecto magnético).
		# Usamos 'lerp' para interpolación suave.
		global_position = global_position.lerp(posicionDefault, 25.0 * delta)

# --- FUNCIONES VISUALES (LLAMADAS POR LA MANO) ---
func seleccionar():
	seleccionado = true
	z_index = 10 # Traer al frente
	animar_escala(escala_base * (1 + (aumento_seleccion/100.0)))

func deseleccionar():
	seleccionado = false
	z_index = 0
	animar_escala(escala_base)

# Animación suave usando Tweens (Evita cambios bruscos de tamaño)
func animar_escala(objetivo: Vector2):
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", objetivo, 0.1)

# --- DETECCIÓN DE INPUT (MOUSE) ---
func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		
		# 1. AL PRESIONAR (DOWN)
		if event.pressed:
			arrastrando = true
			posicion_inicio_click = global_position # Guardamos foto del inicio
			offset_mouse = get_global_mouse_position() - global_position
			z_index = 20 # Prioridad máxima visual mientras arrastras
			
			# AVISO IMPORTANTE: "¡Me están tocando!" (Para que la Mano deseleccione otras)
			empezando_interaccion.emit(self)
			
			animar_escala(escala_base * 1.05) # Pequeño feedback visual

		# 2. AL SOLTAR (UP)
		else:
			arrastrando = false
			z_index = 10 if seleccionado else 0 
			
			# Calculamos si fue un Arrastre o un Clic
			var distancia = global_position.distance_to(posicion_inicio_click)
			
			if distancia < 5.0:
				# Si movió el mouse menos de 5px, asumimos que quería seleccionar.
				click_en_ficha.emit(self)
			else:
				# Si movió más, fue un arrastre. No emitimos click.
				# (Aquí la ficha volverá sola a su sitio gracias a _process)
				pass
			
			# Restauramos tamaño según si quedó seleccionada o no
			if not seleccionado:
				animar_escala(escala_base)
			else:
				animar_escala(escala_base * (1 + (aumento_seleccion/100.0)))
