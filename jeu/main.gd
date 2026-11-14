# Le chef d'orchestre : le menu, le lancement d'une course, le classement.
extends Node

const R = preload("res://donnees/reglages.gd")
const Circuits = preload("res://donnees/circuits.gd")
const Pilotes = preload("res://donnees/pilotes.gd")
const Vehicules = preload("res://donnees/vehicules.gd")
const Defis = preload("res://donnees/defis.gd")
const Modes = preload("res://donnees/modes.gd")
const Course = preload("res://jeu/course.gd")
const Decor = preload("res://jeu/decor.gd")
const Fruit = preload("res://jeu/fruit.gd")
const Defi = preload("res://jeu/defi.gd")
const Magasin = preload("res://jeu/magasin.gd")
const Skate = preload("res://jeu/skate.gd")
const S = preload("res://donnees/skate.gd")

# Les couleurs du menu.
const FOND := Color("#101629")
const CARTE := Color("#1c2440")
const CARTE_CLAIRE := Color("#2c3763")
const ACCENT := Color("#ff6b3d")
const JAUNE := Color("#ffd54f")
const TEXTE := Color("#f4f6ff")
const DISCRET := Color("#9aa6c7")

var GRAS := FontVariation.new()  # la police des titres, en plus épais

var choix := {"joueurs": 1, "pilotes": [0, 1], "vehicules": [0, 0], "circuit": 0, "tours": 3, "avions": false, "onglet": 0, "epreuve": 0, "skate": false, "planches": [0, 0]}
var menu: Control
var resultats: Control
var course: Node
var defi := {}             # le défi du jour, quand on est en train de le jouer
var tournants: Array = []  # les plateaux du menu, qui tournent pour montrer les pilotes
var angle := 0.0
var au_magasin := false     # true = on regarde le magasin au lieu du menu
var rayon_avions := false   # le rayon du magasin : les voitures ou les avions
var en_demo := false

# Pour les essais automatiques (voir le README, partie « Vérifier »).
var essai_circuit := -1
var capture := ""
var essai_derapage := ""
var essai_bonus := ""
var essai_trace := 0.0
var essai_raccourci := ""
var essai_secret := false
var essai_skate := ""
var musique := AudioStreamPlayer.new()


