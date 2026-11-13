# Une course : la piste, les karts, les bonus, les écrans des joueurs et le classement.
extends Node

signal finie(resultats: Array)

const Pilotes = preload("res://donnees/pilotes.gd")
const Piste = preload("res://jeu/piste.gd")
const Vehicules = preload("res://donnees/vehicules.gd")
const Kart = preload("res://jeu/kart.gd")
const Avion = preload("res://jeu/avion.gd")
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
var aerien := false      # true = le mode Avions
var epreuve := "course"  # la façon de jouer (voir donnees/modes.gd)
var sortis: Array = []   # les karts éliminés, dans l'ordre
var manche := 1          # Élimination : le numéro du tour en cours
var patate := {}         # Patate chaude : qui la porte, quand elle éclate
var patate_visible: MeshInstance3D
var prochaine_patate := 3.0
var trace: Array = []    # Contre-la-montre : la course du joueur, notée dix fois par seconde
var fantome: Array = []  # Contre-la-montre : la trace de sa meilleure course
var fantome_visible: Node3D
var record := -1.0


# humains : les numéros des pilotes des joueurs. vehicules : le numéro du véhicule de chacun.
# tours : 0 = le nombre de tours écrit dans le circuit.
# en_avion : true = le mode Avions. regle : l'effet du défi du jour ("" = aucun).
# sorte : l'épreuve ("course", "elimination", "chrono", "chasse" ou "patate").
func demarrer(circuit: Dictionary, humains: Array, vehicules: Array = [], tours := 0, en_avion := false, regle := "", sorte := "course") -> void:
	aerien = en_avion
	epreuve = sorte
	piste = Piste.new()
	piste.regle = regle
	add_child(piste)
	piste.construire(circuit, aerien)
	if tours > 0:
		piste.tours = tours

	# La grille de départ : deux par deux derrière la ligne, les joueurs au fond.
	# Les ordinateurs sont tirés au hasard parmi les autres pilotes, avec un véhicule au hasard.
	var autres: Array = range(Pilotes.PILOTES.size()).filter(func(i): return not humains.has(i))
	autres.shuffle()
	var grille: Array = []
	if epreuve == "chrono" and not humains.is_empty():
		autres = []  # contre la montre, on est seul sur la piste
	for i in autres.slice(0, maxi(0, R.NOMBRE_DE_KARTS - humains.size())):
		grille.append([i, false, Vehicules.VEHICULES.pick_random()])
	for j in humains.size():
		grille.append([humains[j], true, Vehicules.VEHICULES[vehicules[j] if j < vehicules.size() else 0]])
	for n in grille.size():
		var kart: Node3D = Avion.new() if aerien else Kart.new()
		kart.preparer(Pilotes.PILOTES[grille[n][0]], piste, grille[n][1], grille[n][2])
		add_child(kart)
		if aerien:
			kart.placer(-5.0 - (n >> 1) * 8.0, -4.0 if n % 2 == 0 else 4.0)
		else:
			kart.placer(-4.0 - (n >> 1) * 4.0, -2.5 if n % 2 == 0 else 2.5)
		kart.distance = kart.position_piste - piste.longueur
		if demo:
			kart.auto = true
		kart.adversaires = karts
		if regle == "pepins":
			kart.pepins = R.PEPINS_MAXIMUM
		kart.tire.connect(_lancer_un_pepin)
		kart.verse.connect(_verser_du_jus)
		karts.append(kart)

	_preparer_l_epreuve()

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
		if aerien:
			# Le repère du prochain anneau : chaque joueur a le sien, que l'autre caméra ne montre pas.
			var numero := vues.size() - 1
			var tour_jaune := TorusMesh.new()
			tour_jaune.inner_radius = piste.RAYON_ANNEAU + 0.5
			tour_jaune.outer_radius = piste.RAYON_ANNEAU + 1.4
			tour_jaune.rings = 32
			var jaune := StandardMaterial3D.new()
			jaune.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			jaune.albedo_color = Color(R.COULEUR_ANNEAUX[2])
			var cible := MeshInstance3D.new()
			cible.mesh = tour_jaune
			cible.material_override = jaune
			cible.layers = 1 << (10 + numero)
			cible.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(cible)
			vues[-1]["cible"] = cible
			camera.cull_mask &= ~(1 << (11 - numero))
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
		# En avion, le stick sert aussi à monter et à descendre.
		if aerien and absf(Input.get_joy_axis(joueur, JOY_AXIS_LEFT_Y)) > 0.2:
			gaz -= Input.get_joy_axis(joueur, JOY_AXIS_LEFT_Y)
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
	for o in piste.obstacles:
		for kart in karts:
			if kart.ou_suis_je().distance_to(o["noeud"].position) < (3.0 if aerien else 2.1):
				kart.heurter()
	var but: float = piste.longueur * piste.tours
	for kart in karts:
		kart.actif = true
		if kart.arrivee < 0.0 and kart.distance >= but:
			kart.arrivee = temps
			kart.auto = true  # après l'arrivée, l'ordinateur fait le tour d'honneur

	# Chaque épreuve a sa règle, et sa façon de finir.
	var vivants := karts.filter(func(k): return not k.elimine)
	var attendus := karts.filter(func(k): return k.humain) if not vues.is_empty() else karts
	var terminee := false
	match epreuve:
		"elimination", "patate":
			if epreuve == "elimination":
				_eliminer_le_dernier(vivants)
			else:
				_faire_tourner_la_patate(vivants)
			vivants = karts.filter(func(k): return not k.elimine)
			if vivants.size() == 1 and vivants[0].arrivee < 0.0:
				vivants[0].arrivee = temps  # le dernier en piste a gagné
			# C'est fini quand il ne reste qu'un kart, ou quand tous les joueurs sont éliminés.
			terminee = vivants.size() <= 1 or not attendus.any(func(k): return not k.elimine)
		"chasse":
			_ramasser_les_graines()
			terminee = temps >= R.CHASSE_DUREE
		_:
			if epreuve == "chrono":
				_suivre_le_fantome()
			terminee = attendus.all(func(k): return k.arrivee >= 0.0)
	if fin < 0.0 and (terminee or temps > 600.0):
		fin = temps
	if fin >= 0.0 and temps > fin + 2.5 and not annoncee:
		annoncee = true
		finie.emit(classement().map(func(k): return {"nom": k.pilote["nom"], "temps": k.arrivee, "humain": k.humain,
			"touches": k.touches, "retours": k.retours, "tirs": k.tirs, "cagettes": k.cagettes, "glisses": k.glisses,
			"score": k.score, "detail": _detail(k)}))


