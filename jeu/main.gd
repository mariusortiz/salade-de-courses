# Le chef d'orchestre : le menu, le lancement d'une course, le classement.
extends Node

const R = preload("res://donnees/reglages.gd")
const Circuits = preload("res://donnees/circuits.gd")
const Pilotes = preload("res://donnees/pilotes.gd")
const Vehicules = preload("res://donnees/vehicules.gd")
const Course = preload("res://jeu/course.gd")

const ENCRE := Color("#1d2433")

var choix := {"joueurs": 1, "pilotes": [0, 1], "vehicules": [0, 0], "circuit": 0, "tours": 3, "avions": false}
var menu: Control
var resultats: Control
var course: Node

# Pour les essais automatiques (voir le README, partie « Vérifier »).
var essai_circuit := -1
var capture := ""
var essai_derapage := ""
var essai_bonus := ""
var essai_trace := 0.0
var musique := AudioStreamPlayer.new()


func _ready() -> void:
	get_window().title = R.TITRE
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
	menu = ColorRect.new()
	menu.color = Color("#a6dcf5")
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(centre)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 6)
	centre.add_child(colonne)

	_titre(colonne, R.TITRE, 48)

	# Sur la même ligne : le nombre de joueurs et le nombre de tours.
	var ligne := HBoxContainer.new()
	ligne.alignment = BoxContainer.ALIGNMENT_CENTER
	ligne.add_theme_constant_override("separation", 10)
	colonne.add_child(ligne)
	_titre(ligne, "Joueurs", 20)
	_boutons(ligne, ["1", "2"], choix["joueurs"] - 1, func(i): choix["joueurs"] = i + 1)
	_titre(ligne, "      Tours", 20)
	_boutons(ligne, R.CHOIX_DE_TOURS.map(func(t): return str(t)), R.CHOIX_DE_TOURS.find(choix["tours"]), func(i): choix["tours"] = R.CHOIX_DE_TOURS[i])

	_titre(ligne, "      Mode", 20)
	_boutons(ligne, ["Karts", "Avions"], 1 if choix["avions"] else 0, func(i): choix["avions"] = i == 1)

	# Chaque joueur choisit son pilote et son véhicule. À deux, les joueurs sont côte à côte.
	var noms: Array = Pilotes.PILOTES.map(func(p): return p["nom"])
	var couleurs: Array = Pilotes.PILOTES.map(func(p): return Color(p["couleur"]))
	var joueurs := HBoxContainer.new()
	joueurs.alignment = BoxContainer.ALIGNMENT_CENTER
	joueurs.add_theme_constant_override("separation", 30)
	colonne.add_child(joueurs)
	var largeur := 1180 if choix["joueurs"] == 1 else 590
	for j in choix["joueurs"]:
		var bloc := VBoxContainer.new()
		bloc.add_theme_constant_override("separation", 6)
		joueurs.add_child(bloc)
		_titre(bloc, "Joueur %d : pilote" % (j + 1) if choix["joueurs"] == 2 else "Pilote", 20)
		_rangee(bloc, noms, choix["pilotes"][j], func(i): choix["pilotes"][j] = i, couleurs, largeur)
		_titre(bloc, "Avion" if choix["avions"] else "Véhicule", 20)
		_rangee(bloc, Vehicules.VEHICULES.map(func(v): return v["avion"] if choix["avions"] else v["nom"]), choix["vehicules"][j], func(i): choix["vehicules"][j] = i, [], largeur)

	_titre(colonne, "Circuit", 20)
	_rangee(colonne, Circuits.CIRCUITS.map(func(c): return c["nom"]), choix["circuit"], func(i): choix["circuit"] = i)

	var demarrer := _bouton("Démarrer", Color("#ff7043"), ENCRE, 30)
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		demarrer.add_theme_color_override(etat, Color.WHITE)
	demarrer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	demarrer.pressed.connect(func(): _lancer(false))
	colonne.add_child(demarrer)
	demarrer.grab_focus()

	if choix["avions"]:
		_titre(colonne, "Traverse les anneaux dans l'ordre : le prochain est entouré de jaune. L'avion avance tout seul.", 18)
		if choix["joueurs"] == 2:
			_titre(colonne, "Joueur 1 : les flèches (haut = monter). J freiner, L tirer, M objet.     Joueur 2 : Z Q S D. Maj freiner, F tirer, E objet.", 18)
		else:
			_titre(colonne, "Les flèches ou Z Q S D : tourner, monter (haut), descendre (bas). Maj freiner, F tirer un pépin, E utiliser l'objet.", 18)
	elif choix["joueurs"] == 2:
		_titre(colonne, "Joueur 1 : les flèches. J déraper, K sauter, L tirer un pépin, M utiliser l'objet.", 18)
		_titre(colonne, "Joueur 2 : Z Q S D. Maj déraper, Espace sauter, F tirer un pépin, E utiliser l'objet.", 18)
	else:
		_titre(colonne, "Conduire : les flèches ou Z Q S D. Maj déraper, Espace sauter, F tirer un pépin, E utiliser l'objet.", 18)


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