func _ready() -> void:
	get_window().title = R.TITRE
	GRAS.variation_embolden = 0.9
	add_child(musique)
	for option in OS.get_cmdline_user_args():
		if option == "--simulation":
			essai_circuit = 0
		elif option.begins_with("--simulation="):
			essai_circuit = int(option.trim_prefix("--simulation="))  # on commence à ce circuit
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
			var essai := {"touches": 1, "retours": 0, "tirs": 3, "cagettes": 2, "glisses": 0}
			defi = {"circuit": 0, "avions": false, "tours": 3, "regle": {"effet": ""}, "epreuve": Defi.du_circuit(0)[1]}
			_montrer_resultats([{"nom": "Pastek", "temps": 61.2, "humain": false}.merged(essai), {"nom": "Pépin", "temps": 63.9, "humain": true}.merged(essai), {"nom": "Mimi", "temps": -1.0, "humain": false}.merged(essai)])
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
		elif option == "--skate":
			choix["skate"] = true
		elif option.begins_with("--essai-skate="):
			choix["skate"] = true
			essai_skate = option.trim_prefix("--essai-skate=")
		elif option == "--secret":
			essai_secret = true
		elif option.begins_with("--essai-raccourci="):
			essai_raccourci = option.trim_prefix("--essai-raccourci=")
		elif option.begins_with("--epreuve="):
			choix["epreuve"] = int(option.trim_prefix("--epreuve="))
		elif option == "--magasin":
			au_magasin = true
			rayon_avions = choix["avions"]
		elif option.begins_with("--graines="):
			Magasin.gagner(int(option.trim_prefix("--graines=")))
		elif option.begins_with("--onglet="):
			choix["onglet"] = int(option.trim_prefix("--onglet="))
		elif option.begins_with("--joueurs="):
			choix["joueurs"] = int(option.trim_prefix("--joueurs="))
	if essai_circuit >= 0:
		_simuler()
	elif capture != "":
		_lancer(true)
	elif essai_skate != "":
		# L'ordinateur fait une démonstration, et on écrit toutes ses figures.
		_lancer(true)
		en_demo = false  # pour voir aussi le record et les graines à la fin
		course.skateurs[0].bavard = true
		course.duree = 14.0
	elif essai_raccourci != "":
		# Le joueur 1 est posé à l'entrée du premier raccourci et roule tout droit.
		_lancer(false)
		course.scenario = func(_t: float) -> Array:
			return [Vector2(0.0, 1.0), [false, false, false, false]]
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
	page.add_theme_constant_override("separation", 10)
	marge.add_child(page)
	if au_magasin:
		_montrer_le_magasin(page)
		return
	# Certaines épreuves ne se jouent qu'en kart, ou qu'à un seul joueur.
	var epreuve: Dictionary = Modes.EPREUVES[choix["epreuve"]]
	if not epreuve["avions"] and not choix["skate"]:
		choix["avions"] = false
	if epreuve["seul"] and not choix["skate"]:
		choix["joueurs"] = 1
	# Si le véhicule choisi n'est pas (ou plus) dans le garage, on reprend le premier.
	for j in 2:
		if not Magasin.possede(choix["vehicules"][j], choix["avions"]):
			choix["vehicules"][j] = 0

	# En haut : le titre, puis le mode, le nombre de joueurs et le nombre de tours.
	var entete := HBoxContainer.new()
	entete.add_theme_constant_override("separation", 12)
	page.add_child(entete)
	var titre := _texte(entete, R.TITRE, 32, TEXTE, true)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_texte(entete, "%d graines" % Magasin.graines(), 17, JAUNE, true).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var boutique := _bouton("Magasin", CARTE_CLAIRE, JAUNE, 17)
	boutique.pressed.connect(func():
		au_magasin = true
		rayon_avions = choix["avions"]
		_montrer_menu())
	entete.add_child(boutique)
	_reglette(entete, "Mode", ["Karts", "Avions", "Skate"], 2 if choix["skate"] else (1 if choix["avions"] else 0), func(i):
		choix["avions"] = i == 1
		choix["skate"] = i == 2)
	_reglette(entete, "Joueurs", ["1", "2"], choix["joueurs"] - 1, func(i): choix["joueurs"] = i + 1)
	if choix["skate"]:
		_menu_du_skate(page)
		return
	_reglette(entete, "Tours", R.CHOIX_DE_TOURS.map(func(t): return str(t)), R.CHOIX_DE_TOURS.find(choix["tours"]), func(i): choix["tours"] = R.CHOIX_DE_TOURS[i])

	# Juste dessous : l'épreuve, et sa règle.
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 16)
	page.add_child(ligne)
	_reglette(ligne, "Épreuve", Modes.EPREUVES.map(func(e): return e["nom"]), choix["epreuve"], func(i): choix["epreuve"] = i)
	var regle := _texte(ligne, epreuve["texte"] + ("" if epreuve["avions"] else " (En kart seulement.)"), 14, DISCRET)
	regle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	regle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

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
	_carte_des_defis(droite)

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


