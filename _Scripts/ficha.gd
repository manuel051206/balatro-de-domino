class_name Ficha extends Area2D

# --- SEÑALES ---
signal click_en_ficha(ficha: Ficha)      
signal empezando_interaccion(ficha: Ficha) 
signal ficha_soltada(ficha: Ficha)

# --- CONFIGURACIÓN VISUAL ---
@export var escala_base: Vector2 = Vector2(1, 1) 
@export var aumento_seleccion: float = 20.0 
@export var max_offset_sombra: float = 10.0 

# --- CONFIGURACIÓN SONORA ---
@export var SFX_SeleccionarFicha = AudioStream
@export var SFX_DeseleccionarFicha = AudioStream
@onready var reproductor = $AudioStreamPlayer2D


# --- ESTADO ---
var valor_izq: int = -1
var valor_der: int = -1
var seleccionado: bool = false
var posicionDefault: Vector2 = Vector2.ZERO 

# Variable NUEVA: Bloqueo de ficha jugada
var jugada: bool = false 

var arrastrando: bool = false
var offset_mouse: Vector2 = Vector2.ZERO
var posicion_inicio_click: Vector2 = Vector2.ZERO 

var tween_actual: Tween 

# --- REFERENCIAS ---
@onready var sprite: Sprite2D = $Sprite
@onready var sombra: Sprite2D = $Sombra 

func _ready():
	scale = escala_base

func setup(v1, v2, tex):
	valor_izq = v1
	valor_der = v2
	name = "Ficha_%d_%d" % [valor_izq, valor_der]
	
	if sprite: sprite.texture = tex
	if sombra: sombra.texture = tex

# --- BUCLE FÍSICO ---
func _process(delta):
	# Si la ficha ya está jugada, solo nos aseguramos de que llegue a su sitio
	# pero NO calculamos sombras ni inputs.
	if jugada:
		global_position = global_position.lerp(posicionDefault, 25.0 * delta)
		return

	# Lógica normal de mano (si no está jugada)
	if arrastrando:
		global_position = get_global_mouse_position() - offset_mouse
	else:
		global_position = global_position.lerp(posicionDefault, 25.0 * delta)
	
	manejar_sombra(delta)

# --- LÓGICA DE SOMBRA ---
func manejar_sombra(_delta: float) -> void:
	if sombra == null: return
	
	var mitad_pantalla = get_viewport_rect().size.x / 2.0
	var distancia_al_centro = global_position.x
	var porcentaje_basico = abs(distancia_al_centro / mitad_pantalla)
	var factor_velocidad = pow(porcentaje_basico, 2.0)
	var offset_final = -sign(distancia_al_centro) * factor_velocidad * max_offset_sombra
	
	sombra.global_position.x = global_position.x + offset_final

# --- FUNCIONES VISUALES Y DE ESTADO ---

# NUEVA FUNCIÓN: Se llama cuando la ficha se queda en la mesa
func bloquear():
	jugada = true
	arrastrando = false
	seleccionado = false
	
	# 1. Mandar al fondo
	z_index = -1 
	
	# 2. Apagar sombra
	if sombra:
		sombra.visible = false
	
	# 3. Hacerse pequeña (Efecto de estar "lejos")
	escala_base = Vector2(0.75, 0.75) 
	animar_escala(escala_base)

func seleccionar():
	if jugada: return # Seguridad extra
	seleccionado = true
	z_index = 10 
	animar_escala(escala_base * (1 + (aumento_seleccion/100.0)))
	reproductor.stream = SFX_SeleccionarFicha
	reproductor.play()

func deseleccionar():
	if jugada: return
	seleccionado = false
	z_index = 0
	animar_escala(escala_base)
	reproductor.stream = SFX_DeseleccionarFicha
	reproductor.play()

func animar_escala(objetivo: Vector2):
	if tween_actual and tween_actual.is_running():
		tween_actual.kill()
	
	tween_actual = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween_actual.tween_property(self, "scale", objetivo, 0.5)

# --- INPUT ---
func _input_event(_viewport, event, _shape_idx):
	# Si ya está jugada, ignoramos cualquier clic
	if jugada: return 
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			arrastrando = true
			posicion_inicio_click = global_position
			offset_mouse = get_global_mouse_position() - global_position
			z_index = 20 
			
			empezando_interaccion.emit(self)
			animar_escala(escala_base * 1.05) 
# test
		else:
			arrastrando = false
			z_index = 10 if seleccionado else 0 
			
			var distancia = global_position.distance_to(posicion_inicio_click)
			
			if distancia < 5.0:
				click_en_ficha.emit(self)
			else:
				ficha_soltada.emit(self)
			
			if not seleccionado:
				animar_escala(escala_base)
			else:
				animar_escala(escala_base * (1 + (aumento_seleccion/100.0)))
