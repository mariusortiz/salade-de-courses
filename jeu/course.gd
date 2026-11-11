# Une course : la piste, les karts, les écrans des joueurs et le classement.
extends Node

signal finie(resultats: Array)

const Pilotes = preload("res://donnees/pilotes.gd")
const Piste = preload("res://jeu/piste.gd")
const Kart = preload("res://jeu/kart.gd")

const FLECHES := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
const LETTRES := [KEY_W, KEY_S, KEY_A, KEY_D]  # Z Q S D sur un clavier français

var piste: Node3D
var karts: Array = []
var vues: Array = []
var temps := -3.5   # négatif pendant le compte à rebours
var fin := -1.0
var annoncee := false
var demo := false   # true = l'ordinateur conduit aussi les karts des joueurs
var scenario := Callable()  # pour les essais : remplace le clavier du joueur 1


func demarrer(circuit: Dictionary, humains: Array) -> void:
	piste = Piste.new()
	add_child(piste)
	piste.construire(circuit)

	# La grille de départ : deux par deux derrière la ligne, les joueurs au fond.
	var grille: Array = []
	for i in Pilotes.PILOTES.size():
		if not humains.has(i):
			grille.append([i, false])
	for i in humains:
		grille.append([i, true])
	for n in grille.size():
		var kart := Kart.new()
		kart.preparer(Pilotes.PILOTES[grille[n][0]], piste, grille[n][1])
		add_child(kart)
		kart.placer(-4.0 - (n >> 1) * 4.0, -2.5 if n % 2 == 0 else 2.5)
		kart.distance = kart.position_piste - piste.longueur
		if demo:
			kart.auto = true
		karts.append(kart)

	# Un écran par joueur, l'un au-dessus de l'autre.
	var ecran := VBoxContainer.new()
	ecran.set_anchors_preset(Control.PRESET_FULL_RECT)
	ecran.add_theme_constant_override("separation", 4)
	add_child(ecran)
	var joueurs := karts.filter(func(k): return k.humain)
	for kart in joueurs:
		var cellule := Control.new()
		cellule.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ecran.add_child(cellule)
		var cadre := SubViewportContainer.new()
		cadre.stretch = true
		cadre.set_anchors_preset(Control.PRESET_FULL_RECT)
		cellule.add_child(cadre)
		var fenetre := SubViewport.new()
		fenetre.msaa_3d = Viewport.MSAA_2X
		cadre.add_child(fenetre)
		var camera := Camera3D.new()
		camera.fov = 65.0
		camera.far = 800.0
		fenetre.add_child(camera)
		camera.current = true
		vues.append({
			"kart": kart,
			"camera": camera,
			"cap": kart.cap,
			"tour": _texte(cellule, 30, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP),
			"place": _texte(cellule, 54, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_TOP),
			"message": _texte(cellule, 120, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER),
		})
	_cameras(1.0)


func _texte(parent: Control, taille: int, horizontal: int, vertical: int) -> Label:
	var texte := Label.new()
	texte.set_anchors_preset(Control.PRESET_FULL_RECT)
	texte.offset_left = 20
	texte.offset_right = -20
	texte.offset_top = 10
	texte.horizontal_alignment = horizontal
	texte.vertical_alignment = vertical
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texte.add_theme_font_size_override("font_size", taille)
	texte.add_theme_color_override("font_outline_color", Color("#1d2433"))
	texte.add_theme_constant_override("outline_size", int(taille / 4.0))
	parent.add_child(texte)
	return texte


# ── Les commandes des joueurs ────────────────────────────────