# Le menu du mode Skate : les joueurs à gauche, les règles et les figures à droite.
func _menu_du_skate(page: Control) -> void:
	var corps := HBoxContainer.new()
	corps.add_theme_constant_override("separation", 14)
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(corps)
	for j in choix["joueurs"]:
		_carte_du_joueur(corps, j)

	var carte := _carte(corps, "Le skatepark des fruits")
	carte.get_parent().custom_minimum_size.x = 430 if choix["joueurs"] == 1 else 380
	var regle := _texte(carte, "Tu as %d minutes pour marquer le plus de points en faisant des figures. Tout ce que tu enchaînes sans retoucher le sol forme un combo : les points sont multipliés par le nombre de figures. Si tu tombes, le combo est perdu !" % int(S.DUREE / 60.0), 15, TEXTE)
	regle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte(carte, "LES FIGURES", 13, DISCRET, true)
	var figures := GridContainer.new()
	figures.columns = 2
	figures.add_theme_constant_override("h_separation", 14)
	figures.add_theme_constant_override("v_separation", 5)
	carte.add_child(figures)
	for ligne in [
			["toupie", "en l'air, gauche ou droite", "par demi-tour"],
			["salto", "en l'air, haut ou bas", "par tour complet"],
			["tonneau", "en l'air, le bouton tonneau", ""],
			["attrape", "en l'air, tenir le bouton attraper", "par seconde"],
			["glissade", "retomber sur une barre", "par seconde"],
			["grand_saut", "sauter très haut", "par mètre"]]:
		var figure: Dictionary = S.FIGURES[ligne[0]]
		_texte(figures, figure["nom"], 16, JAUNE, true)
		_texte(figures, "%s — %d points %s" % [ligne[1], figure["points"], ligne[2]], 14, DISCRET)
	var meilleur := int(Defi.record("Skatepark").get("temps", 0))
	var bas := _texte(carte, ("Ton record : %d points" % meilleur) if meilleur > 0 else "Pas encore de record : à toi de jouer !", 18, JAUNE, true)
	bas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bas.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	var pied := HBoxContainer.new()
	pied.add_theme_constant_override("separation", 20)
	page.add_child(pied)
	var aide := _texte(pied, _aide(), 15, DISCRET)
	aide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aide.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var demarrer := _bouton("Démarrer la session", ACCENT, Color.WHITE, 26)
	demarrer.pressed.connect(func(): _lancer(false))
	pied.add_child(demarrer)
	demarrer.grab_focus()


func _aide() -> String:
	if choix["skate"]:
		if choix["joueurs"] == 2:
			return "Joueur 1 : les flèches. K sauter, L tonneau, M attraper.   Joueur 2 : Z Q S D. Espace sauter, F tonneau, E attraper.\nEn l'air : gauche et droite pour la toupie, haut et bas pour le salto. Il faut finir ses figures avant de retomber !"
		return "Rouler : les flèches ou Z Q S D (haut pour pousser, bas pour freiner). Espace sauter, F tonneau, E attraper la planche.\nEn l'air : gauche et droite pour la toupie, haut et bas pour le salto. Il faut finir ses figures avant de retomber !"
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
	if choix["skate"]:
		vehicule = S.PLANCHES[choix["planches"][j]]

	_apercu(carte, pilote, vehicule, choix["avions"] and not choix["skate"])

	var nombre := Pilotes.PILOTES.size()
	_selecteur(carte, pilote["nom"], Color(pilote["couleur"]).lightened(0.35), 26,
		func(): choix["pilotes"][j] = (choix["pilotes"][j] + nombre - 1) % nombre,
		func(): choix["pilotes"][j] = (choix["pilotes"][j] + 1) % nombre)
	if choix["skate"]:
		# En skate, on choisit seulement sa planche : elles roulent toutes pareil.
		var planches: int = S.PLANCHES.size()
		_selecteur(carte, vehicule["nom"], TEXTE, 20,
			func(): choix["planches"][j] = (choix["planches"][j] + planches - 1) % planches,
			func(): choix["planches"][j] = (choix["planches"][j] + 1) % planches)
		return
	# On ne peut choisir que les véhicules de son garage (les autres s'achètent au magasin).
	var garage: Array = Magasin.garage(choix["avions"])
	var rang: int = maxi(0, garage.find(choix["vehicules"][j]))
	_selecteur(carte, vehicule["avion"] if choix["avions"] else vehicule["nom"], TEXTE, 20,
		func(): choix["vehicules"][j] = garage[(rang + garage.size() - 1) % garage.size()],
		func(): choix["vehicules"][j] = garage[(rang + 1) % garage.size()])

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


