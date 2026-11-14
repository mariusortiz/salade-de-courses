# Fabrique l'apparence d'un pilote : un fruit avec des bras et des jambes,
# assis dans son véhicule (un kart, un buggy, un bolide, un tracteur ou une cagette). Tout est tourné vers l'avant du kart, c'est-à-dire vers -Z.
extends RefCounted


static func creer(pilote: Dictionary, vehicule: Dictionary = {}, en_avion := false) -> Node3D:
	var chemin: String = pilote.get("modele", "")
	if chemin != "":
		if ResourceLoader.exists(chemin):
			var modele: Node3D = load(chemin).instantiate()
			modele.scale = Vector3.ONE * float(pilote.get("modele_taille", 1.0))
			modele.rotation_degrees.y = float(pilote.get("modele_rotation", 0))
			return modele
		push_warning("Modèle introuvable pour %s : %s. On garde les formes simples." % [pilote["nom"], chemin])

	var kart := Node3D.new()
	if en_avion:
		_avion(kart, Color(pilote["kart"]), vehicule.get("forme", "kart"))
	else:
		_kart(kart, Color(pilote["kart"]), vehicule.get("forme", "kart"))
	# Sur une planche à roulettes, le fruit est debout, et il n'y a pas de plaque à numéro.
	var debout: bool = not en_avion and vehicule.get("forme", "kart") in ["skate", "longboard"]
	if not debout:
		_plaque(kart, pilote)
	_pilote(kart, pilote, debout)
	return kart


# ── Le kart ──────────────────────────────────────────────────

