extends Node2D

var arrastrando = false
var offset = Vector2.ZERO #el offset va a ser (0,0) al empezar. (para que la ficha no snappee a la posicion del mouse, sino que se agarre desde cualquier parte de la ficha)
var posicionDefault = Vector2.ZERO

func _process(delta):
	if arrastrando == true:
		global_position = get_global_mouse_position() - offset
	else:
		global_position = lerp(global_position, posicionDefault, 25*delta)
	

func _ready():
	var pantalla = get_viewport_rect().size #calcular el tamaÑo de la pantalla
	#calcular coordenadas
	position = Vector2(pantalla.x/2, pantalla.y - 150)
	posicionDefault = position

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				arrastrando = true
				offset = get_global_mouse_position() - global_position #basicamente el offset sera: posicion mouse - posicion ficha
			else:
				arrastrando = false
