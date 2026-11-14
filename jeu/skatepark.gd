# Fabrique le skatepark du mode Skate à partir de donnees/skate.gd.
# Le sol est un relief : pour chaque endroit (x, z) on sait calculer sa hauteur.
# Le dessin et les skateurs se servent du même calcul, donc ce qu'on voit est ce sur quoi on roule.
extends Node3D

const S = preload("res://donnees/skate.gd")

const PAS := 0.5             # la taille des carreaux du sol, en mètres
const ANGLE_DES_BORDS := 1.2 # jusqu'où les rampes du tour se redressent (en radians, 1,2 = presque debout)

var demi := Vector2.ZERO  # la moitié de la largeur et de la profondeur : au-delà, c'est le mur
var course_des_bords := 0.0  # la longueur au sol des rampes du tour
var barres: Array = []    # les barres : {a, b} les deux bouts (en haut de la barre), longueur
var modules: Array = []   # les modules, avec leur angle déjà calculé


func construire() -> void:
	demi = Vector2(S.LARGEUR, S.PROFONDEUR) / 2.0
	course_des_bords = S.RAYON_DES_BORDS * sin(ANGLE_DES_BORDS)
	for m in S.MODULES:
		var module: Dictionary = m.duplicate()
		if module["sorte"] == "tremplin":
			var angle := deg_to_rad(float(module["angle"]))
			module["avant"] = Vector2(cos(angle), sin(angle))
		modules.append(module)
	_ciel_et_lumiere()
	_sol()
	_murs()
	for module in modules:
		if module["sorte"] == "barre":
			_barre(module)
	_alentours()


# ── Le relief ────────────────────────────────────────────────

# La hauteur du sol à cet endroit.
func hauteur(x: float, z: float) -> float:
	var h := 0.0
	# Les rampes du tour : plus on est près du mur, plus ça monte.
	var bord := minf(demi.x - absf(x), demi.y - absf(z))
	if bord < course_des_bords:
		var u := minf(course_des_bords, course_des_bords - bord)
		h = S.RAYON_DES_BORDS * (1.0 - cos(asin(u / S.RAYON_DES_BORDS)))
	for module in modules:
		h = maxf(h, _hauteur_du_module(module, x, z))
	return h


func _hauteur_du_module(module: Dictionary, x: float, z: float) -> float:
	match module["sorte"]:
		"pyramide":
			var du: float = module["longueur"] / 2.0 - absf(x - module["x"])
			var dv: float = module["largeur"] / 2.0 - absf(z - module["z"])
			if du <= 0.0 or dv <= 0.0:
				return 0.0
			return module["hauteur"] * clampf(minf(du, dv) / module["pente"], 0.0, 1.0)
		"tremplin":
			var avant: Vector2 = module["avant"]
			var p := Vector2(x - module["x"], z - module["z"])
			var u := p.dot(avant)
			var v := p.dot(Vector2(-avant.y, avant.x))
			if u < 0.0 or u > module["longueur"] or absf(v) > module["largeur"] / 2.0:
				return 0.0
			return module["hauteur"] * pow(u / module["longueur"], 2.0)
		"bosse":
			var r := Vector2(x - module["x"], z - module["z"]).length()
			if r >= module["rayon"]:
				return 0.0
			return module["hauteur"] * 0.5 * (1.0 + cos(PI * r / module["rayon"]))
	return 0.0


# La direction « vers le haut » du sol à cet endroit (penchée sur une rampe).
func normale(x: float, z: float) -> Vector3:
	var e := 0.25
	var pente_x := (hauteur(x + e, z) - hauteur(x - e, z)) / (2.0 * e)
	var pente_z := (hauteur(x, z + e) - hauteur(x, z - e)) / (2.0 * e)
	return Vector3(-clampf(pente_x, -3.0, 3.0), 1.0, -clampf(pente_z, -3.0, 3.0)).normalized()


# Est-on encore à l'intérieur du skatepark ?
func dedans(x: float, z: float) -> bool:
	return absf(x) <= demi.x and absf(z) <= demi.y


# ── Le dessin ────────────────────────────────────────────────