# ── Les épreuves ─────────────────────────────────────────────

func _preparer_l_epreuve() -> void:
	match epreuve:
		"elimination":
			piste.tours = maxi(1, karts.size() - 1)  # un éliminé par tour
		"chasse":
			piste.tours = 999
			for i in R.CHASSE_GRAINES:
				piste.semer()
		"patate":
			piste.tours = 999
			for kart in karts:
				kart.pepins = R.PATATE_PEPINS
			var forme := SphereMesh.new()
			forme.radius = 0.7
			forme.height = 1.4
			patate_visible = MeshInstance3D.new()
			patate_visible.mesh = forme
			patate_visible.material_override = StandardMaterial3D.new()
			patate_visible.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			patate_visible.visible = false
			add_child(patate_visible)
		"chrono":
			if not fantome.is_empty():
				# Le fantôme : une silhouette blanche qui refait la meilleure course.
				var brume := StandardMaterial3D.new()
				brume.albedo_color = Color(1, 1, 1, 0.45)
				brume.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				brume.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				fantome_visible = Node3D.new()
				add_child(fantome_visible)
				for partie in [[1.0, Vector3(0, 0.6, 0), Vector3(1.0, 0.5, 1.8)], [0.75, Vector3(0, 1.5, 0.2), Vector3.ONE]]:
					var forme := SphereMesh.new()
					forme.radius = partie[0]
					forme.height = partie[0] * 2.0
					var m := MeshInstance3D.new()
					m.mesh = forme
					m.material_override = brume
					m.position = partie[1]
					m.scale = partie[2]
					fantome_visible.add_child(m)


