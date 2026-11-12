# Une course : la piste, les karts, les bonus, les écrans des joueurs et le classement.
extends Node

signal finie(resultats: Array)

const Pilotes = preload("res://donnees/pilotes.gd")
const Piste = preload("res://jeu/piste.gd")
const Vehicules = preload("res://donnees/vehicules.gd")
const Kart = preload("res://jeu/kart.gd")
const R = preload("res://donnees/reglages.gd")

const FLECHES := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
const LETTRES := [KEY_W, KEY_S, KEY_A, KEY_D]  # Z Q S D sur un clavier français

# Les boutons, dans l'ordre : déraper, sauter, tirer un pépin, utiliser l'objet.
# Les touches sont repérées par leur place sur le clavier : KEY_SEMICOLON est la touche M
# d'un clavier français.
const TOUCHES_SEUL := [[KEY_SHIFT], [KEY_SPACE], [KEY_F, KEY_ENTER], [KEY_E]]
const TOUCHES_JOUEUR_1 := [[KEY_J, KEY_ENTER], [KEY_K], [KEY_L], [KEY_SEMICOLON]]
const TOUCHES_JOUEUR_2 := [[KEY_SHIFT], [KEY_SPACE], [KEY_F], [KEY_E]]
const MANETTE := [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_X, JOY_BUTTON_Y]
const NOMS_OBJETS := {"": "rien", "turbo": "turbo", "bouclier": "bouclier", "jus": "jus"}

var piste: Node3D
var karts: Array = []
var vues: Array = []
var temps := -3.5   # négatif pendant le compte à rebours
var fin := -1.0
var annoncee := false
var demo := false   # true = l'ordinateur conduit aussi les karts des joueurs
var scenario := Callable()  # pour les essais : remplace le clavier du joueur 1
var pepins: Array = []   # les pépins en vol
var flaques: Array = []  # les flaques de jus sur la route


# humains : les numéros des pilotes des joueurs. vehicules : le numéro du véhicule de chacun.
# tours : 0 = le nombre de tours écrit dans le circuit.
func demarrer(circuit: Dictionary, humains: Array, vehicules: Array = [], tours := 0) -> void:
	piste = Piste.new()
	add_child(piste)
	piste.construire(circuit)
	if tours > 0:
		piste.tours = tours

	# La grille de départ : deux par deux derrière la ligne, les joueurs au fond.
	# Les ordinateurs sont tirés au hasard parmi les autres pilotes, avec un véhicule au hasard.
	var autres: Array = range(Pilotes.PILOTES.size()).filter(func(i): return not humains.has(i))
	autres.shuffle()
	var grille: Array = []
	for i in autres.slice(0, maxi(0, R.NOMBRE_DE_KARTS - humains.size())):
		grille.append([i, false, Vehicules.VEHICULES.pick_random()])
	for j in humains.size():
		grille.append([humains[j], true, Vehicules.VEHICULES[vehicules[j] if j < vehicules.size() else 0]])
	for n in grille.size():
		var kart := Kart.new()
		kart.preparer(Pilotes.PILOTES[grille[n][0]], piste, grille[n][1], grille[n][2])
		add_child(kart)
		kart.placer(-4.0 - (n >> 1) * 4.0, -2.5 if n % 2 == 0 else 2.5)
		kart.distance = kart.position_piste - piste.longueur
		if demo:
			kart.auto = true
		kart.adversaires = karts
		kart.tire.connect(_lancer_un_pepin)
		kart.verse.connect(_verser_du_jus)
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
			"bonus": _texte(cellule, 30, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_BOTTOM),
			"annonce": _texte(cellule, 54, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP),
		})
		vues[-1]["annonce"].offset_top = 80
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


# Les quatre boutons d'un joueur : déraper, sauter, tirer, utiliser l'objet.
func _boutons(joueur: int) -> Array:
	var touches: Array = TOUCHES_SEUL
	if vues.size() > 1:
		touches = TOUCHES_JOUEUR_1 if joueur == 0 else TOUCHES_JOUEUR_2
	var appuyes: Array = []
	for b in 4:
		var appuye := Input.is_joy_button_pressed(joueur, MANETTE[b])
		for t in touches[b]:
			appuye = appuye or Input.is_physical_key_pressed(t)
		appuyes.append(appuye)
	return appuyes


# ── Le déroulement ───────────────────────────────────────────

func _physics_process(dt: float) -> void:
	temps += dt
	if temps < 0.0:
		return
	for i in vues.size():
		_commander(vues[i]["kart"], _lire(i), _boutons(i))
	if scenario.is_valid():
		var ordres: Array = scenario.call(temps)
		_commander(vues[0]["kart"], ordres[0], ordres[1])
	_ramasser_les_cagettes()
	_avancer_les_pepins(dt)
	_surveiller_les_flaques()
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