static func _kart(kart: Node3D, couleur: Color, forme: String) -> void:
	var peinture := _peinture(couleur)   # la peinture brillante, avec de petites paillettes
	var rayee := _carrosserie(couleur)   # la même, avec des bandes de course
	var sombre := _matiere(Color("#2b2f3a"))
	var cuir := _cuir()
	var metal := _metal()
	var bois := _bois()

	# Ce que tous les véhicules ont : le plancher (étroit sur une moto), le siège et le volant.
	var deux_roues := forme in ["moto", "scooter", "moto-cross", "moto-course"]
	# Sur une planche à roulettes, rien de tout ça : le pilote est debout dessus.
	if not forme in ["skate", "longboard"]:
		_ajouter(kart, _boite(Vector3(0.45 if deux_roues else 1.15, 0.12, 2.6)), sombre, Vector3(0, 0.3, 0))
		_ajouter(kart, _boite(Vector3(0.85, 0.8, 0.14)), cuir, Vector3(0, 0.78, 0.82)).rotation_degrees.x = -12
		_membre(kart, Vector3(0, 0.55, -0.6), Vector3(0, 0.95, -0.25), 0.04, metal)
		var cercle := TorusMesh.new()
		cercle.inner_radius = 0.15
		cercle.outer_radius = 0.22
		_ajouter(kart, cercle, sombre, Vector3(0, 0.97, -0.22)).rotation.x = 0.72

	# Les roues : [rayon devant, rayon derrière, épaisseur, écart sur les côtés, z devant, z derrière]
	var roues := [0.34, 0.34, 0.32, 0.84, -0.95, 0.85]
	match forme:
		"buggy":
			roues = [0.5, 0.5, 0.42, 0.98, -1.0, 0.95]
			var nez := _ajouter(kart, _capsule(0.4, 1.3), rayee, Vector3(0, 0.5, -0.8))
			nez.rotation_degrees.x = 90
			nez.scale = Vector3(1, 1, 0.7)
			# L'arceau derrière le siège, avec ses deux phares.
			for x: float in [-0.6, 0.6]:
				_membre(kart, Vector3(x, 0.4, 1.15), Vector3(x * 0.9, 2.5, 0.95), 0.07, metal)
				_membre(kart, Vector3(x * 0.9, 2.5, 0.95), Vector3(x, 0.5, -0.1), 0.06, metal)
				_ajouter(kart, _boule(0.16), _matiere(Color("#fff59d")), Vector3(x * 0.5, 2.62, 0.9))
			_membre(kart, Vector3(-0.54, 2.5, 0.95), Vector3(0.54, 2.5, 0.95), 0.07, metal)
			# La roue de secours et les pare-chocs.
			_ajouter(kart, _roue(0.42, 0.3), _matiere(Color("#1c1c1f")), Vector3(0, 0.95, 1.5)).rotation_degrees.x = 90
			for z in [-1.6, 1.3]:
				_ajouter(kart, _capsule(0.1, 1.9), metal, Vector3(0, 0.45, z)).rotation_degrees.z = 90
		"bolide":
			roues = [0.3, 0.4, 0.42, 0.9, -1.35, 0.9]
			var nez := _ajouter(kart, _capsule(0.36, 2.6), rayee, Vector3(0, 0.4, -1.1))
			nez.rotation_degrees.x = 90
			nez.scale = Vector3(1, 1, 0.55)
			_ajouter(kart, _boite(Vector3(2.1, 0.06, 0.45)), peinture, Vector3(0, 0.2, -2.3))  # l'aileron avant
			for x: float in [-0.6, 0.6]:
				_ajouter(kart, _capsule(0.22, 1.3), rayee, Vector3(x, 0.4, 0.3)).rotation_degrees.x = 90
				_ajouter(kart, _boite(Vector3(0.06, 0.75, 0.5)), sombre, Vector3(x * 1.3, 1.1, 1.5))
			_ajouter(kart, _boite(Vector3(1.7, 0.07, 0.5)), peinture, Vector3(0, 1.5, 1.5))  # le grand aileron arrière
			_ajouter(kart, _capsule(0.3, 1.3), sombre, Vector3(0, 0.75, 1.25)).rotation_degrees.x = 90  # le moteur
		"tracteur":
			roues = [0.3, 0.66, 0.4, 0.95, -1.15, 0.7]
			_ajouter(kart, _boite(Vector3(0.6, 0.5, 1.2)), peinture, Vector3(0, 0.62, -1.15))  # le capot
			_ajouter(kart, _boite(Vector3(0.62, 0.3, 0.06)), sombre, Vector3(0, 0.6, -1.76))  # la calandre
			_membre(kart, Vector3(0.18, 0.85, -1.4), Vector3(0.18, 1.7, -1.4), 0.07, sombre)  # la cheminée
			for x: float in [-0.95, 0.95]:
				_ajouter(kart, _boite(Vector3(0.5, 0.08, 1.5)), peinture, Vector3(x, 1.4, 0.7))  # les garde-boue
			_ajouter(kart, _boite(Vector3(1.0, 0.5, 0.5)), peinture, Vector3(0, 0.6, 1.2))
			_ajouter(kart, _boule(0.14), _matiere(Color("#ffb300")), Vector3(0, 1.3, 1.0))  # le gyrophare
		"skate", "longboard":
			# Une planche arrondie aux deux bouts, quatre petites roues, et le nez qui remonte.
			var long := forme == "longboard"
			roues = [0.2, 0.2, 0.18, 0.55, -1.25, 1.15] if long else [0.16, 0.16, 0.16, 0.5, -0.95, 0.85]
			var plateau := _ajouter(kart, _capsule(0.6, 3.6 if long else 2.9), bois if long else rayee, Vector3(0, 0.42, 0))
			plateau.rotation_degrees.x = 90
			plateau.scale = Vector3(1, 1, 0.1)
			_ajouter(kart, _boite(Vector3(1.0, 0.03, 1.7)), sombre, Vector3(0, 0.49, 0.0))  # l'antidérapant, sous les pieds
			if long:
				_ajouter(kart, _boite(Vector3(0.16, 0.02, 3.0)), peinture, Vector3(0, 0.485, -0.1))  # une bande de couleur
			else:
				var queue := _ajouter(kart, _boite(Vector3(0.95, 0.06, 0.5)), rayee, Vector3(0, 0.52, 1.5))  # l'arrière relevé
				queue.rotation_degrees.x = 22
			for z: float in [roues[4], roues[5]]:
				_ajouter(kart, _boite(Vector3(1.0, 0.1, 0.16)), metal, Vector3(0, roues[0], z))  # l'axe des roues
				_ajouter(kart, _boite(Vector3(0.3, 0.2, 0.3)), metal, Vector3(0, roues[0] + 0.12, z))
		"scooter":
			# Deux petites roues, un grand tablier devant, un plancher plat et un coffre derrière.
			roues = [0.32, 0.32, 0.26, 0.0, -1.3, 1.2]
			_ajouter(kart, _boite(Vector3(0.8, 0.1, 1.3)), peinture, Vector3(0, 0.38, -0.3))  # le plancher
			_ajouter(kart, _boite(Vector3(0.85, 0.95, 0.12)), rayee, Vector3(0, 0.8, -1.0)).rotation_degrees.x = 14  # le tablier
			_ajouter(kart, _boite(Vector3(0.5, 0.1, 0.7)), peinture, Vector3(0, 0.7, -1.3))  # le garde-boue avant
			_membre(kart, Vector3(0, 0.4, -1.25), Vector3(0, 1.4, -0.95), 0.06, metal)  # la colonne du guidon
			_membre(kart, Vector3(-0.5, 1.4, -0.95), Vector3(0.5, 1.4, -0.95), 0.045, sombre)  # le guidon
			_ajouter(kart, _boule(0.16), _matiere(Color("#fff59d")), Vector3(0, 1.15, -1.12))  # le phare
			for x: float in [-0.5, 0.5]:
				_ajouter(kart, _boule(0.09), metal, Vector3(x, 1.55, -0.95))  # les rétroviseurs
			var capot := _ajouter(kart, _capsule(0.38, 1.1), peinture, Vector3(0, 0.6, 0.95))  # la coque arrière
			capot.rotation_degrees.x = 90
			_ajouter(kart, _boite(Vector3(0.6, 0.45, 0.5)), sombre, Vector3(0, 1.2, 1.5))  # le coffre
		"moto-cross":
			# De grandes roues fines, un garde-boue très haut, une plaque à numéro et un pot relevé.
			roues = [0.6, 0.55, 0.22, 0.0, -1.45, 1.3]
			var bidon := _ajouter(kart, _capsule(0.3, 1.0), rayee, Vector3(0, 0.85, -0.5))
			bidon.rotation_degrees.x = 90
			_ajouter(kart, _boite(Vector3(0.45, 0.5, 0.7)), metal, Vector3(0, 0.55, 0.3))  # le moteur
			for x: float in [-0.2, 0.2]:
				_membre(kart, Vector3(x, 0.6, -1.45), Vector3(x, 1.5, -0.8), 0.05, metal)  # la longue fourche
			_membre(kart, Vector3(-0.6, 1.5, -0.78), Vector3(0.6, 1.5, -0.78), 0.045, sombre)  # le guidon large
			_ajouter(kart, _boite(Vector3(0.36, 0.06, 1.0)), peinture, Vector3(0, 1.32, -1.45)).rotation_degrees.x = -12  # le garde-boue haut
			_ajouter(kart, _boite(Vector3(0.5, 0.42, 0.05)), _matiere(Color("#fdf6e3")), Vector3(0, 1.32, -0.98))  # la plaque à numéro
			_ajouter(kart, _boite(Vector3(0.36, 0.06, 1.1)), peinture, Vector3(0, 1.25, 1.35)).rotation_degrees.x = 14  # le garde-boue arrière
			_membre(kart, Vector3(0.28, 0.6, 0.4), Vector3(0.34, 1.15, 1.6), 0.08, metal)  # le pot relevé
		"moto-course":
			# Couchée et carénée : une bulle devant, de gros pneus, un dosseret et deux pots.
			roues = [0.46, 0.5, 0.42, 0.0, -1.35, 1.25]
			var carenage := _ajouter(kart, _capsule(0.5, 1.9), rayee, Vector3(0, 0.62, -0.6))
			carenage.rotation_degrees.x = 90
			carenage.scale = Vector3(0.8, 1, 1)
			var bulle := _ajouter(kart, _boule(0.34), _matiere(Color("#9fd8ff")), Vector3(0, 1.02, -1.0))  # la bulle
			bulle.scale = Vector3(1, 0.8, 1.3)
			_ajouter(kart, _boite(Vector3(0.5, 0.4, 0.8)), metal, Vector3(0, 0.45, 0.4))  # le moteur
			_membre(kart, Vector3(-0.42, 0.95, -0.85), Vector3(0.42, 0.95, -0.85), 0.045, sombre)  # les demi-guidons, très bas
			var dosseret := _ajouter(kart, _capsule(0.3, 1.0), peinture, Vector3(0, 0.95, 1.3))
			dosseret.rotation_degrees.x = 70
			_ajouter(kart, _boite(Vector3(0.9, 0.05, 0.3)), peinture, Vector3(0, 1.3, 1.65))  # le petit aileron
			for x: float in [-0.26, 0.26]:
				_membre(kart, Vector3(x, 0.42, 0.5), Vector3(x * 1.2, 0.7, 1.75), 0.08, metal)  # les deux pots
		"moto":
			# Deux grosses roues l'une derrière l'autre, un réservoir, une fourche, un guidon et un pot.
			roues = [0.5, 0.5, 0.3, 0.0, -1.35, 1.25]
			var reservoir := _ajouter(kart, _capsule(0.36, 1.3), rayee, Vector3(0, 0.62, -0.55))
			reservoir.rotation_degrees.x = 90
			_ajouter(kart, _boite(Vector3(0.5, 0.45, 0.8)), metal, Vector3(0, 0.45, 0.35))  # le moteur
			for x: float in [-0.2, 0.2]:
				_membre(kart, Vector3(x, 0.5, -1.35), Vector3(x, 1.15, -0.85), 0.05, metal)  # la fourche
			_membre(kart, Vector3(-0.55, 1.15, -0.8), Vector3(0.55, 1.15, -0.8), 0.045, sombre)  # le guidon
			_ajouter(kart, _boule(0.17), _matiere(Color("#fff59d")), Vector3(0, 1.0, -1.2))  # le phare
			_ajouter(kart, _boite(Vector3(0.4, 0.08, 0.9)), peinture, Vector3(0, 1.08, 1.25))  # le garde-boue arrière
			_membre(kart, Vector3(0.3, 0.4, 0.5), Vector3(0.36, 0.55, 1.7), 0.08, metal)  # le pot d'échappement
		"cagette":
			roues = [0.3, 0.3, 0.12, 0.8, -0.95, 0.85]
			# Une caisse en bois : deux planches de chaque côté, une devant, une derrière.
			for x: float in [-0.66, 0.66]:
				for y: float in [0.5, 0.82]:
					_ajouter(kart, _boite(Vector3(0.07, 0.26, 2.7)), bois, Vector3(x, y, 0))
			for z: float in [-1.35, 1.35]:
				for y: float in [0.5, 0.82]:
					_ajouter(kart, _boite(Vector3(1.39, 0.26, 0.07)), bois, Vector3(0, y, z))
			_ajouter(kart, _boite(Vector3(1.39, 0.1, 0.09)), peinture, Vector3(0, 0.66, -1.38))  # une bande de couleur
			# Le fanion à l'arrière.
			_membre(kart, Vector3(0.55, 0.9, 1.3), Vector3(0.55, 2.3, 1.3), 0.03, metal)
			_ajouter(kart, _boite(Vector3(0.03, 0.3, 0.5)), peinture, Vector3(0.55, 2.15, 1.55))
		_:
			# Le kart : un nez, deux pontons, les pare-chocs, le moteur, les pots et l'aileron.
			var nez := _ajouter(kart, _capsule(0.42, 1.7), rayee, Vector3(0, 0.42, -0.75))
			nez.rotation_degrees.x = 90
			nez.scale = Vector3(1, 1, 0.6)
			for x in [-0.62, 0.62]:
				_ajouter(kart, _capsule(0.26, 1.5), rayee, Vector3(x, 0.42, 0.2)).rotation_degrees.x = 90
			for z in [-1.55, 1.45]:
				_ajouter(kart, _capsule(0.08, 1.7), metal, Vector3(0, 0.32, z)).rotation_degrees.z = 90
			_ajouter(kart, _boite(Vector3(0.7, 0.4, 0.45)), metal, Vector3(0, 0.52, 1.12))
			for x in [-0.25, 0.25]:
				_membre(kart, Vector3(x, 0.6, 1.25), Vector3(x, 0.85, 1.6), 0.07, sombre)
			_ajouter(kart, _boite(Vector3(1.5, 0.06, 0.38)), peinture, Vector3(0, 1.12, 1.35))
			for x in [-0.5, 0.5]:
				_ajouter(kart, _boite(Vector3(0.06, 0.45, 0.06)), sombre, Vector3(x, 0.9, 1.35))
				_ajouter(kart, _boite(Vector3(0.05, 0.3, 0.42)), peinture, Vector3(x * 1.5, 1.18, 1.35))

	# Les roues tournent, et celles de devant suivent le volant (voir kart.gd).
	var gomme := _pneu()
	var jaune := _matiere(Color("#ffd54f"))
	var tournantes: Array = []
	var directrices: Array = []
	for devant in [true, false]:
		var rayon: float = roues[0] if devant else roues[1]
		for x: float in [-roues[3], roues[3]]:
			var pivot := Node3D.new()
			pivot.position = Vector3(x, rayon, roues[4] if devant else roues[5])
			kart.add_child(pivot)
			var roue := Node3D.new()
			pivot.add_child(roue)
			_ajouter(roue, _roue(rayon, roues[2]), gomme, Vector3.ZERO).rotation_degrees.z = 90
			_ajouter(roue, _roue(rayon * 0.56, roues[2] + 0.02), jaune, Vector3.ZERO).rotation_degrees.z = 90
			_ajouter(roue, _boite(Vector3(roues[2] + 0.04, rayon * 1.5, 0.09)), metal, Vector3.ZERO)  # pour voir la roue tourner
			tournantes.append(roue)
			if devant:
				directrices.append(pivot)
	kart.set_meta("roues", tournantes)
	kart.set_meta("directrices", directrices)