# Ce qu'on écrit à côté du nom dans le classement, quand ce n'est pas un temps.
func _detail(kart: Node3D) -> String:
	match epreuve:
		"chasse":
			return "%d graine%s" % [kart.score, "s" if kart.score > 1 else ""]
		"elimination", "patate":
			return "éliminé" if kart.elimine else "gagnant"
	return ""


func _sortir(kart: Node3D) -> void:
	sortis.append(kart)
	kart.eliminer()


# Élimination : dès que tous les karts sauf un ont fini le tour, celui qui reste est éliminé.
func _eliminer_le_dernier(vivants: Array) -> void:
	if vivants.size() <= 1:
		return
	var passes := vivants.filter(func(k): return k.distance >= manche * piste.longueur)
	if passes.size() >= vivants.size() - 1:
		var dernier: Node3D = vivants[0]
		for k in vivants:
			if k.distance < dernier.distance:
				dernier = k
		_sortir(dernier)
		manche += 1


# Chasse aux graines : une graine ramassée repousse ailleurs.
func _ramasser_les_graines() -> void:
	for graine in piste.graines:
		for kart in karts:
			if kart.ou_suis_je().distance_to(graine["noeud"].position) < 2.0:
				kart.score += 1
				piste.semer(graine)
				break


# Patate chaude : le porteur la refile en touchant un autre kart. Quand elle éclate, il est éliminé.
func _faire_tourner_la_patate(vivants: Array) -> void:
	if vivants.size() <= 1:
		patate_visible.visible = false
		return
	if patate.is_empty():
		if temps >= prochaine_patate:
			_donner_la_patate(vivants.pick_random(), null)
			patate["eclate"] = temps + randf_range(R.PATATE_DUREE[0], R.PATATE_DUREE[1])
		return
	var porteur: Node3D = patate["porteur"]
	# Il faut garder la patate au moins une seconde, et on ne la rend pas tout de suite à celui qui l'a donnée.
	if temps > patate["recue"] + 1.0:
		for k in vivants:
			var rendue: bool = k == patate["donneur"] and temps < patate["recue"] + 3.0
			if k != porteur and not rendue and k.ou_suis_je().distance_to(porteur.ou_suis_je()) < 2.8:
				_donner_la_patate(k, porteur)
				break
	porteur = patate["porteur"]
	# L'ordinateur qui a la patate poursuit le kart le plus proche.
	var plus_pres := INF
	for k in vivants:
		k.bonus_vitesse = R.PATATE_VITESSE if k == porteur else 1.0
		k.proie = null
		if k != porteur and k.ou_suis_je().distance_to(porteur.ou_suis_je()) < plus_pres:
			plus_pres = k.ou_suis_je().distance_to(porteur.ou_suis_je())
			porteur.proie = k
	# La patate flotte au-dessus du porteur. Plus elle est près d'éclater, plus elle est rouge et plus elle bat vite.
	var reste: float = patate["eclate"] - temps
	var chaleur := clampf(1.0 - reste / R.PATATE_DUREE[1], 0.0, 1.0)
	patate_visible.visible = true
	patate_visible.position = porteur.ou_suis_je() + Vector3.UP * 3.2
	patate_visible.scale = Vector3(1.3, 1.0, 1.0) * (1.0 + 0.2 * sin(temps * (6.0 + 20.0 * chaleur)))
	patate_visible.material_override.albedo_color = Color("#b58a4c").lerp(Color("#ff1744"), chaleur)
	if reste <= 0.0:
		_sortir(porteur)
		patate = {}
		patate_visible.visible = false
		prochaine_patate = temps + 2.0