# Montre un pilote dans son véhicule, en 3D, sur un plateau qui tourne.
# etroit : true quand la carte est plus haute que large (au magasin).
func _apercu(parent: Control, pilote: Dictionary, vehicule: Dictionary, en_avion: bool, etroit := false) -> void:
	var cadre := SubViewportContainer.new()
	cadre.stretch = true
	cadre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(cadre)
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
	socle.top_radius = 5.4 if en_avion else 2.7
	socle.bottom_radius = socle.top_radius + 0.2
	socle.height = 0.2
	var disque := MeshInstance3D.new()
	disque.mesh = socle
	var teinte := StandardMaterial3D.new()
	teinte.albedo_color = Color(pilote["couleur"]).lerp(CARTE, 0.55)
	disque.material_override = teinte
	disque.position.y = -0.5 if en_avion else -0.1
	plateau.add_child(disque)
	plateau.add_child(Fruit.creer(pilote, vehicule, en_avion))
	var camera := Camera3D.new()
	camera.fov = 40.0
	scene.add_child(camera)
	camera.position = Vector3(0, 4.0, -11.5) if en_avion else Vector3(0, 2.7, -6.8)
	camera.look_at(Vector3(0, 1.1, 0))
	if etroit:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = 46.0 if en_avion else 33.0


# ── Le magasin ───────────────────────────────────────────────