# ── L'avion ──────────────────────────────────────────────────

# Dans le mode Avions, chaque véhicule devient un avion :
# kart = monoplan, buggy = biplan, bolide = jet, tracteur = coucou, cagette = planeur en bois.
static func _avion(avion: Node3D, couleur: Color, forme: String) -> void:
	var peinture := _peinture(couleur)
	var sombre := _matiere(Color("#2b2f3a"))
	var cuir := _cuir()
	var metal := _metal()
	var coque := _bois() if forme == "cagette" else _carrosserie(couleur)

	# Le plancher, le siège et le manche.
	_ajouter(avion, _boite(Vector3(1.15, 0.12, 2.6)), sombre, Vector3(0, 0.3, 0))
	_ajouter(avion, _boite(Vector3(0.85, 0.8, 0.14)), cuir, Vector3(0, 0.78, 0.82)).rotation_degrees.x = -12
	_membre(avion, Vector3(0, 0.55, -0.6), Vector3(0, 0.95, -0.25), 0.04, metal)
	var cercle := TorusMesh.new()
	cercle.inner_radius = 0.15
	cercle.outer_radius = 0.22
	_ajouter(avion, cercle, sombre, Vector3(0, 0.97, -0.22)).rotation.x = 0.72

	# Le nez, les flancs, la queue et ses deux ailerons.
	var nez := _ajouter(avion, _capsule(0.5, 2.3), coque, Vector3(0, 0.5, -1.0))
	nez.rotation_degrees.x = 90
	nez.scale = Vector3(1, 1, 0.8)
	for x: float in [-0.62, 0.62]:
		_ajouter(avion, _capsule(0.3, 2.3), coque, Vector3(x, 0.45, 0.2)).rotation_degrees.x = 90
	_membre(avion, Vector3(0, 0.5, 0.9), Vector3(0, 0.8, 3.0), 0.28, coque)
	_ajouter(avion, _boite(Vector3(0.08, 1.0, 0.7)), peinture, Vector3(0, 1.4, 2.9))
	_ajouter(avion, _boite(Vector3(2.5, 0.07, 0.65)), peinture, Vector3(0, 0.85, 2.9))

	# Les ailes, différentes pour chaque avion.
	var helice := true
	match forme:
		"buggy":
			# Le biplan : deux ailes l'une au-dessus de l'autre.
			for y: float in [0.35, 2.9]:
				_ajouter(avion, _boite(Vector3(6.6, 0.1, 1.2)), peinture, Vector3(0, y, -0.2))
			for x: float in [-2.7, -0.75, 0.75, 2.7]:
				_membre(avion, Vector3(x, 0.4, -0.2), Vector3(x, 2.85, -0.2), 0.05, metal)
		"bolide":
			# Le jet : des ailes en flèche, deux réacteurs, pas d'hélice.
			helice = false
			for cote: float in [-1.0, 1.0]:
				_ajouter(avion, _boite(Vector3(3.6, 0.1, 1.3)), peinture, Vector3(cote * 2.2, 0.4, 0.5)).rotation.y = -cote * 0.45
				_ajouter(avion, _capsule(0.3, 1.6), sombre, Vector3(cote * 1.7, 0.1, 0.5)).rotation_degrees.x = 90
				var flamme := CylinderMesh.new()
				flamme.top_radius = 0.22
				flamme.bottom_radius = 0.0
				flamme.height = 0.9
				var feu := _matiere(Color("#ff9800"))
				feu.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_ajouter(avion, flamme, feu, Vector3(cote * 1.7, 0.1, 1.7)).rotation_degrees.x = 90
		"tracteur":
			# Le coucou : une grosse aile au-dessus de la tête, et des roues.
			_ajouter(avion, _boite(Vector3(6.0, 0.2, 1.7)), peinture, Vector3(0, 2.9, -0.2))
			for x: float in [-0.9, 0.9]:
				_membre(avion, Vector3(x * 0.7, 0.5, -0.5), Vector3(x * 1.6, 2.85, -0.4), 0.06, metal)
				_membre(avion, Vector3(x * 0.7, 0.5, 0.6), Vector3(x * 1.6, 2.85, 0.1), 0.06, metal)
				_membre(avion, Vector3(x * 0.6, 0.3, -0.6), Vector3(x, -0.3, -0.7), 0.06, metal)
				_ajouter(avion, _roue(0.38, 0.25), _matiere(Color("#1c1c1f")), Vector3(x * 1.15, -0.35, -0.7)).rotation_degrees.z = 90
		"moto":
			# La moto volante : deux petites ailes courtes et relevées, et une grande hélice.
			for cote: float in [-1.0, 1.0]:
				_ajouter(avion, _boite(Vector3(2.6, 0.1, 1.1)), peinture, Vector3(cote * 1.7, 0.75, 0.0)).rotation.z = cote * 0.35
				_ajouter(avion, _boite(Vector3(0.1, 0.7, 1.1)), sombre, Vector3(cote * 2.9, 1.45, 0.0))
		"skate", "longboard":
			# La planche volante : une seule grande aile arrondie, comme une planche de surf en travers.
			var envergure := 4.2 if forme == "longboard" else 3.2
			var aile := _ajouter(avion, _boule(1.0), peinture, Vector3(0, 0.35, -0.1))
			aile.scale = Vector3(envergure, 0.07, 0.85)
			for cote: float in [-1.0, 1.0]:
				_ajouter(avion, _boite(Vector3(0.08, 0.5, 0.7)), sombre, Vector3(cote * (envergure - 0.5), 0.6, 0.0))
		"scooter":
			# Le scooter volant : deux ailes toutes rondes, comme des pétales.
			for cote: float in [-1.0, 1.0]:
				var petale := _ajouter(avion, _boule(1.0), peinture, Vector3(cote * 1.9, 0.6, 0.0))
				petale.scale = Vector3(1.5, 0.08, 0.9)
				_ajouter(avion, _boule(0.2), _matiere(Color("#fff59d")), Vector3(cote * 3.3, 0.6, 0.0))
		"moto-cross":
			# La moto des nuages : deux paires d'ailes courtes, une en bas et une en haut.
			for cote: float in [-1.0, 1.0]:
				for y: float in [0.4, 2.0]:
					_ajouter(avion, _boite(Vector3(2.4, 0.1, 1.0)), peinture, Vector3(cote * 1.7, y, -0.1))
				_membre(avion, Vector3(cote * 2.5, 0.4, -0.1), Vector3(cote * 2.5, 2.0, -0.1), 0.05, metal)
				_membre(avion, Vector3(cote * 0.6, 0.6, -0.1), Vector3(cote * 0.9, 2.0, -0.1), 0.05, metal)
		"moto-course":
			# La moto fusée : des ailes en flèche et une tuyère qui brille, pas d'hélice.
			helice = false
			for cote: float in [-1.0, 1.0]:
				_ajouter(avion, _boite(Vector3(3.0, 0.1, 1.3)), peinture, Vector3(cote * 1.8, 0.45, 0.5)).rotation.y = cote * 0.6
				_ajouter(avion, _boite(Vector3(0.1, 0.6, 0.9)), sombre, Vector3(cote * 3.0, 0.7, 1.35))
			_ajouter(avion, _roue(0.34, 0.5), metal, Vector3(0, 0.8, 3.2)).rotation_degrees.x = 90
			_ajouter(avion, _boule(0.26), _matiere(Color("#ffb300")), Vector3(0, 0.8, 3.45))
		"cagette":
			# Le planeur en bois : de très longues ailes fines, pas d'hélice.
			helice = false
			_ajouter(avion, _boite(Vector3(10.0, 0.08, 1.0)), coque, Vector3(0, 0.45, -0.1))
			for x: float in [-4.9, 4.9]:
				_ajouter(avion, _boite(Vector3(0.2, 0.1, 1.05)), peinture, Vector3(x, 0.47, -0.1))
		_:
			# Le monoplan : une seule aile.
			_ajouter(avion, _boite(Vector3(7.6, 0.1, 1.35)), peinture, Vector3(0, 0.4, -0.1))
			for x: float in [-3.6, 3.6]:
				_ajouter(avion, _boite(Vector3(0.5, 0.12, 1.4)), sombre, Vector3(x, 0.4, -0.1))

	# L'hélice tourne (voir avion.gd).
	if helice:
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0.5, -2.25)
		avion.add_child(pivot)
		_ajouter(pivot, _boite(Vector3(0.16, 2.0, 0.05)), sombre, Vector3.ZERO)
		_ajouter(pivot, _boite(Vector3(2.0, 0.16, 0.05)), sombre, Vector3.ZERO)
		_ajouter(pivot, _boule(0.22), metal, Vector3.ZERO)
		avion.set_meta("helices", [pivot])