func _donner_la_patate(a_qui: Node3D, de_qui: Node3D) -> void:
	patate["porteur"] = a_qui
	patate["donneur"] = de_qui
	patate["recue"] = temps
	a_qui.annonce = "Tu as la patate !"
	a_qui.annonce_temps = 2.0


# Contre-la-montre : on note la course du joueur, et le fantôme refait la meilleure.
func _suivre_le_fantome() -> void:
	if vues.is_empty():
		return
	var kart: Node3D = vues[0]["kart"]
	if kart.arrivee < 0.0 and trace.size() <= int(temps * 10.0):
		var ici: Vector3 = kart.ou_suis_je()
		trace.append([snappedf(ici.x, 0.01), snappedf(ici.y, 0.01), snappedf(ici.z, 0.01), snappedf(kart.cap, 0.001)])
	if fantome_visible != null:
		var rang := temps * 10.0
		var a: Array = fantome[mini(int(rang), fantome.size() - 1)]
		var b: Array = fantome[mini(int(rang) + 1, fantome.size() - 1)]
		var entre := rang - floorf(rang)
		fantome_visible.position = Vector3(a[0], a[1], a[2]).lerp(Vector3(b[0], b[1], b[2]), entre) + Vector3.DOWN * 0.9
		fantome_visible.rotation.y = lerp_angle(a[3], b[3], entre)


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
			if kart.ou_suis_je().distance_to(cagette.position) < (2.8 if aerien else 1.9):
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
		if aerien:
			choc = {}  # en l'air, le pépin file tout droit
			sol = {}
		for touche in [choc, sol]:
			if not touche.is_empty() and touche["collider"].get_meta("sol", "") == "mur":
				fini = true
		if not sol.is_empty():
			la.y = sol["position"].y + 0.7
		pepin.position = la
		for kart in karts:
			var ecart: Vector3 = kart.ou_suis_je() - la
			# Un kart qui saute assez haut laisse passer le pépin sous lui.
			if kart != p["tireur"] and Vector2(ecart.x, ecart.z).length() < (2.4 if aerien else 1.7) and absf(ecart.y) < (2.0 if aerien else 0.9):
				kart.recevoir_pepin()
				p["tireur"].tirs += 1
				if epreuve == "chasse":
					kart.score = maxi(0, kart.score - R.CHASSE_PEPIN)
				if epreuve == "patate" and patate.get("porteur") == p["tireur"]:
					_donner_la_patate(kart, p["tireur"])  # un pépin refile aussi la patate
				fini = true
				break
		if fini:
			pepin.queue_free()
			pepins.erase(p)


# La flaque de jus est posée sur la route, juste derrière le kart, à la couleur du fruit.
func _verser_du_jus(kart: Node3D) -> void:
	var ou: Vector3 = kart.ou_suis_je() - kart.devant() * 2.8
	if aerien:
		_lacher_un_nuage_de_jus(kart)
		return
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


# Dans le mode Avions, le jus reste en l'air : c'est un nuage qui ralentit ceux qui le traversent.
func _lacher_un_nuage_de_jus(kart: Node3D) -> void:
	var forme := SphereMesh.new()
	forme.radius = 3.0
	forme.height = 6.0
	var jus := StandardMaterial3D.new()
	jus.albedo_color = Color(Color(kart.pilote["couleur"]), 0.6)
	jus.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var nuage := MeshInstance3D.new()
	nuage.mesh = forme
	nuage.material_override = jus
	nuage.position = kart.ou_suis_je() - kart.devant() * 6.0
	add_child(nuage)
	flaques.append({"noeud": nuage, "fin": temps + R.JUS_DUREE, "auteur": kart})


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
	if epreuve == "chasse":
		var chasseurs := karts.duplicate()
		chasseurs.sort_custom(func(a, b): return a.score > b.score)
		return chasseurs
	var ordre := karts.filter(func(k): return not k.elimine)
	ordre.sort_custom(func(a, b):
		if a.arrivee >= 0.0 and b.arrivee >= 0.0:
			return a.arrivee < b.arrivee
		if a.arrivee >= 0.0 or b.arrivee >= 0.0:
			return a.arrivee >= 0.0
		return a.distance > b.distance)
	# Les éliminés viennent ensuite : le dernier sorti est le mieux classé.
	for i in sortis.size():
		ordre.append(sortis[sortis.size() - 1 - i])
	return ordre