# Le magasin a deux rayons : les voitures et les avions. On paie avec les graines gagnées en course.
func _montrer_le_magasin(page: Control) -> void:
	var entete := HBoxContainer.new()
	entete.add_theme_constant_override("separation", 22)
	page.add_child(entete)
	var titre := _texte(entete, "Le magasin", 36, TEXTE, true)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var graines: int = Magasin.graines()
	_texte(entete, "%d graines" % graines, 20, JAUNE, true).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reglette(entete, "Rayon", ["Voitures", "Avions"], 1 if rayon_avions else 0, func(i): rayon_avions = i == 1)
	var retour := _bouton("Retour au menu", ACCENT, Color.WHITE, 17)
	retour.pressed.connect(func():
		au_magasin = false
		_montrer_menu())
	entete.add_child(retour)

	# Les véhicules sont rangés sur deux étagères.
	var rayon := GridContainer.new()
	rayon.columns = int(ceil(Vehicules.VEHICULES.size() / 2.0))
	rayon.add_theme_constant_override("h_separation", 8)
	rayon.add_theme_constant_override("v_separation", 8)
	rayon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(rayon)
	var pilote: Dictionary = Pilotes.PILOTES[choix["pilotes"][0]]
	for numero in Vehicules.VEHICULES.size():
		var vehicule: Dictionary = Vehicules.VEHICULES[numero]
		var carte := _carte(rayon, vehicule["avion"] if rayon_avions else vehicule["nom"])
		carte.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		carte.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
		_apercu(carte, pilote, vehicule, rayon_avions, true)
		# Ses forces et ses faiblesses, sur une seule ligne pour laisser la place à l'image.
		var qualites := HBoxContainer.new()
		qualites.alignment = BoxContainer.ALIGNMENT_CENTER
		qualites.add_theme_constant_override("separation", 10)
		carte.add_child(qualites)
		for qualite in [["Vit.", "vitesse"], ["Acc.", "acceleration"], ["Man.", "maniabilite"]]:
			var plus: int = vehicule[qualite[1]]
			_texte(qualites, "%s %s" % [qualite[0], ("+%d" % plus) if plus > 0 else ("%d" % plus if plus < 0 else "=")], 13, JAUNE if plus > 0 else (ACCENT if plus < 0 else DISCRET))
		var prix: int = Magasin.prix(numero, rayon_avions)
		if Magasin.possede(numero, rayon_avions):
			var a_nous := _bouton("Dans ton garage", CARTE, JAUNE, 16)
			a_nous.disabled = true
			a_nous.add_theme_color_override("font_disabled_color", JAUNE)
			a_nous.add_theme_stylebox_override("disabled", a_nous.get_theme_stylebox("normal"))
			carte.add_child(a_nous)
		else:
			_texte(carte, "%d graines" % prix, 16, JAUNE, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if Magasin.possede(numero, rayon_avions):
			pass
		elif graines >= prix:
			var acheter := _bouton("Acheter", ACCENT, Color.WHITE, 16)
			acheter.pressed.connect(func():
				Magasin.acheter(numero, rayon_avions)
				_montrer_menu())
			carte.add_child(acheter)
		else:
			var trop_cher := _bouton("Il manque %d" % (prix - graines), CARTE_CLAIRE, DISCRET, 14)
			trop_cher.disabled = true
			trop_cher.add_theme_color_override("font_disabled_color", DISCRET)
			trop_cher.add_theme_stylebox_override("disabled", trop_cher.get_theme_stylebox("normal"))
			carte.add_child(trop_cher)

	var aide := _texte(page, "On gagne des graines en finissant une course (plus on est bien classé, plus on en gagne), en réussissant les défis des circuits et en gagnant des étoiles au défi du jour.", 15, DISCRET)
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


# La carte du circuit : son plan vu d'en haut, aux couleurs de son décor.
func _carte_du_circuit(parent: Control) -> void:
	var carte := _carte(parent, "Circuit")
	carte.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	var circuit: Dictionary = Circuits.CIRCUITS[choix["circuit"]]
	var longueur := _plan(carte, circuit, Vector2(330, 120) if choix["joueurs"] == 1 else Vector2(300, 56))
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

	var courbe: Curve3D = Defi.courbe(circuit)
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
	# Les raccourcis, en pointillé.
	var tour := courbe.get_baked_length()
	for bouts in circuit.get("raccourcis", []):
		var de := courbe.sample_baked(float(bouts[0]) * tour)
		var a := courbe.sample_baked(float(bouts[1]) * tour)
		for k in range(1, 10, 2):
			var pointille := Line2D.new()
			pointille.points = PackedVector2Array([
				(Vector2(de.x, de.z).lerp(Vector2(a.x, a.z), k / 10.0) - zone.get_center()) * echelle + taille / 2.0,
				(Vector2(de.x, de.z).lerp(Vector2(a.x, a.z), (k + 1) / 10.0) - zone.get_center()) * echelle + taille / 2.0])
			pointille.width = 3.0
			pointille.default_color = Color(ambiance["lignes"][1])
			fond.add_child(pointille)
	var depart := ColorRect.new()
	depart.color = Color.WHITE
	depart.size = Vector2(8, 8)
	depart.position = trace[0] - Vector2(4, 4)
	fond.add_child(depart)
	return int(courbe.get_baked_length())


# La carte des défis, avec deux onglets : le défi du jour, et les trois défis du circuit choisi.
func _carte_des_defis(parent: Control) -> void:
	var carte := _carte(parent, "Défis")
	var onglets := HBoxContainer.new()
	onglets.add_theme_constant_override("separation", 6)
	carte.add_child(onglets)
	for i in 2:
		var onglet := _bouton(["Du jour", "Du circuit"][i], JAUNE if i == choix["onglet"] else CARTE_CLAIRE, FOND if i == choix["onglet"] else TEXTE, 15)
		onglet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		onglet.pressed.connect(func():
			choix["onglet"] = i
			_montrer_menu())
		onglets.add_child(onglet)
	if choix["onglet"] == 0:
		_defi_du_jour(carte)
	else:
		_defis_du_circuit(carte)


func _defi_du_jour(carte: Control) -> void:
	var du_jour: Dictionary = Defi.du_jour()
	var regle: Dictionary = du_jour["regle"]
	_texte(carte, regle["nom"], 19, JAUNE, true)
	var description := _texte(carte, "%s  ·  %s  ·  %d tours\n%s" % [Circuits.CIRCUITS[du_jour["circuit"]]["nom"], "Avions" if du_jour["avions"] else "Karts", du_jour["tours"], regle["texte"]], 14, TEXTE)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 12)
	carte.add_child(ligne)
	_pastilles(ligne, Defi.etoiles_du_jour(), 3, JAUNE, 18)
	var serie := Defi.serie()
	var suite := _texte(ligne, "Série : %d jour%s" % [serie, "s" if serie > 1 else ""] if serie > 0 else "Pas encore joué", 14, DISCRET)
	suite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var jouer := _bouton("Jouer", CARTE_CLAIRE, JAUNE, 16)
	jouer.pressed.connect(func():
		defi = du_jour
		_lancer(false))
	ligne.add_child(jouer)