static func _roue(rayon: float, epaisseur: float) -> CylinderMesh:
	var roue := CylinderMesh.new()
	roue.top_radius = rayon
	roue.bottom_radius = rayon
	roue.height = epaisseur
	return roue


# ── Le fruit ─────────────────────────────────────────────────

static func _pilote(kart: Node3D, pilote: Dictionary, debout := false) -> void:
	var couleur := Color(pilote["couleur"])
	var taille: float = pilote.get("taille", 1.0)
	var fruit := Node3D.new()
	fruit.scale = Vector3.ONE * taille
	fruit.position = Vector3(0, 0.55 + 0.65 * taille, 0.3)
	if debout:
		fruit.position = Vector3(0, 1.2 + 0.65 * taille, 0.0)
	kart.add_child(fruit)

	var peau := _peau(couleur, pilote.get("motif", "uni"))
	# « visage » : où poser les yeux. « haut » : où poser la tige. « large » : où attacher les bras.
	var visage := Vector3(0, 0.15, -0.6)
	var haut := 0.62
	var large := 0.58
	match pilote.get("forme", "ronde"):
		"longue":
			var points: Array = []
			for i in 6:
				var t := i / 5.0
				points.append(Vector3(0, -0.6 + 1.5 * t, 0.1 - 0.4 * t * t))
			for i in 5:
				_membre(fruit, points[i], points[i + 1], 0.3, peau)
			_ajouter(fruit, _boule(0.13), _matiere(Color("#5d4037")), points[0] + Vector3(0, -0.3, 0))
			visage = Vector3(0, 0.3, -0.34)
			haut = 1.2
			large = 0.28
		"pointue":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.65
			cone.bottom_radius = 0.08
			cone.height = 1.2
			_ajouter(fruit, cone, peau, Vector3(0, -0.05, 0))
			_ajouter(fruit, _boule(0.65), peau, Vector3(0, 0.55, 0)).scale = Vector3(1, 0.4, 1)
			var feuille := _matiere(Color("#43a047"))
			for i in 6:
				var angle := i * TAU / 6.0
				var f := _ajouter(fruit, _boule(0.22), feuille, Vector3(cos(angle) * 0.3, 0.8, sin(angle) * 0.3))
				f.scale = Vector3(1.3, 0.25, 0.7)
				f.rotation.y = -angle
			visage = Vector3(0, 0.2, -0.56)
			haut = 0.8
			large = 0.5
		"grappe":
			var etages := [[5, 0.4, 0.45], [6, 0.44, 0.1], [4, 0.32, -0.25], [1, 0.0, -0.55]]
			for e in etages:
				for i in e[0]:
					var angle: float = i * TAU / e[0] + e[2]
					_ajouter(fruit, _boule(0.32), peau, Vector3(cos(angle) * e[1], e[2], sin(angle) * e[1]))
			_ajouter(fruit, _boule(0.4), peau, Vector3(0, 0.2, 0))
			_ajouter(fruit, _boule(0.3), peau, Vector3(0, 0.15, -0.42))  # le grain qui porte le visage
			visage = Vector3(0, 0.15, -0.68)
			haut = 0.7
		"poire":
			_ajouter(fruit, _boule(0.62), peau, Vector3(0, -0.1, 0))
			_ajouter(fruit, _boule(0.42), peau, Vector3(0, 0.55, 0))
			visage = Vector3(0, 0.0, -0.58)
			haut = 0.95
		_:
			_ajouter(fruit, _boule(0.65), peau, Vector3.ZERO).scale = Vector3(1, 0.94, 1)

	# La tige et la feuille.
	_ajouter(fruit, _boite(Vector3(0.08, 0.3, 0.08)), _matiere(Color("#6d4c2f")), Vector3(0, haut + 0.1, 0))
	_ajouter(fruit, _boule(0.2), _matiere(Color("#43a047")), Vector3(0.2, haut + 0.18, 0)).scale = Vector3(1.4, 0.3, 0.8)

	# Le visage : deux yeux, deux joues roses et un sourire.
	var blanc := _matiere(Color.WHITE)
	var noir := _matiere(Color("#1d1d1d"))
	var rose := _matiere(Color("#ff8a80"))
	for x in [-0.2, 0.2]:
		_ajouter(fruit, _boule(0.15), blanc, visage + Vector3(x, 0.1, 0.02)).scale = Vector3(1, 1.2, 0.6)
		_ajouter(fruit, _boule(0.075), noir, visage + Vector3(x * 0.9, 0.08, -0.06))
		_ajouter(fruit, _boule(0.03), blanc, visage + Vector3(x * 0.9 + 0.03, 0.12, -0.12))
		_ajouter(fruit, _boule(0.09), rose, visage + Vector3(x * 1.8, -0.1, 0.06)).scale = Vector3(1, 0.7, 0.4)
	var sourire := [Vector3(-0.15, -0.12, 0), Vector3(-0.07, -0.19, -0.02), Vector3(0.07, -0.19, -0.02), Vector3(0.15, -0.12, 0)]
	for i in 3:
		_membre(fruit, visage + sourire[i], visage + sourire[i + 1], 0.025, noir)

	# Les bras tiennent le volant, les jambes sont allongées vers les pédales.
	var membre := _matiere(couleur.darkened(0.3))
	var chaussure := _matiere(Color(pilote["kart"]).lightened(0.2))
	var centre := fruit.position
	if debout:
		# Debout sur la planche : les bras écartés pour garder l'équilibre, un pied devant, un pied derrière.
		for cote: float in [-1.0, 1.0]:
			var epaule := centre + Vector3(cote * large, 0.05, 0.0) * taille
			var main := epaule + Vector3(cote * 0.75, 0.2, -0.1 * cote)
			_membre(kart, epaule, (epaule + main) / 2.0 + Vector3(0, -0.12, 0), 0.07, membre)
			_membre(kart, (epaule + main) / 2.0 + Vector3(0, -0.12, 0), main, 0.07, membre)
			_ajouter(kart, _boule(0.12), blanc, main)  # le gant
			var hanche := centre + Vector3(cote * 0.25, -0.5, cote * 0.1) * taille
			var pied := Vector3(cote * 0.12, 0.6, cote * 0.6)
			var genou := (hanche + pied) / 2.0 + Vector3(cote * 0.12, 0, cote * 0.08)
			_membre(kart, hanche, genou, 0.08, membre)
			_membre(kart, genou, pied, 0.08, membre)
			_ajouter(kart, _boule(0.15), chaussure, pied + Vector3(0, 0.02, 0)).scale = Vector3(1.5, 0.9, 0.9)
		return
	for cote: float in [-1.0, 1.0]:
		var epaule := centre + Vector3(cote * large, 0.05, -0.15) * taille
		var main := Vector3(cote * 0.2, 0.99, -0.26)
		var coude := (epaule + main) / 2.0 + Vector3(cote * 0.18, -0.15, 0)
		_membre(kart, epaule, coude, 0.07, membre)
		_membre(kart, coude, main, 0.07, membre)
		_ajouter(kart, _boule(0.12), blanc, main)  # le gant

		var hanche := centre + Vector3(cote * 0.3, -0.45, -0.25) * taille
		var genou := Vector3(cote * 0.45, 0.82, -0.4)
		var pied := Vector3(cote * 0.47, 0.62, -1.0)
		_membre(kart, hanche, genou, 0.08, membre)
		_membre(kart, genou, pied, 0.08, membre)
		_ajouter(kart, _boule(0.15), chaussure, pied + Vector3(0, 0.04, -0.08)).scale = Vector3(0.9, 0.9, 1.5)


