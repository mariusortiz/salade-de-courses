# Fabrique l'apparence d'un pilote : un fruit avec des bras et des jambes,
# assis dans son kart. Tout est tourné vers l'avant du kart, c'est-à-dire vers -Z.
extends RefCounted


static func creer(pilote: Dictionary) -> Node3D:
	var chemin: String = pilote.get("modele", "")
	if chemin != "":
		if ResourceLoader.exists(chemin):
			var modele: Node3D = load(chemin).instantiate()
			modele.scale = Vector3.ONE * float(pilote.get("modele_taille", 1.0))
			modele.rotation_degrees.y = float(pilote.get("modele_rotation", 0))
			return modele
		push_warning("Modèle introuvable pour %s : %s. On garde les formes simples." % [pilote["nom"], chemin])

	var kart := Node3D.new()
	_kart(kart, Color(pilote["kart"]))
	_pilote(kart, pilote)
	return kart


# ── Le kart ──────────────────────────────────────────────────

static func _kart(kart: Node3D, couleur: Color) -> void:
	var peinture := _matiere(couleur)
	peinture.metallic = 0.3
	peinture.roughness = 0.3
	var sombre := _matiere(Color("#2b2f3a"))
	var metal := _matiere(Color("#c3c9d4"))
	metal.metallic = 0.9
	metal.roughness = 0.25

	# Le plancher, le nez et les deux pontons sur les côtés.
	_ajouter(kart, _boite(Vector3(1.15, 0.12, 2.6)), sombre, Vector3(0, 0.3, 0))
	var nez := _ajouter(kart, _capsule(0.42, 1.7), peinture, Vector3(0, 0.42, -0.75))
	nez.rotation_degrees.x = 90
	nez.scale = Vector3(1, 1, 0.6)
	for x in [-0.62, 0.62]:
		_ajouter(kart, _capsule(0.26, 1.5), peinture, Vector3(x, 0.42, 0.2)).rotation_degrees.x = 90

	# Les pare-chocs.
	for z in [-1.55, 1.45]:
		_ajouter(kart, _capsule(0.08, 1.7), metal, Vector3(0, 0.32, z)).rotation_degrees.z = 90

	# Le siège, le moteur et ses deux pots d'échappement.
	_ajouter(kart, _boite(Vector3(0.85, 0.8, 0.14)), sombre, Vector3(0, 0.78, 0.82)).rotation_degrees.x = -12
	_ajouter(kart, _boite(Vector3(0.7, 0.4, 0.45)), metal, Vector3(0, 0.52, 1.12))
	for x in [-0.25, 0.25]:
		_membre(kart, Vector3(x, 0.6, 1.25), Vector3(x, 0.85, 1.6), 0.07, sombre)

	# L'aileron.
	_ajouter(kart, _boite(Vector3(1.5, 0.06, 0.38)), peinture, Vector3(0, 1.12, 1.35))
	for x in [-0.5, 0.5]:
		_ajouter(kart, _boite(Vector3(0.06, 0.45, 0.06)), sombre, Vector3(x, 0.9, 1.35))
		_ajouter(kart, _boite(Vector3(0.05, 0.3, 0.42)), peinture, Vector3(x * 1.5, 1.18, 1.35))

	# Le volant.
	_membre(kart, Vector3(0, 0.55, -0.6), Vector3(0, 0.95, -0.25), 0.04, metal)
	var cercle := TorusMesh.new()
	cercle.inner_radius = 0.15
	cercle.outer_radius = 0.22
	_ajouter(kart, cercle, sombre, Vector3(0, 0.97, -0.22)).rotation.x = 0.72

	# Les roues. Celles de devant tournent avec le volant (voir kart.gd).
	var pneu := CylinderMesh.new()
	pneu.top_radius = 0.34
	pneu.bottom_radius = 0.34
	pneu.height = 0.32
	var jante := CylinderMesh.new()
	jante.top_radius = 0.19
	jante.bottom_radius = 0.19
	jante.height = 0.34
	var gomme := _matiere(Color("#1c1c1f"))
	gomme.roughness = 0.9
	var jaune := _matiere(Color("#ffd54f"))
	var roues: Array = []
	var directrices: Array = []
	for z in [-0.95, 0.85]:
		for x in [-0.84, 0.84]:
			var pivot := Node3D.new()
			pivot.position = Vector3(x, 0.34, z)
			kart.add_child(pivot)
			var roue := Node3D.new()
			pivot.add_child(roue)
			_ajouter(roue, pneu, gomme, Vector3.ZERO).rotation_degrees.z = 90
			_ajouter(roue, jante, jaune, Vector3.ZERO).rotation_degrees.z = 90
			_ajouter(roue, _boite(Vector3(0.36, 0.5, 0.09)), metal, Vector3.ZERO)  # pour voir la roue tourner
			roues.append(roue)
			if z < 0.0:
				directrices.append(pivot)
	kart.set_meta("roues", roues)
	kart.set_meta("directrices", directrices)


# ── Le fruit ─────────────────────────────────────────────────

static func _pilote(kart: Node3D, pilote: Dictionary) -> void:
	var couleur := Color(pilote["couleur"])
	var taille: float = pilote.get("taille", 1.0)
	var fruit := Node3D.new()
	fruit.scale = Vector3.ONE * taille
	fruit.position = Vector3(0, 0.55 + 0.65 * taille, 0.3)
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
