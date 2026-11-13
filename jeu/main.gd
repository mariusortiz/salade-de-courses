# Le chef d'orchestre : le menu, le lancement d'une course, le classement.
extends Node

const R = preload("res://donnees/reglages.gd")
const Circuits = preload("res://donnees/circuits.gd")
const Pilotes = preload("res://donnees/pilotes.gd")
const Vehicules = preload("res://donnees/vehicules.gd")
const Defis = preload("res://donnees/defis.gd")
const Course = preload("res://jeu/course.gd")
const Decor = preload("res://jeu/decor.gd")
const Fruit = preload("res://jeu/fruit.gd")
const Defi = preload("res://jeu/defi.gd")

# Les couleurs du menu.
const FOND := Color("#101629")
const CARTE := Color("#1c2440")
const CARTE_CLAIRE := Color("#2c3763")
const ACCENT := Color("#ff6b3d")
const JAUNE := Color("#ffd54f")
const TEXTE := Color("#f4f6ff")
const DISCRET := Color("#9aa6c7")

var GRAS := FontVariation.new()  # la police des titres, en plus épais

var choix := {"joueurs": 1, "pilotes": [0, 1], "vehicules": [0, 0], "circuit": 0, "tours": 3, "avions": false}
var menu: Control
var resultats: Control
var course: Node
var defi := {}             # le défi du jour, quand on est en train de le jouer
var tournants: Array = []  # les plateaux du menu, qui tournent pour montrer les pilotes
var angle := 0.0

# Pour les essais automatiques (voir le README, partie « Vérifier »).
var essai_circuit := -1
var capture := ""
var essai_derapage := ""
var essai_bonus := ""
var essai_trace := 0.0
var musique := AudioStreamPlayer.new()


func _ready() -> void:
	get_window().title = R.TITRE
	GRAS.variation_embolden = 0.9
	add_child(musique)
	for option in OS.get_cmdline_user_args():
		if option == "--simulation":
			essai_circuit = 0
		elif option.begins_with("--capture="):
			capture = option.trim_prefix("--capture=")
		elif option.begins_with("--essai-bonus="):
			essai_bonus = option.trim_prefix("--essai-bonus=")
		elif option.begins_with("--essai-derapage="):
			essai_derapage = option.trim_prefix("--essai-derapage=")
		elif option.begins_with("--menu="):
			_montrer_menu()
			await get_tree().create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png(option.trim_prefix("--menu="))
			get_tree().quit()
			return
		elif option.begins_with("--galerie="):
			_galerie(option.trim_prefix("--galerie="))
			return
		elif option.begins_with("--resultats="):
			defi = Defi.du_jour()
			_montrer_resultats([{"nom": "Pastek", "temps": 61.2, "humain": false}, {"nom": "Pépin", "temps": 63.9, "humain": true}, {"nom": "Mimi", "temps": -1.0, "humain": false}])
			await get_tree().create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png(option.trim_prefix("--resultats="))
			get_tree().quit()
			return
		elif option == "--defi":
			defi = Defi.du_jour()
			print("Défi du jour : ", defi)
		elif option == "--avions":
			choix["avions"] = true
		elif option.begins_with("--vehicule="):
			choix["vehicules"] = [int(option.trim_prefix("--vehicule=")), int(option.trim_prefix("--vehicule="))]
		elif option.begins_with("--circuit="):
			choix["circuit"] = int(option.trim_prefix("--circuit="))
		elif option.begins_with("--joueurs="):
			choix["joueurs"] = int(option.trim_prefix("--joueurs="))
	if essai_circuit >= 0:
		_simuler()
	elif capture != "":
		_lancer(true)
	elif essai_bonus != "":
		_lancer(false)
		# Le joueur 1 roule tout droit, saute à 1 s, puis tire et utilise son objet sans arrêt.
		course.scenario = func(t: float) -> Array:
			var clic := int(t * 4.0) % 2 == 0
			return [Vector2(0.0, 1.0), [false, t >= 1.0 and t < 1.2, t > 3.0 and clic, t > 3.0 and clic]]
	elif essai_derapage != "":
		_lancer(false)
		# Le joueur 1 accélère, dérape à droite de 2 s à 3 s en contre-braquant, puis relâche.
		course.scenario = func(t: float) -> Array:
			var volant := 0.0
			if t >= 2.0 and t < 2.1:
				volant = 1.0
			elif t >= 2.1 and t < 3.0:
				volant = -1.0
			return [Vector2(volant, 1.0), [t >= 2.0 and t < 3.0, false, false, false]]
	else:
		_montrer_menu()