# La peau du fruit : une couleur, avec des rayures ou des petits points si on veut.
static func _peau(couleur: Color, motif: String) -> StandardMaterial3D:
	var matiere := StandardMaterial3D.new()
	matiere.roughness = 0.4
	if motif != "rayures" and motif != "points":
		matiere.albedo_color = couleur
		return matiere
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	image.fill(couleur)
	if motif == "rayures":
		for y in 64:
			for x in 64:
				if int(x + 3.0 * sin(y * TAU / 16.0)) % 16 < 7:
					image.set_pixel(x, y, couleur.darkened(0.45))
		matiere.uv1_scale = Vector3(3, 1, 1)
	else:
		for centre in [Vector2(16, 16), Vector2(48, 48)]:
			for y in 64:
				for x in 64:
					if Vector2(x, y).distance_to(centre) < 5.0:
						image.set_pixel(x, y, Color("#ffe082"))
		matiere.uv1_scale = Vector3(8, 5, 1)
	image.generate_mipmaps()
	matiere.albedo_texture = ImageTexture.create_from_image(image)
	return matiere


# ── Les matières des véhicules ───────────────────────────────

static var textures := {}  # les textures sont dessinées une seule fois, puis gardées


# Dessine une texture point par point. « pinceau » reçoit x, y (de 0 à 1) et un grain
# au hasard (de 0 à 1), et répond la couleur du point.
static func _dessiner(cle: String, cote: int, grain: float, pinceau: Callable) -> ImageTexture:
	if textures.has(cle):
		return textures[cle]
	var bruit := FastNoiseLite.new()
	bruit.frequency = grain
	var taches: Image = bruit.get_seamless_image(cote, cote)
	var image := Image.create(cote, cote, false, Image.FORMAT_RGB8)
	for y in cote:
		for x in cote:
			image.set_pixel(x, y, pinceau.call(float(x) / cote, float(y) / cote, taches.get_pixel(x, y).r))
	image.generate_mipmaps()
	textures[cle] = ImageTexture.create_from_image(image)
	return textures[cle]