func _couleur(x: float, z: float, h: float) -> Color:
	var bord := minf(demi.x - absf(x), demi.y - absf(z))
	if bord < course_des_bords:
		return Color(S.COULEUR_BORDS[int(floor((x + z) / 3.0)) & 1])
	if h > 0.03:
		for module in modules:
			if _hauteur_du_module(module, x, z) >= h - 0.01:
				match module["sorte"]:
					"pyramide":
						return Color(S.COULEUR_PYRAMIDE).darkened(0.0 if h >= module["hauteur"] - 0.02 else 0.12)
					"tremplin":
						return Color(S.COULEUR_TREMPLIN)
					"bosse":
						return Color(S.COULEUR_BOSSE)
	return Color(S.COULEUR_SOL[(int(floor(x / 4.0)) + int(floor(z / 4.0))) & 1])


func _sol() -> void:
	var colonnes := int(S.LARGEUR / PAS) + 1
	var lignes := int(S.PROFONDEUR / PAS) + 1
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var couleurs := PackedColorArray()
	var triangles := PackedInt32Array()
	for j in lignes:
		for i in colonnes:
			var x := -demi.x + i * PAS
			var z := -demi.y + j * PAS
			var h := hauteur(x, z)
			sommets.append(Vector3(x, h, z))
			normales.append(normale(x, z))
			couleurs.append(_couleur(x, z, h))
	for j in lignes - 1:
		for i in colonnes - 1:
			var a := j * colonnes + i
			triangles.append_array([a, a + 1, a + colonnes, a + 1, a + colonnes + 1, a + colonnes])
	var tableaux := []
	tableaux.resize(Mesh.ARRAY_MAX)
	tableaux[Mesh.ARRAY_VERTEX] = sommets
	tableaux[Mesh.ARRAY_NORMAL] = normales
	tableaux[Mesh.ARRAY_COLOR] = couleurs
	tableaux[Mesh.ARRAY_INDEX] = triangles
	var maillage := ArrayMesh.new()
	maillage.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
	var beton := StandardMaterial3D.new()
	beton.vertex_color_use_as_albedo = true
	beton.roughness = 0.85
	beton.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sol := MeshInstance3D.new()
	sol.mesh = maillage
	sol.material_override = beton
	add_child(sol)

	# L'herbe autour du skatepark.
	var pre := PlaneMesh.new()
	pre.size = Vector2(900, 900)
	_objet(pre, _matiere(Color("#4f9a3d")), Vector3(0, -0.05, 0))


# Le mur tout autour, en panneaux de couleur.
func _murs() -> void:
	var haut := hauteur(demi.x, 0.0) + 2.2
	var panneau := 6.0
	var numero := 0
	for cote in 4:
		var long: float = S.LARGEUR if cote < 2 else S.PROFONDEUR
		var nombre := int(ceil(long / panneau))
		for k in nombre:
			var le_long: float = -long / 2.0 + (k + 0.5) * long / nombre
			var boite := BoxMesh.new()
			var ou := Vector3.ZERO
			if cote < 2:
				boite.size = Vector3(long / nombre, haut, 0.6)
				ou = Vector3(le_long, haut / 2.0, (demi.y + 0.3) * (1.0 if cote == 0 else -1.0))
			else:
				boite.size = Vector3(0.6, haut, long / nombre)
				ou = Vector3((demi.x + 0.3) * (1.0 if cote == 2 else -1.0), haut / 2.0, le_long)
			_objet(boite, _matiere(Color(S.COULEUR_MURS[numero % S.COULEUR_MURS.size()])), ou)
			numero += 1


func _barre(module: Dictionary) -> void:
	var de: Vector2 = module["de"]
	var vers: Vector2 = module["a"]
	var a := Vector3(de.x, hauteur(de.x, de.y) + module["hauteur"], de.y)
	var b := Vector3(vers.x, hauteur(vers.x, vers.y) + module["hauteur"], vers.y)
	barres.append({"a": a, "b": b, "longueur": a.distance_to(b)})
	var acier := _matiere(Color(S.COULEUR_BARRES))
	acier.metallic = 0.8
	acier.roughness = 0.3
	var tube := CylinderMesh.new()
	tube.top_radius = 0.09
	tube.bottom_radius = 0.09
	tube.height = a.distance_to(b)
	var barre := _objet(tube, acier, (a + b) / 2.0)
	barre.look_at_from_position((a + b) / 2.0, b, Vector3.UP)
	barre.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	# Les pieds de la barre.
	var pieds := maxi(2, int(a.distance_to(b) / 5.0) + 1)
	for k in pieds:
		var p := a.lerp(b, (k + 0.15) / (pieds - 0.7))
		var pied := CylinderMesh.new()
		pied.top_radius = 0.07
		pied.bottom_radius = 0.07
		pied.height = module["hauteur"]
		_objet(pied, acier, Vector3(p.x, p.y - module["hauteur"] / 2.0, p.z))