func _process(dt: float) -> void:
	var ordre := classement()
	for vue in vues:
		var kart = vue["kart"]
		var place := ordre.find(kart) + 1
		vue["tour"].text = "Tour %d / %d" % [clampi(kart.tour(), 1, piste.tours), piste.tours]
		if aerien:
			# Le prochain anneau de ce joueur est entouré de jaune (lui seul le voit).
			var n: int = piste.anneaux.size()
			vue["tour"].text += "     Anneau %d / %d" % [kart.prochain % n + 1, n]
			var anneau: Dictionary = piste.anneaux[kart.prochain % n]
			vue["cible"].global_transform = Transform3D(Basis(anneau["droite"], anneau["axe"], anneau["droite"].cross(anneau["axe"])) * (1.0 + 0.06 * sin(temps * 8.0)), anneau["centre"])
		# En haut à gauche : ce qui compte dans cette épreuve.
		match epreuve:
			"elimination":
				vue["tour"].text = "Tour %d     Encore %d pilotes" % [manche, karts.size() - sortis.size()]
			"chasse":
				vue["tour"].text = "Graines : %d     Temps : %s" % [kart.score, _minutes(maxf(0.0, R.CHASSE_DUREE - temps))]
			"patate":
				vue["tour"].text = "Encore %d pilotes" % (karts.size() - sortis.size())
			"chrono":
				vue["tour"].text += "     %s" % _minutes(maxf(0.0, temps if kart.arrivee < 0.0 else kart.arrivee))
				if record > 0.0:
					vue["tour"].text += "     Record : %s" % _minutes(record)
		vue["place"].text = "1er" if place == 1 else "%de" % place
		var message := ""
		if temps < -3.0:
			message = ""
		elif temps < 0.0:
			message = str(int(ceil(-temps)))
		elif temps < 1.0:
			message = "Partez !"
		elif kart.elimine:
			message = "Éliminé !"
		elif kart.arrivee >= 0.0:
			message = "Gagné !" if epreuve in ["elimination", "patate"] else "Arrivée !"
		elif epreuve == "chasse" and temps >= R.CHASSE_DUREE:
			message = "Fini !"
		vue["message"].text = message
		vue["bonus"].text = "Pépins : %d     Objet : %s" % [kart.pepins, NOMS_OBJETS.get(kart.objet, kart.objet)]
		vue["annonce"].text = kart.annonce if kart.annonce_temps > 0.0 else ""
	_cameras(minf(1.0, dt * 5.0))


func _minutes(secondes: float) -> String:
	return "%d:%04.1f" % [int(secondes) / 60, fmod(secondes, 60.0)]


# Chaque caméra suit son kart en douceur. Si le joueur est éliminé, elle suit le premier.
func _cameras(douceur: float) -> void:
	for vue in vues:
		var kart = vue["kart"]
		if kart.elimine:
			kart = classement()[0]
		vue["cap"] = lerp_angle(vue["cap"], kart.cap, douceur)
		var direction := Vector3(-sin(vue["cap"]), 0, -cos(vue["cap"]))
		var ici: Vector3 = kart.ou_suis_je()
		var camera: Camera3D = vue["camera"]
		camera.global_position = ici - direction * 7.5 + Vector3.UP * 3.4
		camera.look_at(ici + direction * 4.0 + Vector3.UP * 0.8)
