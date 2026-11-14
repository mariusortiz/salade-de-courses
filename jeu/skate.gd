# Une session de skate : le skatepark, un ou deux skateurs, le chrono et l'affichage.
# Les réglages (durée, figures, points) sont dans donnees/skate.gd.
extends Node

signal finie(resultats: Array)

const S = preload("res://donnees/skate.gd")
const Pilotes = preload("res://donnees/pilotes.gd")
const Skatepark = preload("res://jeu/skatepark.gd")
const Skateur = preload("res://jeu/skateur.gd")
const Course = preload("res://jeu/course.gd")  # pour avoir les mêmes touches qu'en course

var epreuve := "skate"
var piste: Node3D           # le skatepark (le menu l'appelle « piste », comme en course)
var skateurs: Array = []
var vues: Array = []
var temps := -3.5           # négatif pendant le compte à rebours
var annoncee := false
var demo := false           # true = l'ordinateur fait une démonstration
var scenario := Callable()  # pour les essais : remplace le clavier du joueur 1
var record := 0
var duree: float = S.DUREE  # la durée de la session (les essais la raccourcissent)


func demarrer(humains: Array, planches: Array) -> void:
	piste = Skatepark.new()
	add_child(piste)
	piste.construire()
	for j in humains.size():
		var skateur: Node3D = Skateur.new()
		skateur.preparer(Pilotes.PILOTES[humains[j]], piste, true, S.PLANCHES[planches[j] if j < planches.size() else 0])
		add_child(skateur)
		# Au départ : à gauche du skatepark, face à la pyramide.
		skateur.placer(-36.0, -3.0 + j * 6.0 if humains.size() > 1 else 0.0, -PI / 2.0)
		skateurs.append(skateur)
	if demo:
		scenario = _demonstration

	# Un écran par joueur, l'un au-dessus de l'autre.
	var ecran := VBoxContainer.new()
	ecran.set_anchors_preset(Control.PRESET_FULL_RECT)
	ecran.add_theme_constant_override("separation", 4)
	add_child(ecran)
	for skateur in skateurs:
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
		camera.fov = 68.0
		camera.far = 600.0
		fenetre.add_child(camera)
		camera.current = true
		vues.append({
			"skateur": skateur,
			"camera": camera,
			"cap": skateur.route,
			"cible": skateur.ou,
			"score": _texte(cellule, 34, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP),
			"temps": _texte(cellule, 44, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_TOP),
			"message": _texte(cellule, 110, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER),
			"combo": _texte(cellule, 26, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM),
			"annonce": _texte(cellule, 54, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP),
		})
		vues[-1]["annonce"].offset_top = 70
		vues[-1]["combo"].add_theme_color_override("font_color", Color("#ffd54f"))
	_cameras(1.0)


func _texte(parent: Control, taille: int, horizontal: int, vertical: int) -> Label:
	var texte := Label.new()
	texte.set_anchors_preset(Control.PRESET_FULL_RECT)
	texte.offset_left = 20
	texte.offset_right = -20
	texte.offset_top = 10
	texte.offset_bottom = -10
	texte.horizontal_alignment = horizontal
	texte.vertical_alignment = vertical
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texte.add_theme_font_size_override("font_size", taille)
	texte.add_theme_color_override("font_outline_color", Color("#1d2433"))
	texte.add_theme_constant_override("outline_size", int(taille / 4.0))
	parent.add_child(texte)
	return texte


# ── Les commandes des joueurs ────────────────────────────────

