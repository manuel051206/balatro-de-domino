extends Node

# Esta ruta especial 'user://' asegura que se guarde en la carpeta de datos de 
# la aplicación del jugador (Appdata en Windows, por ejemplo), no en los archivos del juego.
var ruta_guardado = "user://partida_balatro_domino.json"

# Nuestro "Molde" base. Los valores no son relevantes.
var datos_partida = {
	"mesa_actual": 1,
	"ronda_actual": 1,
	"robos_restantes": 3,
	"suma_total_puntos": 0,
	"puntos_ronda_actual": 0,
	"historial_jugadas": [],
	"fichas_en_mano": [],
	"pozo_de_fichas": []
	
}

# --- GUARDAR ---
func guardar_partida(datos_nuevos: Dictionary):
	# 1. Actualizamos nuestro diccionario interno con lo que nos mande la Mesa
	for key in datos_nuevos.keys():
		datos_partida[key] = datos_nuevos[key]
		
	# 2. Abrimos el archivo en modo ESCRITURA
	var archivo = FileAccess.open(ruta_guardado, FileAccess.WRITE)
	
	# 3. Convertimos el diccionario a un texto JSON (String) y lo guardamos
	var json_string = JSON.stringify(datos_partida)
	archivo.store_line(json_string)
	
	print("💾 Partida guardada con éxito en: ", ruta_guardado)

# --- CARGAR ---
func cargar_partida() -> bool:
	# 1. Verificamos si existe un archivo de guardado
	if not FileAccess.file_exists(ruta_guardado):
		print("No hay partida guardada anterior.")
		return false
		
	# 2. Abrimos el archivo en modo LECTURA
	var archivo = FileAccess.open(ruta_guardado, FileAccess.READ)
	var json_string = archivo.get_as_text()
	
	# 3. Convertimos el texto JSON de vuelta a un Diccionario
	var datos_cargados = JSON.parse_string(json_string)
	
	if datos_cargados != null:
		datos_partida = datos_cargados
		print("📂 Partida cargada con éxito. Puntos recuperados: ", datos_partida["suma_total_puntos"])
		return true
		
	return false

# --- BORRAR (GAME OVER) ---
func borrar_partida():
	if FileAccess.file_exists(ruta_guardado):
		DirAccess.remove_absolute(ruta_guardado)
		print("🗑️ Partida borrada (Game Over o Nueva Run).")

# ==========================================
# --- SISTEMA DE AJUSTES (NO SE BORRAN) ---
# ==========================================
var ruta_ajustes = "user://ajustes_balatrodedomino.json"

var datos_ajustes = {
	"volumen": 1.0,
	"pantalla_completa": false,
	"modo_debug": false
}
func guardar_ajustes():
	var archivo = FileAccess.open(ruta_ajustes, FileAccess.WRITE)
	archivo.store_line(JSON.stringify(datos_ajustes))
	print("⚙️ AJUSTES GUARDADOS EN PC: ", datos_ajustes)

func cargar_ajustes() -> bool:
	if FileAccess.file_exists(ruta_ajustes):
		var archivo = FileAccess.open(ruta_ajustes, FileAccess.READ)
		var json_string = archivo.get_as_text()
		var cargado = JSON.parse_string(json_string)
		
		if cargado != null:
			datos_ajustes = cargado
			print("📂 AJUSTES CARGADOS DE PC: ", datos_ajustes)
			return true
			
	print("⚠️ No se encontró archivo de ajustes previo. Usando valores por defecto.")
	return false