static func _texturee(texture: Texture2D, metal: float, rugosite: float, partout := 0.0) -> StandardMaterial3D:
	var matiere := StandardMaterial3D.new()
	matiere.albedo_texture = texture
	matiere.metallic = metal
	matiere.roughness = rugosite
	matiere.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if partout > 0.0:
		# La texture est plaquée de tous les côtés, à la même taille partout.
		matiere.uv1_triplanar = true
		matiere.uv1_scale = Vector3.ONE * partout
	return matiere


# La peinture : brillante, avec de petites paillettes.
static func _peinture(couleur: Color) -> StandardMaterial3D:
	var texture := _dessiner("peinture" + couleur.to_html(), 64, 0.35, func(_x: float, _y: float, g: float) -> Color:
		return couleur.darkened(0.12).lerp(couleur.lightened(0.1), g))
	return _texturee(texture, 0.45, 0.22, 1.5)


# La carrosserie : la même peinture, avec deux bandes blanches de chaque côté et des lignes de tôle.
static func _carrosserie(couleur: Color) -> StandardMaterial3D:
	var texture := _dessiner("carrosserie" + couleur.to_html(), 128, 0.35, func(x: float, y: float, g: float) -> Color:
		var bande := absf(fposmod(x, 0.5) - 0.25)  # 0 au milieu d'une bande
		if bande > 0.012 and bande < 0.045:
			return Color("#f7f7f7").darkened(0.06 * g)
		if absf(fposmod(x + 0.25, 0.5) - 0.25) < 0.006 or absf(fposmod(y, 0.34) - 0.17) < 0.006:
			return couleur.darkened(0.45)
		return couleur.darkened(0.12).lerp(couleur.lightened(0.1), g))
	return _texturee(texture, 0.45, 0.22)