# ── Le menu ──────────────────────────────────────────────────

func _montrer_menu() -> void:
	_nettoyer()
	_jouer(R.MUSIQUE_MENU)
	defi = {}
	tournants.clear()
	menu = ColorRect.new()
	menu.color = FOND
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for cote in ["left", "right"]:
		marge.add_theme_constant_override("margin_" + cote, 28)
	for cote in ["top", "bottom"]:
		marge.add_theme_constant_override("margin_" + cote, 18)
	menu.add_child(marge)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	marge.add_child(page)

	# En haut : le titre, puis le mode, le nombre de joueurs et le nombre de tours.
	var entete := HBoxContainer.new()
	entete.add_theme_constant_override("separation", 22)
	page.add_child(entete)
	var titre := _texte(entete, R.TITRE, 36, TEXTE, true)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reglette(entete, "Mode", ["Karts", "Avions"], 1 if choix["avions"] else 0, func(i): choix["avions"] = i == 1)
	_reglette(entete, "Joueurs", ["1", "2"], choix["joueurs"] - 1, func(i): choix["joueurs"] = i + 1)
	_reglette(entete, "Tours", R.CHOIX_DE_TOURS.map(func(t): return str(t)), R.CHOIX_DE_TOURS.find(choix["tours"]), func(i): choix["tours"] = R.CHOIX_DE_TOURS[i])

	# Au milieu : une carte par joueur, puis le circuit et le défi du jour.
	var corps := HBoxContainer.new()
	corps.add_theme_constant_override("separation", 14)
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(corps)
	for j in choix["joueurs"]:
		_carte_du_joueur(corps, j)
	var droite := VBoxContainer.new()
	droite.add_theme_constant_override("separation", 14)
	droite.custom_minimum_size.x = 400 if choix["joueurs"] == 1 else 340
	corps.add_child(droite)
	_carte_du_circuit(droite)
	_carte_du_defi(droite)

	# En bas : le rappel des touches et le bouton pour partir.
	var pied := HBoxContainer.new()
	pied.add_theme_constant_override("separation", 20)
	page.add_child(pied)
	var aide := _texte(pied, _aide(), 15, DISCRET)
	aide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aide.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var demarrer := _bouton("Démarrer la course", ACCENT, Color.WHITE, 26)
	demarrer.pressed.connect(func(): _lancer(false))
	pied.add_child(demarrer)
	demarrer.grab_focus()


func _aide() -> String:
	if choix["avions"]:
		var vol := "Traverse les anneaux dans l'ordre : le prochain est entouré de jaune. L'avion avance tout seul. Haut = piquer, Bas = monter.\n"
		if choix["joueurs"] == 2:
			return vol + "Joueur 1 : les flèches, J freiner, L tirer, M objet.   Joueur 2 : Z Q S D, Maj freiner, F tirer, E objet."
		return vol + "Les flèches ou Z Q S D pour piloter. Maj freiner, F tirer un pépin, E utiliser l'objet."
	if choix["joueurs"] == 2:
		return "Joueur 1 : les flèches. J déraper, K sauter, L tirer un pépin, M utiliser l'objet.\nJoueur 2 : Z Q S D. Maj déraper, Espace sauter, F tirer un pépin, E utiliser l'objet."
	return "Conduire : les flèches ou Z Q S D. Maj déraper, Espace sauter, F tirer un pépin, E utiliser l'objet.\nAttention aux obstacles entourés de rouge !"