# Les flèches (ou Z Q S D) : tourner, pousser, freiner. En l'air : toupie et salto.
func _lire(joueur: int) -> Vector2:
	var claviers: Array = [Course.FLECHES, Course.LETTRES]
	if vues.size() > 1:
		claviers = [Course.FLECHES] if joueur == 0 else [Course.LETTRES]
	var gaz := 0.0
	var volant := 0.0
	for c in claviers:
		gaz += float(Input.is_physical_key_pressed(c[0])) - float(Input.is_physical_key_pressed(c[1]))
		volant += float(Input.is_physical_key_pressed(c[3])) - float(Input.is_physical_key_pressed(c[2]))
	if Input.get_connected_joypads().has(joueur):
		var stick := Vector2(Input.get_joy_axis(joueur, JOY_AXIS_LEFT_X), Input.get_joy_axis(joueur, JOY_AXIS_LEFT_Y))
		if absf(stick.x) > 0.25:
			volant += stick.x
		if absf(stick.y) > 0.25:
			gaz -= stick.y
		volant += float(Input.is_joy_button_pressed(joueur, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(joueur, JOY_BUTTON_DPAD_LEFT))
		gaz += float(Input.is_joy_button_pressed(joueur, JOY_BUTTON_DPAD_UP)) - float(Input.is_joy_button_pressed(joueur, JOY_BUTTON_DPAD_DOWN))
	return Vector2(clampf(volant, -1.0, 1.0), clampf(gaz, -1.0, 1.0))


# Les boutons, aux mêmes endroits qu'en course : [—, sauter, tonneau, attraper].
# À la manette : A sauter, X tonneau, Y attraper.
func _boutons(joueur: int) -> Array:
	var touches: Array = Course.TOUCHES_SEUL
	if vues.size() > 1:
		touches = Course.TOUCHES_JOUEUR_1 if joueur == 0 else Course.TOUCHES_JOUEUR_2
	var manette := [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_Y]
	var appuyes: Array = []
	for b in 4:
		var appuye := Input.is_joy_button_pressed(joueur, manette[b])
		for t in touches[b]:
			appuye = appuye or Input.is_physical_key_pressed(t)
		appuyes.append(appuye)
	return appuyes


# La démonstration : l'ordinateur fonce, saute, et tente une toupie puis un tonneau.
func _demonstration(t: float) -> Array:
	var cycle := fmod(t, 2.4)
	var volant := 0.0
	if cycle > 1.3 and cycle < 1.83:
		volant = 1.0
	elif cycle > 2.15:
		volant = -0.6
	return [Vector2(volant, 1.0), [false, cycle > 1.2 and cycle < 1.28, cycle > 1.3 and cycle < 1.4, false]]


# ── Le déroulement ───────────────────────────────────────────

func _physics_process(dt: float) -> void:
	temps += dt
	var en_jeu := temps >= 0.0 and temps < duree
	for i in vues.size():
		var skateur: Node3D = vues[i]["skateur"]
		skateur.actif = en_jeu
		skateur.commande = _lire(i)
		skateur.boutons = _boutons(i)
	if scenario.is_valid() and not skateurs.is_empty():
		var ordres: Array = scenario.call(maxf(temps, 0.0))
		skateurs[0].commande = ordres[0]
		skateurs[0].boutons = ordres[1]
	if temps > duree + 3.0 and not annoncee:
		annoncee = true
		finie.emit(classement().map(func(s): return {"nom": s.pilote["nom"], "temps": -1.0, "humain": true, "score": s.score,
			"detail": "%d points" % s.score, "combo": s.meilleur_combo, "chutes": s.chutes, "figures": s.figures}))


func classement() -> Array:
	var ordre := skateurs.duplicate()
	ordre.sort_custom(func(a, b): return a.score > b.score)
	return ordre


func _process(dt: float) -> void:
	for vue in vues:
		var skateur: Node3D = vue["skateur"]
		var reste := clampf(duree - temps, 0.0, duree)
		vue["score"].text = "%d points" % skateur.score
		if record > 0:
			vue["score"].text += "\nRecord : %d" % record
		vue["temps"].text = "%d:%02d" % [int(ceil(reste)) / 60, int(ceil(reste)) % 60]
		var message := ""
		if temps < -3.0:
			message = ""
		elif temps < 0.0:
			message = str(int(ceil(-temps)))
		elif temps < 1.0:
			message = "C'est parti !"
		elif temps >= duree:
			message = "Fini !"
		vue["message"].text = message
		vue["combo"].text = skateur.texte_du_combo()
		vue["annonce"].text = skateur.annonce if skateur.annonce_temps > 0.0 else ""
	_cameras(minf(1.0, dt * 4.0))


# Chaque caméra suit son skateur, derrière lui, dans la direction où il va.
func _cameras(douceur: float) -> void:
	for vue in vues:
		var skateur: Node3D = vue["skateur"]
		vue["cap"] = lerp_angle(vue["cap"], skateur.route, douceur)
		vue["cible"] = vue["cible"].lerp(skateur.ou, minf(1.0, douceur * 3.0))
		var direction := Vector3(-sin(vue["cap"]), 0, -cos(vue["cap"]))
		var ici: Vector3 = vue["cible"]
		var camera: Camera3D = vue["camera"]
		var recul: Vector3 = ici - direction * 8.5 + Vector3.UP * 4.2
		# La caméra ne sort pas du skatepark et ne passe pas sous une rampe.
		recul.x = clampf(recul.x, -piste.demi.x + 0.5, piste.demi.x - 0.5)
		recul.z = clampf(recul.z, -piste.demi.y + 0.5, piste.demi.y - 0.5)
		recul.y = maxf(recul.y, piste.hauteur(recul.x, recul.z) + 1.5)
		camera.global_position = recul
		if recul.distance_to(ici + Vector3.UP) > 0.5:
			camera.look_at(ici + direction * 2.0 + Vector3.UP * 1.2)
