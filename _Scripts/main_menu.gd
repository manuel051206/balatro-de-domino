extends Control

# --- REFERENCIAS ---
@onready var panel_opciones = $PanelOpciones
@onready var boton_jugar = $VBoxContainer/BotonJugar
@onready var slider_volumen = $PanelOpciones/VBoxContainer/SliderVolumen
@onready var check_pantalla = $PanelOpciones/VBoxContainer/CheckPantalla
@onready var contenedor_botones = $VBoxContainer

func _ready():
	# Nos aseguramos de que el panel de opciones esté oculto al iniciar
	panel_opciones.visible = false
	
	# DETALLE DE CALIDAD: Revisamos si hay partida guardada
	if SaveManager.cargar_partida():
		boton_jugar.text = "Continuar Partida"
	# ---> NUEVO: CARGAR Y APLICAR AJUSTES <---
	if SaveManager.cargar_ajustes():
		var vol = SaveManager.datos_ajustes.get("volumen", 1.0)
		var fullscreen = SaveManager.datos_ajustes.get("pantalla_completa", false)
		
		# Ajustamos los controles visuales
		slider_volumen.value = vol
		check_pantalla.button_pressed = fullscreen
		
		# Forzamos al motor de audio a aplicar el volumen cargado
		_on_slider_volumen_value_changed(vol)
	else:
		boton_jugar.text = "Nueva Partida"
	
	# Sincronizamos el CheckBox con el estado actual de la pantalla
	var modo_actual = DisplayServer.window_get_mode()
	check_pantalla.button_pressed = (modo_actual == DisplayServer.WINDOW_MODE_FULLSCREEN)

# --- BOTONES PRINCIPALES ---
func _on_boton_jugar_pressed():
	# Cambiamos de escena hacia la Mesa
	get_tree().change_scene_to_file("res://_Scenes/Mesa.tscn")

func _on_boton_opciones_pressed():
	panel_opciones.visible = true
	contenedor_botones.visible = false # Ocultamos el menú principal

func _on_boton_salir_pressed():
	get_tree().quit()

# --- PANEL DE OPCIONES ---
func _on_boton_cerrar_opciones_pressed():
	panel_opciones.visible = false
	contenedor_botones.visible = true # Mostramos el menú principal de nuevo

func _on_check_pantalla_toggled(toggled_on: bool):
	if toggled_on:
		get_window().mode = Window.MODE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED
		
	# Guardamos el cambio
	SaveManager.datos_ajustes["pantalla_completa"] = toggled_on
	SaveManager.guardar_ajustes()
	print("💾 Ajustes de Pantalla guardados: ", toggled_on)

func _on_slider_volumen_value_changed(value: float):	
	var bus_index = AudioServer.get_bus_index("Master")
	
	if value <= 0.01:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
		
	# Guardamos el cambio de volumen de inmediato
	SaveManager.datos_ajustes["volumen"] = value
	SaveManager.guardar_ajustes()