# La carte d'un joueur : son pilote et son véhicule qui tournent, les flèches pour en changer,
# et les points de vitesse, d'accélération et de maniabilité.
func _carte_du_joueur(parent: Control, j: int) -> void:
	var carte := _carte(parent, "Joueur %d" % (j + 1) if choix["joueurs"] == 2 else "Ton pilote")
	carte.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pilote: Dictionary = Pilotes.PILOTES[choix["pilotes"][j]]
	var vehicule: Dictionary = Vehicules.VEHICULES[choix["vehicules"][j]]

	# L'aperçu en 3D.
	var cadre := SubViewportContainer.new()
	cadre.stretch = true
	cadre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carte.add_child(cadre)
	var scene := SubViewport.new()
	scene.own_world_3d = true
	scene.transparent_bg = true
	scene.msaa_3d = Viewport.MSAA_4X
	cadre.add_child(scene)
	var air := Environment.new()
	air.background_mode = Environment.BG_CLEAR_COLOR
	air.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	air.ambient_light_color = Color("#dfe6ff")
	air.ambient_light_energy = 0.8
	var monde := WorldEnvironment.new()
	monde.environment = air
	scene.add_child(monde)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-45, 150, 0)
	scene.add_child(soleil)
	var plateau := Node3D.new()
	scene.add_child(plateau)
	tournants.append(plateau)
	var socle := CylinderMesh.new()
	socle.top_radius = 5.4 if choix["avions"] else 2.7
	socle.bottom_radius = socle.top_radius + 0.2
	socle.height = 0.2
	var disque := MeshInstance3D.new()
	disque.mesh = socle
	var teinte := StandardMaterial3D.new()
	teinte.albedo_color = Color(pilote["couleur"]).lerp(CARTE, 0.55)
	disque.material_override = teinte
	disque.position.y = -0.5 if choix["avions"] else -0.1
	plateau.add_child(disque)
	plateau.add_child(Fruit.creer(pilote, vehicule, choix["avions"]))
	var camera := Camera3D.new()
	camera.fov = 40.0
	scene.add_child(camera)
	camera.position = Vector3(0, 4.0, -11.5) if choix["avions"] else Vector3(0, 2.7, -6.8)
	camera.look_at(Vector3(0, 1.1, 0))

	var nombre := Pilotes.PILOTES.size()
	_selecteur(carte, pilote["nom"], Color(pilote["couleur"]).lightened(0.35), 26,
		func(): choix["pilotes"][j] = (choix["pilotes"][j] + nombre - 1) % nombre,
		func(): choix["pilotes"][j] = (choix["pilotes"][j] + 1) % nombre)
	var garage := Vehicules.VEHICULES.size()
	_selecteur(carte, vehicule["avion"] if choix["avions"] else vehicule["nom"], TEXTE, 20,
		func(): choix["vehicules"][j] = (choix["vehicules"][j] + garage - 1) % garage,
		func(): choix["vehicules"][j] = (choix["vehicules"][j] + 1) % garage)

	# Les points : ceux du pilote, plus ou moins ceux du véhicule.
	var points := GridContainer.new()
	points.columns = 2
	points.add_theme_constant_override("h_separation", 14)
	points.add_theme_constant_override("v_separation", 6)
	points.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	carte.add_child(points)
	for qualite in [["Vitesse", "vitesse"], ["Accélération", "acceleration"], ["Maniabilité", "maniabilite"]]:
		_texte(points, qualite[0], 15, DISCRET)
		_pastilles(points, pilote[qualite[1]] + vehicule[qualite[1]], 6, JAUNE)