# Quelques arbres et des lampadaires derrière les murs, pour ne pas rouler dans le vide.
func _alentours() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 11
	var tronc := _matiere(Color("#8d6e63"))
	var feuilles := [_matiere(Color("#43a047")), _matiere(Color("#2e7d32")), _matiere(Color("#7cb342"))]
	for k in 46:
		var angle := k * TAU / 46.0 + hasard.randf_range(-0.05, 0.05)
		var loin := hasard.randf_range(10.0, 34.0)
		var ou := Vector3(cos(angle) * (demi.x + loin), 0, sin(angle) * (demi.y + loin))
		var taille := hasard.randf_range(0.8, 1.5)
		var fut := CylinderMesh.new()
		fut.top_radius = 0.35 * taille
		fut.bottom_radius = 0.5 * taille
		fut.height = 3.0 * taille
		_objet(fut, tronc, ou + Vector3.UP * 1.5 * taille)
		var boule := SphereMesh.new()
		boule.radius = 2.4 * taille
		boule.height = 4.2 * taille
		boule.radial_segments = 12
		boule.rings = 6
		_objet(boule, feuilles[k % 3], ou + Vector3.UP * 4.6 * taille)
	var metal := _matiere(Color("#455a64"))
	var lampe := _matiere(Color("#fff59d"))
	lampe.emission_enabled = true
	lampe.emission = Color("#fff59d")
	for coin: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var ou := Vector3(coin.x * (demi.x + 2.5), 0, coin.y * (demi.y + 2.5))
		var mat := CylinderMesh.new()
		mat.top_radius = 0.15
		mat.bottom_radius = 0.22
		mat.height = 12.0
		_objet(mat, metal, ou + Vector3.UP * 6.0)
		var globe := SphereMesh.new()
		globe.radius = 0.7
		globe.height = 1.4
		_objet(globe, lampe, ou + Vector3.UP * 12.3)
	# Le nom du skatepark, sur le mur du fond.
	var enseigne := Label3D.new()
	enseigne.text = "SKATEPARK DES FRUITS"
	enseigne.font_size = 220
	enseigne.pixel_size = 0.012
	enseigne.outline_size = 40
	enseigne.modulate = Color("#fff8e1")
	enseigne.outline_modulate = Color("#1d2433")
	enseigne.position = Vector3(0, hauteur(0.0, -demi.y) + 1.1, -demi.y - 0.05)
	add_child(enseigne)


func _ciel_et_lumiere() -> void:
	var ciel := Sky.new()
	var bleu := ProceduralSkyMaterial.new()
	bleu.sky_top_color = Color("#3d8fe0")
	bleu.sky_horizon_color = Color("#bfe3ff")
	bleu.ground_horizon_color = Color("#bfe3ff")
	bleu.ground_bottom_color = Color("#6fbf5a")
	ciel.sky_material = bleu
	var air := Environment.new()
	air.background_mode = Environment.BG_SKY
	air.sky = ciel
	air.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	air.ambient_light_color = Color("#dfe9ff")
	air.ambient_light_energy = 0.45
	air.ambient_light_sky_contribution = 0.0
	var monde := WorldEnvironment.new()
	monde.environment = air
	add_child(monde)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-52, 40, 0)
	soleil.shadow_enabled = true
	soleil.light_energy = 0.9
	soleil.directional_shadow_max_distance = 120.0
	add_child(soleil)


func _objet(forme: Mesh, matiere: Material, ou: Vector3) -> MeshInstance3D:
	var objet := MeshInstance3D.new()
	objet.mesh = forme
	objet.material_override = matiere
	objet.position = ou
	add_child(objet)
	return objet


func _matiere(couleur: Color) -> StandardMaterial3D:
	var matiere := StandardMaterial3D.new()
	matiere.albedo_color = couleur
	matiere.roughness = 0.8
	return matiere