# Les pneus : du caoutchouc avec des rainures en biais.
static func _pneu() -> StandardMaterial3D:
	var texture := _dessiner("pneu", 64, 0.3, func(x: float, y: float, g: float) -> Color:
		var rainure := fposmod(x * 4.0 + absf(y * 4.0 - 1.0), 0.5) < 0.16
		return Color("#0c0c0e") if rainure else Color("#26262b").darkened(0.2 * g))
	var matiere := _texturee(texture, 0.0, 0.95)
	matiere.uv1_scale = Vector3(6, 1, 1)
	return matiere


# Le métal brossé.
static func _metal() -> StandardMaterial3D:
	var texture := _dessiner("metal", 64, 0.08, func(_x: float, y: float, g: float) -> Color:
		return Color("#aab1bd").lerp(Color("#dfe4ec"), fposmod(g * 3.0 + y * 13.0, 1.0)))
	return _texturee(texture, 0.9, 0.3, 2.0)


# Le cuir du siège, avec ses coutures en losange.
static func _cuir() -> StandardMaterial3D:
	var texture := _dessiner("cuir", 64, 0.4, func(x: float, y: float, g: float) -> Color:
		var couture := absf(fposmod(x + y, 0.5) - 0.25) < 0.02 or absf(fposmod(x - y, 0.5) - 0.25) < 0.02
		return Color("#59607a") if couture else Color("#262a36").lightened(0.06 * g))
	return _texturee(texture, 0.0, 0.6, 2.0)