# La carte du circuit : son plan vu d'en haut, aux couleurs de son décor.
func _carte_du_circuit(parent: Control) -> void:
	var carte := _carte(parent, "Circuit")
	carte.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	var circuit: Dictionary = Circuits.CIRCUITS[choix["circuit"]]
	var longueur := _plan(carte, circuit, Vector2(330, 150))
	var nombre := Circuits.CIRCUITS.size()
	_selecteur(carte, circuit["nom"], TEXTE, 22,
		func(): choix["circuit"] = (choix["circuit"] + nombre - 1) % nombre,
		func(): choix["circuit"] = (choix["circuit"] + 1) % nombre)
	var info := _texte(carte, "%d m par tour  ·  décor : %s  ·  %d / %d" % [longueur, circuit.get("decor", "campagne"), choix["circuit"] + 1, nombre], 14, DISCRET)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# Dessine le plan d'un circuit et répond la longueur d'un tour, en mètres.
func _plan(parent: Control, circuit: Dictionary, taille: Vector2) -> int:
	var ambiance: Dictionary = Decor.ambiance(circuit.get("decor", "campagne"))
	var fond := Panel.new()
	fond.custom_minimum_size = taille
	fond.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fond.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ambiance["ciel"][0] if ambiance["sol"].is_empty() else ambiance["sol"][0])
	style.set_corner_radius_all(14)
	fond.add_theme_stylebox_override("panel", style)
	fond.clip_contents = true
	parent.add_child(fond)

	# La même courbe que celle de la piste (voir piste.gd).
	var courbe := Curve3D.new()
	var points: Array = circuit["points"]
	var n := points.size()
	for i in n + 1:
		var poignee: Vector3 = (points[(i + 1) % n] - points[(i - 1 + n) % n]) / 6.0
		courbe.add_point(points[i % n], -poignee, poignee)
	var trace := PackedVector2Array()
	var zone := Rect2()
	for i in 160:
		var p := courbe.sample_baked(courbe.get_baked_length() * i / 160.0)
		trace.append(Vector2(p.x, p.z))
		zone = Rect2(trace[0], Vector2.ZERO) if i == 0 else zone.expand(trace[i])
	var echelle := minf((taille.x - 40.0) / zone.size.x, (taille.y - 36.0) / zone.size.y)
	for i in trace.size():
		trace[i] = (trace[i] - zone.get_center()) * echelle + taille / 2.0
	for couche in [[9.0, Color(ambiance["barrieres"][0])], [5.5, Color(ambiance["route"][0])]]:
		var ligne := Line2D.new()
		ligne.points = trace
		ligne.closed = true
		ligne.width = couche[0]
		ligne.default_color = couche[1]
		ligne.joint_mode = Line2D.LINE_JOINT_ROUND
		ligne.antialiased = true
		fond.add_child(ligne)
	var depart := ColorRect.new()
	depart.color = Color.WHITE
	depart.size = Vector2(8, 8)
	depart.position = trace[0] - Vector2(4, 4)
	fond.add_child(depart)
	return int(courbe.get_baked_length())


# La carte du défi du jour.
func _carte_du_defi(parent: Control) -> void:
	var du_jour: Dictionary = Defi.du_jour()
	var carte := _carte(parent, "Défi du jour")
	var regle: Dictionary = du_jour["regle"]
	_texte(carte, regle["nom"], 20, JAUNE, true)
	var description := _texte(carte, "%s  ·  %s  ·  %d tours\n%s" % [Circuits.CIRCUITS[du_jour["circuit"]]["nom"], "Avions" if du_jour["avions"] else "Karts", du_jour["tours"], regle["texte"]], 14, TEXTE)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 12)
	carte.add_child(ligne)
	_pastilles(ligne, Defi.etoiles_du_jour(), 3, JAUNE, 18)
	var serie := Defi.serie()
	var suite := _texte(ligne, "Série : %d jour%s" % [serie, "s" if serie > 1 else ""] if serie > 0 else "Pas encore joué", 14, DISCRET)
	suite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var jouer := _bouton("Jouer le défi", CARTE_CLAIRE, JAUNE, 17)
	jouer.pressed.connect(func():
		defi = du_jour
		_lancer(false))
	ligne.add_child(jouer)