func _lire(joueur: int) -> Vector2:
	var claviers: Array = [FLECHES, LETTRES]
	if vues.size() > 1:
		claviers = [FLECHES] if joueur == 0 else [LETTRES]
	var gaz := 0.0
	var volant := 0.0
	for c in claviers:
		gaz += float(Input.is_physical_key_pressed(c[0])) - float(Input.is_physical_key_pressed(c[1]))
		volant += float(Input.is_physical_key_pressed(c[3])) - float(Input.is_physical_key_pressed(c[2]))

	# Une manette, si elle est branchée : le stick pour tourner, A pour accélérer, B pour freiner.
	if Input.get_connected_joypads().has(joueur):
		var stick := Input.get_joy_axis(joueur, JOY_AXIS_LEFT_X)
		if absf(stick) > 0.2:
			volant += stick
		volant += float(Input.is_joy_button_pressed(joueur, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(joueur, JOY_BUTTON_DPAD_LEFT))
		if Input.is_joy_button_pressed(joueur, JOY_BUTTON_A) or Input.get_joy_axis(joueur, JOY_AXIS_TRIGGER_RIGHT) > 0.3:
			gaz += 1.0
		if Input.is_joy_button_pressed(joueur, JOY_BUTTON_B) or Input.get_joy_axis(joueur, JOY_AXIS_TRIGGER_LEFT) > 0.3:
			gaz -= 1.0
	return Vector2(clampf(volant, -1.0, 1.0), clampf(gaz, -1.0, 1.0))


# Le bouton de dérapage. Seul : Espace ou Maj. À deux : Entrée pour le joueur 1, Espace pour le joueur 2.
func _derape(joueur: int) -> bool:
	var touches: Array = [KEY_SPACE, KEY_SHIFT]
	if vues.size() > 1:
		touches = [KEY_ENTER] if joueur == 0 else [KEY_SPACE]
	for t in touches:
		if Input.is_physical_key_pressed(t):
			return true
	return Input.is_joy_button_pressed(joueur, JOY_BUTTON_RIGHT_SHOULDER) or Input.is_joy_button_pressed(joueur, JOY_BUTTON_X)


# ── Le déroulement ───────────────────────────────────────────

func _physics_process(dt: float) -> void:
	temps += dt
	if temps < 0.0:
		return
	for i in vues.size():
		vues[i]["kart"].commande = _lire(i)
		vues[i]["kart"].bouton_derapage = _derape(i)
	if scenario.is_valid():
		var ordres: Array = scenario.call(temps)
		vues[0]["kart"].commande = ordres[0]
		vues[0]["kart"].bouton_derapage = ordres[1]
	var but: float = piste.longueur * piste.tours
	for kart in karts:
		kart.actif = true
		if kart.arrivee < 0.0 and kart.distance >= but:
			kart.arrivee = temps
			kart.auto = true  # après l'arrivée, l'ordinateur fait le tour d'honneur

	# La course s'arrête quand tous les joueurs sont arrivés.
	var attendus := karts.filter(func(k): return k.humain) if not vues.is_empty() else karts
	if fin < 0.0 and (attendus.all(func(k): return k.arrivee >= 0.0) or temps > 600.0):
		fin = temps
	if fin >= 0.0 and temps > fin + 2.5 and not annoncee:
		annoncee = true
		finie.emit(classement().map(func(k): return {"nom": k.pilote["nom"], "temps": k.arrivee, "humain": k.humain}))


func classement() -> Array:
	var ordre := karts.duplicate()
	ordre.sort_custom(func(a, b):
		if a.arrivee >= 0.0 and b.arrivee >= 0.0:
			return a.arrivee < b.arrivee
		if a.arrivee >= 0.0 or b.arrivee >= 0.0:
			return a.arrivee >= 0.0
		return a.distance > b.distance)
	return ordre


func _process(dt: float) -> void:
	var ordre := classement()
	for vue in vues:
		var kart = vue["kart"]
		var place := ordre.find(kart) + 1
		vue["tour"].text = "Tour %d / %d" % [clampi(kart.tour(), 1, piste.tours), piste.tours]
		vue["place"].text = "1er" if place == 1 else "%de" % place
		var message := ""
		if temps < -3.0:
			message = ""
		elif temps < 0.0:
			message = str(int(ceil(-temps)))
		elif temps < 1.0:
			message = "Partez !"
		elif kart.arrivee >= 0.0:
			message = "Arrivée !"
		vue["message"].text = message
	_cameras(minf(1.0, dt * 5.0))


# Chaque caméra suit son kart en douceur.
func _cameras(douceur: float) -> void:
	for vue in vues:
		var kart = vue["kart"]
		vue["cap"] = lerp_angle(vue["cap"], kart.cap, douceur)
		var direction := Vector3(-sin(vue["cap"]), 0, -cos(vue["cap"]))
		var ici: Vector3 = kart.ou_suis_je()
		var camera: Camera3D = vue["camera"]
		camera.global_position = ici - direction * 7.5 + Vector3.UP * 3.4
		camera.look_at(ici + direction * 4.0 + Vector3.UP * 0.8)