# Le bois : des planches, avec leurs veines.
static func _bois() -> StandardMaterial3D:
	var texture := _dessiner("bois", 64, 0.06, func(_x: float, y: float, g: float) -> Color:
		if fposmod(y, 0.5) < 0.04:
			return Color("#6d4423")
		return Color("#b97e45").lerp(Color("#d8a366"), fposmod(g * 6.0, 1.0)))
	return _texturee(texture, 0.0, 0.8, 1.2)


# La plaque avec le numéro du pilote, au dos du siège.
static func _plaque(kart: Node3D, pilote: Dictionary) -> void:
	var blanc := _matiere(Color("#f7f7f7"))
	var plaque := _ajouter(kart, _boite(Vector3(0.62, 0.46, 0.03)), blanc, Vector3(0, 0.92, 0.93))
	plaque.rotation_degrees.x = -12
	var numero := Label3D.new()
	numero.text = str(int(pilote.get("numero", absi(str(pilote["nom"]).hash()) % 98 + 1)))
	numero.font_size = 96
	numero.pixel_size = 0.004
	numero.modulate = Color("#1d2433")
	numero.outline_size = 0
	numero.position = Vector3(0, 0, 0.02)
	plaque.add_child(numero)


# ── Les outils ───────────────────────────────────────────────

static func _ajouter(parent: Node3D, forme: Mesh, matiere: Material, ou: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = forme
	m.material_override = matiere
	m.position = ou
	parent.add_child(m)
	return m


# Un tube arrondi qui va du point a au point b : un bras, une jambe, un tuyau.
static func _membre(parent: Node3D, a: Vector3, b: Vector3, rayon: float, matiere: Material) -> MeshInstance3D:
	var m := _ajouter(parent, _capsule(rayon, a.distance_to(b) + rayon * 2.0), matiere, (a + b) / 2.0)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.UP).normalized()
	m.basis = Basis(x, y, x.cross(y))
	return m


static func _boite(taille: Vector3) -> BoxMesh:
	var boite := BoxMesh.new()
	boite.size = taille
	return boite


static func _capsule(rayon: float, hauteur: float) -> CapsuleMesh:
	var capsule := CapsuleMesh.new()
	capsule.radius = rayon
	capsule.height = hauteur
	capsule.radial_segments = 16
	capsule.rings = 4
	return capsule


static func _boule(rayon: float) -> SphereMesh:
	var boule := SphereMesh.new()
	boule.radius = rayon
	boule.height = rayon * 2.0
	boule.radial_segments = 20
	boule.rings = 10
	return boule


static func _matiere(couleur: Color) -> StandardMaterial3D:
	var matiere := StandardMaterial3D.new()
	matiere.albedo_color = couleur
	return matiere
