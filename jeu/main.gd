# Le chef d'orchestre : le menu, le lancement d'une course, le classement.
extends Node

const R = preload("res://donnees/reglages.gd")
const Circuits = preload("res://donnees/circuits.gd")
const Pilotes = preload("res://donnees/pilotes.gd")
const Course = preload("res://jeu/course.gd")

const ENCRE := Color("#1d2433")

var choix := {"joueurs": 1, "pilotes": [0, 1], "circuit": 0}
var menu: Control
var resultats: Control
var course: Node

# Pour les essais automatiques (voir le README, partie « Vérifier »).
var essai_circuit := -1
var capture := ""


func _ready() -> void:
	get_window().title = R.TITRE
	for option in OS.get_cmdline_user_args():
		if option == "--simulation":
			essai_circuit = 0
		elif option.begins_with("--capture="):
			capture = option.trim_prefix("--capture=")
		elif option.begins_with("--circuit="):
			choix["circuit"] = int(option.trim_prefix("--circuit="))
		elif option.begins_with("--joueurs="):
			choix["joueurs"] = int(option.trim_prefix("--joueurs="))
	if essai_circuit >= 0:
		_simuler()
	elif capture != "":
		_lancer(true)
	else:
		_montrer_menu()


# ── Le menu ──────────────────────────────────────────────────

func _montrer_menu() -> void:
	_nettoyer()
	menu = ColorRect.new()
	menu.color = Color("#a6dcf5")
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(centre)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 12)
	centre.add_child(colonne)

	_titre(colonne, R.TITRE, 64)
	_titre(colonne, "Combien de joueurs ?", 22)
	_rangee(colonne, ["1 joueur", "2 joueurs"], choix["joueurs"] - 1, func(i): choix["joueurs"] = i + 1)

	var noms: Array = Pilotes.PILOTES.map(func(p): return p["nom"])
	var couleurs: Array = Pilotes.PILOTES.map(func(p): return Color(p["couleur"]))
	for j in choix["joueurs"]:
		_titre(colonne, "Joueur %d" % (j + 1), 22)
		_rangee(colonne, noms, choix["pilotes"][j], func(i): choix["pilotes"][j] = i, couleurs)

	_titre(colonne, "Circuit", 22)
	_rangee(colonne, Circuits.CIRCUITS.map(func(c): return c["nom"]), choix["circuit"], func(i): choix["circuit"] = i)

	var demarrer := _bouton("Démarrer", Color("#ff7043"), ENCRE, 34)
	demarrer.add_theme_color_override("font_color", Color.WHITE)
	demarrer.add_theme_color_override("font_hover_color", Color.WHITE)
	demarrer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	demarrer.pressed.connect(func(): _lancer(false))
	colonne.add_child(demarrer)
	demarrer.grab_focus()

	var aide := "Joueur 1 : les flèches. Joueur 2 : Z Q S D." if choix["joueurs"] == 2 else "Pour conduire : les flèches ou Z Q S D. Une manette marche aussi."
	_titre(colonne, aide, 18)


func _titre(parent: Control, texte: String, taille: int) -> void:
	var titre := Label.new()
	titre.text = texte
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", taille)
	titre.add_theme_color_override("font_color", ENCRE)
	parent.add_child(titre)


func _rangee(parent: Control, noms: Array, actif: int, au_clic: Callable, bords: Array = []) -> void:
	var rangee := HBoxContainer.new()
	rangee.alignment = BoxContainer.ALIGNMENT_CENTER
	rangee.add_theme_constant_override("separation", 10)
	parent.add_child(rangee)
	for i in noms.size():
		var fond := Color("#ffd54f") if i == actif else Color.WHITE
		var bouton := _bouton(noms[i], fond, bords[i] if not bords.is_empty() else ENCRE, 22)
		bouton.pressed.connect(func():
			au_clic.call(i)
			_montrer_menu())
		rangee.add_child(bouton)


func _bouton(texte: String, fond: Color, bord: Color, taille: int) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.add_theme_font_size_override("font_size", taille)
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.border_color = bord
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)
	style.content_margin_left = 22
	style.content_margin_right = 22
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
	course.demarrer(Circuits.CIRCUITS[choix["circuit"]], humains)


func _montrer_resultats(classement: Array) -> void:
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
	if capture != "" and course != null and course.temps > 4.0:
		get_viewport().get_texture().get_image().save_png(capture)
		get_tree().quit()


# Fait courir les ordinateurs seuls sur chaque circuit et écrit le résultat.
func _simuler() -> void:
	_nettoyer()
	if essai_circuit >= Circuits.CIRCUITS.size():
		get_tree().quit()
		return
	course = Course.new()
	add_child(course)
	course.demarrer(Circuits.CIRCUITS[essai_circuit], [])
	print("%s : %.0f m par tour, %d tours" % [Circuits.CIRCUITS[essai_circuit]["nom"], course.piste.longueur, course.piste.tours])
	course.finie.connect(func(classement: Array):
		for r in classement:
			print("  %-8s %s" % [r["nom"], ("%.1f s" % r["temps"]) if r["temps"] >= 0.0 else "PAS ARRIVÉ"])
		for kart in course.karts:
			print("  · %-8s retours en piste %d, vitesse max %.0f, hauteur max %.1f" % [kart.pilote["nom"], kart.retours, kart.vitesse_max, kart.hauteur_max])
		essai_circuit += 1
		_simuler.call_deferred())