# Les trois défis du circuit choisi : une pastille jaune quand le défi est réussi.
func _defis_du_circuit(carte: Control) -> void:
	var nom: String = Circuits.CIRCUITS[choix["circuit"]]["nom"]
	var faits: Array = Defi.reussis(nom)
	for epreuve in Defi.du_circuit(choix["circuit"]):
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 10)
		carte.add_child(ligne)
		_pastilles(ligne, 1 if faits.has(epreuve["cle"]) else 0, 1, JAUNE, 16)
		var textes := VBoxContainer.new()
		textes.add_theme_constant_override("separation", 0)
		textes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ligne.add_child(textes)
		_texte(textes, epreuve["nom"], 15, JAUNE if faits.has(epreuve["cle"]) else TEXTE, true)
		_texte(textes, epreuve["texte"], 12, DISCRET).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var jouer := _bouton("Jouer", CARTE_CLAIRE, JAUNE, 14)
		jouer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		jouer.pressed.connect(func():
			defi = {"circuit": choix["circuit"], "avions": epreuve["avions"], "tours": 3, "regle": {"effet": ""}, "epreuve": epreuve}
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
	en_demo = demo
	var joueurs: int = 1 if not defi.is_empty() else choix["joueurs"]
	var humains: Array = choix["pilotes"].slice(0, joueurs)
	if joueurs == 2 and humains[0] == humains[1]:
		humains[1] = (humains[0] + 1) % Pilotes.PILOTES.size()  # pas deux fois le même fruit
	if choix["skate"] and defi.is_empty():
		# Le mode Skate : pas de circuit ni de véhicule, juste le skatepark.
		course = Skate.new()
		course.demo = demo
		course.record = int(Defi.record("Skatepark").get("temps", 0))
		add_child(course)
		course.finie.connect(_montrer_resultats)
		course.demarrer(humains, choix["planches"])
		_jouer(S.MUSIQUE)
		return
	course = Course.new()
	course.demo = demo
	add_child(course)
	course.finie.connect(_montrer_resultats)
	var circuit: Dictionary = Circuits.CIRCUITS[defi["circuit"] if not defi.is_empty() else choix["circuit"]]
	# Un défi peut se jouer dans l'autre mode : on ne garde le véhicule choisi que s'il est dans le garage.
	var en_avion: bool = defi["avions"] if not defi.is_empty() else choix["avions"]
	var vehicules: Array = choix["vehicules"].map(func(v): return v if Magasin.possede(v, en_avion) else 0)
	if defi.is_empty():
		var sorte: String = Modes.EPREUVES[choix["epreuve"]]["cle"]
		if sorte == "chrono":
			# Contre-la-montre : on retrouve le record de ce circuit et son fantôme.
			var ancien: Dictionary = Defi.record(_cle_du_record())
			course.record = float(ancien.get("temps", -1.0))
			course.fantome = ancien.get("trace", [])
		course.demarrer(circuit, humains, vehicules, choix["tours"], en_avion, "", sorte)
	else:
		course.demarrer(circuit, humains, vehicules, defi["tours"], en_avion, defi["regle"]["effet"])
	_jouer(circuit.get("musique", ""))


# Un record par circuit, par mode (kart ou avion) et par nombre de tours.
func _cle_du_record() -> String:
	return "%s / %s / %d tours" % [Circuits.CIRCUITS[choix["circuit"]]["nom"], "avion" if choix["avions"] else "kart", choix["tours"]]


func _montrer_resultats(classement: Array) -> void:
	_jouer(R.MUSIQUE_ARRIVEE)
	resultats = ColorRect.new()
	resultats.color = Color(FOND, 0.8)
	resultats.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(resultats)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	resultats.add_child(centre)
	var titre := "Résultat"
	if defi.has("epreuve"):
		titre = "Défi : " + defi["epreuve"]["nom"]
	elif not defi.is_empty():
		titre = "Défi du jour"
	var carte := _carte(centre, titre)
	carte.custom_minimum_size.x = 440
	_texte(carte, "Classement", 34, TEXTE, true)

	var place := 0
	var joueur := {}
	for i in classement.size():
		var r: Dictionary = classement[i]
		if r["humain"] and place == 0:
			place = i + 1
			joueur = r
			joueur["place"] = place
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 14)
		carte.add_child(ligne)
		var couleur := JAUNE if r["humain"] else TEXTE
		_texte(ligne, "%d" % (i + 1), 22, DISCRET, true).custom_minimum_size.x = 26
		_texte(ligne, r["nom"], 22, couleur, r["humain"]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var detail: String = r.get("detail", "")
		if detail == "" or detail == "gagnant":
			detail = "%.1f s" % r["temps"] if r["temps"] >= 0.0 else "—"
		_texte(ligne, detail, 20, couleur)

	# Les graines : selon la place, et plus pour une course plus longue.
	var graines := 0
	var sorte: String = course.epreuve if course != null else "course"
	if place > 0 and not en_demo and sorte == "skate":
		# Le skate : des graines selon le score, et un record à battre (le meilleur des joueurs).
		var points := int(joueur.get("score", 0))
		graines = mini(S.GRAINES_MAXIMUM, points / S.POINTS_PAR_GRAINE)
		_texte(carte, "Meilleur combo : %d points     Chutes : %d" % [joueur.get("combo", 0), joueur.get("chutes", 0)], 16, DISCRET)
		if points > course.record:
			graines += S.GRAINES_RECORD if course.record > 0 else 0
			Defi.noter_le_record("Skatepark", points, [])
			_texte(carte, "Nouveau record !", 18, JAUNE, true)
		elif course.record > 0:
			_texte(carte, "Ton record : %d points" % course.record, 18, DISCRET, true)
	elif place > 0 and not en_demo and sorte == "chrono":
		# Contre-la-montre : on compare au record, et on garde la course si elle est meilleure.
		if joueur["temps"] >= 0.0:
			graines = R.GRAINES_CHRONO[0]
			var bat_le_record: bool = course.record < 0.0 or joueur["temps"] < course.record
			if bat_le_record:
				graines += R.GRAINES_CHRONO[1] if course.record > 0.0 else 0
				Defi.noter_le_record(_cle_du_record(), joueur["temps"], course.trace)
			_texte(carte, "Nouveau record !" if bat_le_record else "Ton record : %.1f s" % course.record, 18, JAUNE if bat_le_record else DISCRET, true)
	elif place > 0 and not en_demo and sorte == "chasse":
		# Chasse aux graines : on garde ce qu'on a ramassé, plus la prime du classement.
		graines = int(joueur.get("score", 0)) + R.GRAINES_PAR_PLACE[mini(place, R.GRAINES_PAR_PLACE.size()) - 1]
	elif place > 0 and not en_demo and (joueur["temps"] >= 0.0 or sorte != "course"):
		var tours: int = defi["tours"] if not defi.is_empty() else choix["tours"]
		if sorte != "course":
			tours = 3
		graines = int(R.GRAINES_PAR_PLACE[mini(place, R.GRAINES_PAR_PLACE.size()) - 1] * tours / 3.0)

	# Le défi du jour : on gagne une, deux ou trois étoiles.
	if defi.has("epreuve") and place > 0:
		# Un défi du circuit : réussi ou raté.
		var gagne: bool = Defi.reussie(defi["epreuve"], joueur)
		if gagne:
			if not Defi.reussis(Circuits.CIRCUITS[defi["circuit"]]["nom"]).has(defi["epreuve"]["cle"]):
				graines += R.GRAINES_DEFI
			Defi.valider(Circuits.CIRCUITS[defi["circuit"]]["nom"], defi["epreuve"]["cle"])
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 12)
		carte.add_child(ligne)
		_pastilles(ligne, 1 if gagne else 0, 1, JAUNE, 22)
		var verdict := _texte(ligne, "Défi réussi !" if gagne else "Raté. " + defi["epreuve"]["texte"], 16, JAUNE if gagne else DISCRET, true)
		verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		verdict.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif not defi.is_empty() and place > 0:
		var avant: int = Defi.etoiles_du_jour()
		var etoiles := Defi.noter(place)
		graines += R.GRAINES_ETOILE * maxi(0, etoiles - avant)
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 12)
		carte.add_child(ligne)
		_pastilles(ligne, etoiles, 3, JAUNE, 22)
		_texte(ligne, Defis.ETOILES[etoiles - 1] + " : %d étoile%s !" % [etoiles, "s" if etoiles > 1 else ""], 17, JAUNE, true)

	if graines > 0:
		Magasin.gagner(graines)
		_texte(carte, "+ %d graines  (tu en as %d)" % [graines, Magasin.graines()], 18, JAUNE, true)

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
	if capture != "" and essai_derapage == "" and essai_bonus == "" and essai_raccourci == "" and essai_skate == "" and course != null and course.temps > 4.0:
		get_viewport().get_texture().get_image().save_png(capture)
		get_tree().quit()
	if essai_raccourci != "" and course != null and not course.piste.raccourcis.is_empty():
		var kart = course.vues[0]["kart"]
		var raccourci: Dictionary = course.piste.raccourcis[-1 if essai_secret else 0]
		if course.temps >= 0.5 and capture == "":
			capture = "pose"
			var entree: Transform3D = course.piste._repere_de(raccourci["courbe"], raccourci["longueur"] * 0.25)
			kart.placer(0.0, 0.0)
			kart.boule.position = entree.origin + Vector3.UP
			PhysicsServer3D.body_set_state(kart.boule.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.IDENTITY, entree.origin + Vector3.UP))
			kart.cap = atan2(entree.basis.z.x, entree.basis.z.z)
			kart.position_piste = raccourci["de"] + 0.25 * raccourci["remplace"]
			kart.distance = kart.position_piste
			print("raccourci de %.0f m qui remplace %.0f m de route, de %.0f à %.0f" % [raccourci["longueur"], raccourci["remplace"], raccourci["de"], raccourci["de"] + raccourci["remplace"]])
		if course.temps >= essai_trace:
			essai_trace += 0.5
			print("t=%.1f position sur le tour=%.0f distance=%.0f vitesse=%.0f retours=%d touches=%d au_sol=%s raccourci=%s hauteur=%.1f" % [course.temps, kart.position_piste, kart.distance, kart.vitesse, kart.retours, kart.touches, kart.au_sol, kart.sur_raccourci, kart.boule.global_position.y])
		if course.temps > 2.0 and capture == "pose":
			capture = "fait"
			get_viewport().get_texture().get_image().save_png(essai_raccourci)
		if course.temps > 9.0:
			get_tree().quit()
	if essai_skate != "" and course != null:
		if course.temps > 6.0 and capture == "":
			capture = "fait"
			get_viewport().get_texture().get_image().save_png(essai_skate)
		if course.temps > course.duree + 5.0:
			var skateur = course.skateurs[0]
			print("score %d, meilleur combo %d, figures %d, chutes %d" % [skateur.score, skateur.meilleur_combo, skateur.figures, skateur.chutes])
			get_viewport().get_texture().get_image().save_png(essai_skate.replace(".png", "-fin.png"))
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
	course.demarrer(Circuits.CIRCUITS[essai_circuit], [], [], 0, choix["avions"], "", Modes.EPREUVES[choix["epreuve"]]["cle"])
	print("%s : %.0f m par tour, %d tours" % [Circuits.CIRCUITS[essai_circuit]["nom"], course.piste.longueur, course.piste.tours])
	course.finie.connect(func(classement: Array):
		for r in classement:
			print("  %-8s %s" % [r["nom"], ("%.1f s" % r["temps"]) if r["temps"] >= 0.0 else "PAS ARRIVÉ"])
		for kart in course.karts:
			print("  · %-8s retours en piste %d, vitesse max %.0f, hauteur max %.1f" % [kart.pilote["nom"], kart.retours, kart.vitesse_max, kart.hauteur_max])
		essai_circuit += 1
		_simuler.call_deferred())