func _titre(parent: Control, texte: String, taille: int) -> void:
	var titre := Label.new()
	titre.text = texte
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", taille)
	titre.add_theme_color_override("font_color", ENCRE)
	parent.add_child(titre)


func _rangee(parent: Control, noms: Array, actif: int, au_clic: Callable, bords: Array = [], largeur := 1180) -> void:
	# Quand il y a trop de boutons pour une seule ligne, ils passent à la ligne suivante.
	var rangee := HFlowContainer.new()
	rangee.alignment = FlowContainer.ALIGNMENT_CENTER
	rangee.custom_minimum_size.x = largeur
	rangee.add_theme_constant_override("h_separation", 10)
	rangee.add_theme_constant_override("v_separation", 8)
	parent.add_child(rangee)
	_boutons(rangee, noms, actif, au_clic, bords)


# Ajoute une série de boutons : celui qui est choisi est en jaune.
func _boutons(parent: Control, noms: Array, actif: int, au_clic: Callable, bords: Array = []) -> void:
	for i in noms.size():
		var fond := Color("#ffd54f") if i == actif else Color.WHITE
		var bouton := _bouton(noms[i], fond, bords[i] if not bords.is_empty() else ENCRE, 18)
		bouton.pressed.connect(func():
			au_clic.call(i)
			_montrer_menu())
		parent.add_child(bouton)


func _bouton(texte: String, fond: Color, bord: Color, taille: int) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.add_theme_font_size_override("font_size", taille)
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.border_color = bord
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	var survol: StyleBoxFlat = style.duplicate()
	survol.bg_color = fond.darkened(0.08)
	var focus: StyleBoxFlat = style.duplicate()
	focus.draw_center = false
	focus.border_color = Color("#1565c0")
	bouton.add_theme_stylebox_override("normal", style)
	bouton.add_theme_stylebox_override("hover", survol)
	bouton.add_theme_stylebox_override("pressed", survol)
	bouton.add_theme_stylebox_override("focus", focus)
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		bouton.add_theme_color_override(etat, ENCRE)
	return bouton


# ── La course et le classement ───────────────────────────────

func _nettoyer() -> void:
	for ancien in [menu, resultats, course]:
		if ancien != null and is_instance_valid(ancien):
			ancien.queue_free()
	menu = null
	resultats = null
	course = null


func _lancer(demo: bool) -> void:
	_nettoyer()
	course = Course.new()
	course.demo = demo
	add_child(course)
	course.finie.connect(_montrer_resultats)
	var humains: Array = choix["pilotes"].slice(0, choix["joueurs"])
	if choix["joueurs"] == 2 and humains[0] == humains[1]:
		humains[1] = (humains[0] + 1) % Pilotes.PILOTES.size()  # pas deux fois le même fruit
	course.demarrer(Circuits.CIRCUITS[choix["circuit"]], humains, choix["vehicules"], choix["tours"], choix["avions"])
	_jouer(Circuits.CIRCUITS[choix["circuit"]].get("musique", ""))


func _montrer_resultats(classement: Array) -> void:
	_jouer(R.MUSIQUE_ARRIVEE)
	resultats = ColorRect.new()
	resultats.color = Color(1, 1, 1, 0.85)
	resultats.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(resultats)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	resultats.add_child(centre)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 8)
	centre.add_child(colonne)

	_titre(colonne, "Classement", 56)
	for i in classement.size():
		var r: Dictionary = classement[i]
		var ligne := "%d.  %s" % [i + 1, r["nom"]]
		if r["temps"] >= 0.0:
			ligne += "   %.1f s" % r["temps"]
		if r["humain"]:
			ligne += "   ◀"
		_titre(colonne, ligne, 30)

	var rejouer := _bouton("Rejouer", Color("#ff7043"), ENCRE, 30)
	rejouer.pressed.connect(func(): _lancer(false))
	colonne.add_child(rejouer)
	var retour := _bouton("Menu", Color.WHITE, ENCRE, 22)
	retour.pressed.connect(_montrer_menu)
	colonne.add_child(retour)
	rejouer.grab_focus()


# ── Les essais automatiques ──────────────────────────────────

func _process(_dt: float) -> void:
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