# ── Les briques du menu ──────────────────────────────────────

# Une carte : un panneau arrondi avec un petit titre. Répond la colonne où ranger le contenu.
func _carte(parent: Control, titre: String) -> VBoxContainer:
	var panneau := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARTE
	style.set_corner_radius_all(18)
	style.set_content_margin_all(16)
	panneau.add_theme_stylebox_override("panel", style)
	parent.add_child(panneau)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	panneau.add_child(colonne)
	_texte(colonne, titre.to_upper(), 13, DISCRET, true)
	return colonne


func _texte(parent: Control, contenu: String, taille: int, couleur: Color, gras := false) -> Label:
	var texte := Label.new()
	texte.text = contenu
	texte.add_theme_font_size_override("font_size", taille)
	texte.add_theme_color_override("font_color", couleur)
	if gras:
		texte.add_theme_font_override("font", GRAS)
	parent.add_child(texte)
	return texte


# Un petit titre suivi de boutons collés : celui qui est choisi est en jaune.
func _reglette(parent: Control, titre: String, noms: Array, actif: int, au_clic: Callable) -> void:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 6)
	parent.add_child(ligne)
	_texte(ligne, titre, 15, DISCRET).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for i in noms.size():
		var bouton := _bouton(noms[i], JAUNE if i == actif else CARTE_CLAIRE, FOND if i == actif else TEXTE, 17)
		bouton.pressed.connect(func():
			au_clic.call(i)
			_montrer_menu())
		ligne.add_child(bouton)


# Une flèche, un nom, une flèche : pour passer au précédent ou au suivant.
func _selecteur(parent: Control, nom: String, couleur: Color, taille: int, precedent: Callable, suivant: Callable) -> void:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 10)
	parent.add_child(ligne)
	for sens in 2:
		if sens == 1:
			var texte := _texte(ligne, nom, taille, couleur, true)
			texte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var fleche := _bouton("<" if sens == 0 else ">", CARTE_CLAIRE, TEXTE, 20)
		fleche.custom_minimum_size.x = 44
		fleche.pressed.connect(func():
			(precedent if sens == 0 else suivant).call()
			_montrer_menu())
		ligne.add_child(fleche)


# Une rangée de pastilles : « pleines » sont allumées, les autres éteintes.
func _pastilles(parent: Control, pleines: int, total: int, couleur: Color, taille := 14) -> void:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 5)
	ligne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(ligne)
	for i in total:
		var pastille := Panel.new()
		pastille.custom_minimum_size = Vector2(taille * 1.6, taille) if total > 3 else Vector2(taille, taille)
		var style := StyleBoxFlat.new()
		style.bg_color = couleur if i < pleines else CARTE_CLAIRE
		style.set_corner_radius_all(taille / 2)
		pastille.add_theme_stylebox_override("panel", style)
		ligne.add_child(pastille)


func _bouton(texte: String, fond: Color, encre: Color, taille: int) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.add_theme_font_size_override("font_size", taille)
	bouton.add_theme_font_override("font", GRAS)
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.set_corner_radius_all(12)
	style.set_content_margin_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	var survol: StyleBoxFlat = style.duplicate()
	survol.bg_color = fond.lightened(0.12)
	var focus: StyleBoxFlat = style.duplicate()
	focus.draw_center = false
	focus.border_color = Color.WHITE
	focus.set_border_width_all(2)
	bouton.add_theme_stylebox_override("normal", style)
	bouton.add_theme_stylebox_override("hover", survol)
	bouton.add_theme_stylebox_override("pressed", survol)
	bouton.add_theme_stylebox_override("focus", focus)
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		bouton.add_theme_color_override(etat, encre)
	return bouton