func _commander(kart: Node3D, commande: Vector2, boutons: Array) -> void:
	kart.commande = commande
	kart.bouton_derapage = boutons[0]
	kart.bouton_saut = boutons[1]
	kart.bouton_tir = boutons[2]
	kart.bouton_objet = boutons[3]


# ── Les bonus ────────────────────────────────────────────────

# Une cagette touchée disparaît, donne un bonus, puis revient un peu plus tard.
func _ramasser_les_cagettes() -> void:
	for cagette in piste.cagettes:
		if not cagette.visible:
			cagette.visible = temps >= cagette.get_meta("retour", 0.0)
			continue
		for kart in karts:
			if kart.ou_suis_je().distance_to(cagette.position) < 1.9:
				cagette.visible = false
				cagette.set_meta("retour", temps + R.CAGETTE_RETOUR)
				kart.ramasser()
				break


func _lancer_un_pepin(kart: Node3D) -> void:
	var avant: Vector3 = kart.devant()
	var forme := SphereMesh.new()
	forme.radius = 0.3
	forme.height = 0.6
	var brun := StandardMaterial3D.new()
	brun.albedo_color = Color("#4e342e")
	var pepin := MeshInstance3D.new()
	pepin.mesh = forme
	pepin.material_override = brun
	pepin.basis = Basis.looking_at(avant) * Basis.from_scale(Vector3(0.7, 0.7, 1.7))
	pepin.position = kart.ou_suis_je() + avant * 2.2
	add_child(pepin)
	pepins.append({"noeud": pepin, "direction": avant, "vitesse": maxf(kart.vitesse, 0.0) + R.PEPIN_VITESSE, "vie": 2.5, "tireur": kart})


# Les pépins filent tout droit en suivant le sol, jusqu'à toucher un kart ou une barrière.
func _avancer_les_pepins(dt: float) -> void:
	var espace := piste.get_world_3d().direct_space_state
	for p in pepins.duplicate():
		var pepin: MeshInstance3D = p["noeud"]
		var ici: Vector3 = pepin.position
		var la: Vector3 = ici + p["direction"] * p["vitesse"] * dt
		p["vie"] -= dt
		var fini: bool = p["vie"] <= 0.0
		var choc := espace.intersect_ray(PhysicsRayQueryParameters3D.create(ici, la, 1))
		var sol := espace.intersect_ray(PhysicsRayQueryParameters3D.create(la + Vector3.UP * 2.0, la + Vector3.DOWN * 6.0, 1))
		for touche in [choc, sol]:
			if not touche.is_empty() and touche["collider"].get_meta("sol", "") == "mur":
				fini = true
		if not sol.is_empty():
			la.y = sol["position"].y + 0.7
		pepin.position = la
		for kart in karts:
			var ecart: Vector3 = kart.ou_suis_je() - la
			# Un kart qui saute assez haut laisse passer le pépin sous lui.
			if kart != p["tireur"] and Vector2(ecart.x, ecart.z).length() < 1.7 and absf(ecart.y) < 0.9:
				kart.recevoir_pepin()
				fini = true
				break
		if fini:
			pepin.queue_free()
			pepins.erase(p)


# La flaque de jus est posée sur la route, juste derrière le kart, à la couleur du fruit.
func _verser_du_jus(kart: Node3D) -> void:
	var ou: Vector3 = kart.ou_suis_je() - kart.devant() * 2.8
	var espace := piste.get_world_3d().direct_space_state
	var sol := espace.intersect_ray(PhysicsRayQueryParameters3D.create(ou + Vector3.UP, ou + Vector3.DOWN * 4.0, 1))
	if sol.is_empty():
		return
	var forme := CylinderMesh.new()
	forme.top_radius = 2.6
	forme.bottom_radius = 2.6
	forme.height = 0.06
	var jus := StandardMaterial3D.new()
	jus.albedo_color = Color(Color(kart.pilote["couleur"]), 0.85)
	jus.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	jus.roughness = 0.1
	var flaque := MeshInstance3D.new()
	flaque.mesh = forme
	flaque.material_override = jus
	flaque.basis = Basis(Quaternion(Vector3.UP, sol["normal"]))
	flaque.position = sol["position"] + sol["normal"] * 0.06
	add_child(flaque)
	flaques.append({"noeud": flaque, "fin": temps + R.JUS_DUREE, "auteur": kart})


func _surveiller_les_flaques() -> void:
	for f in flaques.duplicate():
		if temps > f["fin"]:
			f["noeud"].queue_free()
			flaques.erase(f)
			continue
		for kart in karts:
			if kart != f["auteur"] and kart.au_sol and kart.ou_suis_je().distance_to(f["noeud"].position) < 3.0:
				kart.rouler_dans_le_jus()


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
		vue["bonus"].text = "Pépins : %d     Objet : %s" % [kart.pepins, NOMS_OBJETS.get(kart.objet, kart.objet)]
		vue["annonce"].text = kart.annonce if kart.annonce_temps > 0.0 else ""
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