# Joue une musique en boucle (ou coupe le son si le fichier n'existe pas).
func _jouer(chemin: String) -> void:
	if R.VOLUME_MUSIQUE <= 0.0 or not ResourceLoader.exists(chemin):
		musique.stop()
		return
	var morceau: AudioStream = load(chemin)
	if musique.stream == morceau and musique.playing:
		return
	if "loop" in morceau:
		morceau.loop = true
	musique.stream = morceau
	musique.volume_db = linear_to_db(R.VOLUME_MUSIQUE)
	musique.play()


# ── La course et le classement ───────────────────────────────

func _nettoyer() -> void:
	for ancien in [menu, resultats, course]:
		if ancien != null and is_instance_valid(ancien):
			ancien.queue_free()
	menu = null
	resultats = null
	course = null


# Lance la course choisie dans le menu, ou le défi du jour si on a cliqué dessus.
func _lancer(demo: bool) -> void:
	_nettoyer()
	course = Course.new()
	course.demo = demo
	add_child(course)
	course.finie.connect(_montrer_resultats)
	var joueurs: int = 1 if not defi.is_empty() else choix["joueurs"]
	var humains: Array = choix["pilotes"].slice(0, joueurs)
	if joueurs == 2 and humains[0] == humains[1]:
		humains[1] = (humains[0] + 1) % Pilotes.PILOTES.size()  # pas deux fois le même fruit
	var circuit: Dictionary = Circuits.CIRCUITS[defi["circuit"] if not defi.is_empty() else choix["circuit"]]
	if defi.is_empty():
		course.demarrer(circuit, humains, choix["vehicules"], choix["tours"], choix["avions"])
	else:
		course.demarrer(circuit, humains, choix["vehicules"], defi["tours"], defi["avions"], defi["regle"]["effet"])
	_jouer(circuit.get("musique", ""))


func _montrer_resultats(classement: Array) -> void:
	_jouer(R.MUSIQUE_ARRIVEE)
	resultats = ColorRect.new()
	resultats.color = Color(FOND, 0.8)
	resultats.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(resultats)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	resultats.add_child(centre)
	var carte := _carte(centre, "Défi du jour" if not defi.is_empty() else "Résultat")
	carte.custom_minimum_size.x = 440
	_texte(carte, "Classement", 34, TEXTE, true)

	var place := 0
	for i in classement.size():
		var r: Dictionary = classement[i]
		if r["humain"] and place == 0:
			place = i + 1
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 14)
		carte.add_child(ligne)
		var couleur := JAUNE if r["humain"] else TEXTE
		_texte(ligne, "%d" % (i + 1), 22, DISCRET, true).custom_minimum_size.x = 26
		_texte(ligne, r["nom"], 22, couleur, r["humain"]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_texte(ligne, "%.1f s" % r["temps"] if r["temps"] >= 0.0 else "—", 20, couleur)

	# Le défi du jour : on gagne une, deux ou trois étoiles.
	if not defi.is_empty() and place > 0:
		var etoiles := Defi.noter(place)
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 12)
		carte.add_child(ligne)
		_pastilles(ligne, etoiles, 3, JAUNE, 22)
		_texte(ligne, Defis.ETOILES[etoiles - 1] + " : %d étoile%s !" % [etoiles, "s" if etoiles > 1 else ""], 17, JAUNE, true)

	var boutons := HBoxContainer.new()
	boutons.add_theme_constant_override("separation", 12)
	boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	carte.add_child(boutons)
	var rejouer := _bouton("Rejouer", ACCENT, Color.WHITE, 22)
	rejouer.pressed.connect(func(): _lancer(false))
	boutons.add_child(rejouer)
	var retour := _bouton("Menu", CARTE_CLAIRE, TEXTE, 22)
	retour.pressed.connect(_montrer_menu)
	boutons.add_child(retour)
	rejouer.grab_focus()


# ── Les essais automatiques ──────────────────────────────────

func _process(dt: float) -> void:
	angle += dt * 0.7
	for plateau in tournants:
		if is_instance_valid(plateau):
			plateau.rotation.y = angle
	if capture != "" and essai_derapage == "" and essai_bonus == "" and course != null and course.temps > 4.0:
		get_viewport().get_texture().get_image().save_png(capture)
		get_tree().quit()
	if essai_bonus != "" and course != null:
		var kart = course.vues[0]["kart"]
		if course.temps >= essai_trace:
			essai_trace += 0.25
			print("t=%.2f hauteur=%.2f pépins=%d objet=%s en vol=%d flaques=%d bouclier=%.1f turbo=%.1f vitesse=%.1f" % [course.temps, kart.ou_suis_je().y, kart.pepins, kart.objet, course.pepins.size(), course.flaques.size(), kart.bouclier, kart.turbo, kart.vitesse])
		if course.temps > 1.3 and capture == "":
			capture = "fait"
			get_viewport().get_texture().get_image().save_png(essai_bonus)
		if course.temps > 14.0:
			get_tree().quit()
	if essai_derapage != "" and course != null:
		var kart = course.vues[0]["kart"]
		if course.temps >= essai_trace:
			essai_trace += 0.25
			print("t=%.2f dérapage=%.0f charge=%.2f turbo=%.2f vitesse=%.1f" % [course.temps, kart.derapage, kart.charge, kart.turbo, kart.vitesse])
		if course.temps > 2.8 and capture == "":
			capture = "fait"
			get_viewport().get_texture().get_image().save_png(essai_derapage)
		if course.temps > 4.0:
			get_tree().quit()


# Photographie tous les pilotes côte à côte, vus de face, avec une cagette et une flaque.
func _galerie(fichier: String) -> void:
	var piste: Node3D = preload("res://jeu/piste.gd").new()
	add_child(piste)
	piste.construire(Circuits.CIRCUITS[0])
	var depart: Transform3D = piste.repere(20.0)
	for i in Pilotes.PILOTES.size():
		var fruit: Node3D = preload("res://jeu/fruit.gd").creer(Pilotes.PILOTES[i], Vehicules.VEHICULES[i % Vehicules.VEHICULES.size()], choix["avions"])
		fruit.transform = depart.translated_local(Vector3((i % 4 - 1.5) * 3.3, 0, -(i / 4) * 5.0)).rotated_local(Vector3.UP, PI + (i % 4 - 1.5) * 0.3)
		add_child(fruit)
	var camera := Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	camera.global_position = depart * Vector3(0, 5.0, 9.5)
	camera.look_at(depart * Vector3(0, 0.8, -2.0))
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(fichier)
	get_tree().quit()


# Fait courir les ordinateurs seuls sur chaque circuit et écrit le résultat.
func _simuler() -> void:
	_nettoyer()
	if essai_circuit >= Circuits.CIRCUITS.size():
		get_tree().quit()
		return
	course = Course.new()
	add_child(course)
	course.demarrer(Circuits.CIRCUITS[essai_circuit], [], [], 0, choix["avions"])
	print("%s : %.0f m par tour, %d tours" % [Circuits.CIRCUITS[essai_circuit]["nom"], course.piste.longueur, course.piste.tours])
	course.finie.connect(func(classement: Array):
		for r in classement:
			print("  %-8s %s" % [r["nom"], ("%.1f s" % r["temps"]) if r["temps"] >= 0.0 else "PAS ARRIVÉ"])
		for kart in course.karts:
			print("  · %-8s retours en piste %d, vitesse max %.0f, hauteur max %.1f" % [kart.pilote["nom"], kart.retours, kart.vitesse_max, kart.hauteur_max])
		essai_circuit += 1
		_simuler.call_deferred())
