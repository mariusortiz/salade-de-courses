# Construit un circuit en 3D à partir de sa liste de points (donnees/circuits.gd) :
# la route, les barrières, les turbos, les tremplins, les cagettes à bonus et le décor.
extends Node3D

const R = preload("res://donnees/reglages.gd")

const FRUITS := ["#e53935", "#fb8c00", "#fdd835", "#8e24aa", "#d81b60", "#7cb342"]

static var textures := {}  # les textures sont dessinées une seule fois, puis gardées

var courbe := Curve3D.new()
var longueur := 0.0
var largeur := 12.0
var tours := 3
var turbos: Array = []    # positions des turbos, en mètres depuis le départ
var cagettes: Array = []  # les cagettes à bonus posées sur la route
var jalons: Array[Vector3] = []  # un point de la route tous les 4 mètres, pour placer le décor
var zone := Rect2()
var hasard := RandomNumberGenerator.new()


func construire(def: Dictionary) -> void:
	largeur = def.get("largeur", 12.0)
	tours = def.get("tours", 3)
	hasard.seed = 7  # toujours le même décor aux mêmes endroits

	# La courbe passe par tous les points, en arrondissant les virages.
	var points: Array = def["points"]
	var n := points.size()
	courbe.bake_interval = 1.0
	for i in n + 1:
		var p: Vector3 = points[i % n]
		var suivant: Vector3 = points[(i + 1) % n]
		var precedent: Vector3 = points[(i - 1 + n) % n]
		var poignee := (suivant - precedent) / 6.0
		courbe.add_point(p, -poignee, poignee)
	longueur = courbe.get_baked_length()

	var d := 0.0
	while d < longueur:
		var p := courbe.sample_baked(d)
		var plat := Vector2(p.x, p.z)
		zone = Rect2(plat, Vector2.ZERO) if jalons.is_empty() else zone.expand(plat)
		jalons.append(p)
		d += 4.0
	zone = zone.grow(60.0)

	_ciel_et_lumiere()
	_sol()
	_route()
	_piliers()
	_ligne_de_depart()
	for part in def.get("turbos", []):
		turbos.append(float(part) * longueur)
		_turbo(float(part) * longueur)
	for part in def.get("tremplins", []):
		_tremplin(float(part) * longueur)
	for part in def.get("bonus", []):
		_rangee_de_cagettes(float(part) * longueur)
	_tribunes()
	_arbres()
	_rochers_et_buissons()
	_fleurs()
	_bottes_de_paille()
	_lointain()


func _process(dt: float) -> void:
	for c in cagettes:
		c.rotate_y(dt * 1.5)


# Donne la position et l'orientation de la route à une distance du départ.
# basis.x = vers la droite de la route, basis.y = vers le haut, -basis.z = vers l'avant.
func repere(distance: float) -> Transform3D:
	var d := fposmod(distance, longueur)
	var p := courbe.sample_baked(d, true)
	var q := courbe.sample_baked(fposmod(d + 0.5, longueur), true)
	var avant := (q - p).normalized()
	var droite := avant.cross(Vector3.UP).normalized()
	var haut := droite.cross(avant)
	return Transform3D(Basis(droite, haut, -avant), p)


# ── La route et les barrières ────────────────────────────────

func _route() -> void:
	var route := SurfaceTool.new()
	var murs := SurfaceTool.new()
	route.begin(Mesh.PRIMITIVE_TRIANGLES)
	murs.begin(Mesh.PRIMITIVE_TRIANGLES)

	var troncons := int(ceil(longueur / 2.0))
	var demi := largeur / 2.0
	var h := Vector3.UP * R.HAUTEUR_BARRIERES
	var dalle := Vector3.DOWN * 0.7
	var beton := Color("#8d939e")
	for i in troncons:
		var da := i * longueur / troncons
		var db := (i + 1) * longueur / troncons
		var a := repere(da)
		var b := repere(db)
		var ag := a.origin - a.basis.x * demi
		var ad := a.origin + a.basis.x * demi
		var bg := b.origin - b.basis.x * demi
		var bd := b.origin + b.basis.x * demi
		# La texture de la route se répète tous les 8 mètres.
		_carre(route, ag, bg, bd, ad, a.basis.y, Color.WHITE,
			Vector2(0, da / 8.0), Vector2(0, db / 8.0), Vector2(1, db / 8.0), Vector2(1, da / 8.0))

		# Les barrières ont une épaisseur, et la route repose sur une dalle en béton.
		var rouge_blanc := Color(R.COULEUR_BARRIERES[(i >> 1) & 1])
		for cote: float in [-1.0, 1.0]:
			var pa := a.origin + a.basis.x * demi * cote
			var pb := b.origin + b.basis.x * demi * cote
			var oa := pa + a.basis.x * 0.4 * cote
			var ob := pb + b.basis.x * 0.4 * cote
			_carre(murs, pa, pa + h, pb + h, pb, -a.basis.x * cote, rouge_blanc)
			_carre(murs, pa + h, oa + h, ob + h, pb + h, Vector3.UP, rouge_blanc.darkened(0.15))
			_carre(murs, oa, oa + h, ob + h, ob, a.basis.x * cote, rouge_blanc)
			_carre(murs, oa, ob, ob + dalle, oa + dalle, a.basis.x * cote, beton)

	var bitume := StandardMaterial3D.new()
	bitume.albedo_texture = _texture("route")
	bitume.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	bitume.cull_mode = BaseMaterial3D.CULL_DISABLED
	bitume.roughness = 0.9
	_poser(route.commit(), "route", bitume)
	var peinture := StandardMaterial3D.new()
	peinture.vertex_color_use_as_albedo = true
	peinture.cull_mode = BaseMaterial3D.CULL_DISABLED
	_poser(murs.commit(), "mur", peinture).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _carre(outil: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normale: Vector3, couleur: Color,
		ta := Vector2.ZERO, tb := Vector2.ZERO, tc := Vector2.ZERO, td := Vector2.ZERO) -> void:
	for sommet in [[a, ta], [b, tb], [c, tc], [a, ta], [c, tc], [d, td]]:
		outil.set_color(couleur)
		outil.set_normal(normale)
		outil.set_uv(sommet[1])
		outil.add_vertex(sommet[0])


# Affiche un maillage et le rend solide. « sol » dit aux karts sur quoi ils roulent.
func _poser(maillage: ArrayMesh, sol: String, matiere: Material) -> MeshInstance3D:
	var visible_ := MeshInstance3D.new()
	visible_.mesh = maillage
	visible_.material_override = matiere
	add_child(visible_)

	var forme: ConcavePolygonShape3D = maillage.create_trimesh_shape()
	forme.backface_collision = true
	_solide(forme, Transform3D.IDENTITY, sol)
	return visible_


func _solide(forme: Shape3D, ou: Transform3D, sol: String) -> void:
	var corps := StaticBody3D.new()
	corps.set_meta("sol", sol)
	corps.transform = ou
	var collision := CollisionShape3D.new()
	collision.shape = forme
	corps.add_child(collision)
	add_child(corps)


# Des piliers sous la route quand elle est en hauteur (sauf au-dessus d'une autre route).
func _piliers() -> void:
	var pilier := CylinderMesh.new()
	pilier.top_radius = 0.9
	pilier.bottom_radius = 1.1
	pilier.height = 1.0
	var beton := _matiere("#8d939e")
	for i in range(0, jalons.size(), 3):
		var p := jalons[i]
		if p.y < 1.5:
			continue
		var libre := true
		for q in jalons:
			if q.y < p.y - 3.0 and Vector2(q.x - p.x, q.z - p.z).length() < largeur / 2.0 + 2.0:
				libre = false
				break
		if libre:
			_objet(pilier, beton, Vector3(p.x, p.y / 2.0 - 0.2, p.z), Vector3(1, p.y + 0.2, 1))


# ── Les outils pour fabriquer des objets ─────────────────────

func _objet(forme: Mesh, matiere: Material, ou: Vector3, echelle := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = forme
	m.material_override = matiere
	m.position = ou
	m.scale = echelle
	(parent if parent != null else self).add_child(m)
	return m


func _boite(taille: Vector3, ou: Transform3D, couleur: String) -> MeshInstance3D:
	var boite := BoxMesh.new()
	boite.size = taille
	var m := _objet(boite, _matiere(couleur), Vector3.ZERO)
	m.transform = ou
	return m


func _boule(rayon: float) -> SphereMesh:
	var boule := SphereMesh.new()
	boule.radius = rayon
	boule.height = rayon * 2.0
	boule.radial_segments = 16
	boule.rings = 8
	return boule


func _cylindre(haut: float, bas: float, hauteur: float) -> CylinderMesh:
	var cylindre := CylinderMesh.new()
	cylindre.top_radius = haut
	cylindre.bottom_radius = bas
	cylindre.height = hauteur
	cylindre.radial_segments = 12
	return cylindre


func _matiere(couleur: String) -> StandardMaterial3D:
	var matiere := StandardMaterial3D.new()
	matiere.albedo_color = Color(couleur)
	return matiere


# Les textures sont dessinées par le jeu lui-même, point par point.
func _texture(nom: String) -> ImageTexture:
	if textures.has(nom):
		return textures[nom]
	var cote := 128
	var bruit := FastNoiseLite.new()
	bruit.seed = nom.hash()
	bruit.frequency = 0.05 if nom == "herbe" else 0.3
	var grain: Image = bruit.get_seamless_image(cote, cote)
	var image := Image.create(cote, cote, false, Image.FORMAT_RGB8)
	for y in cote:
		for x in cote:
			var g := grain.get_pixel(x, y).r
			var couleur := Color.WHITE
			match nom:
				"herbe":
					couleur = Color(R.COULEUR_HERBE).darkened(0.18).lerp(Color(R.COULEUR_HERBE).lightened(0.12), g)
					if (x * 7 + y * 13) % 29 == 0:
						couleur = couleur.lightened(0.15)  # des brins d'herbe plus clairs
				"route":
					# Deux bandes de bitume, les lignes des bords et les pointillés du milieu.
					couleur = Color(R.COULEUR_ROUTE[y >> 6]).darkened(0.25 * g)
					if (x >= 4 and x < 8) or (x >= 120 and x < 124):
						couleur = Color(R.COULEUR_LIGNES[0])
					elif x >= 62 and x < 66 and y < 64:
						couleur = Color(R.COULEUR_LIGNES[1])
				"bois":
					couleur = Color("#c58b4e").darkened(0.2 * g)
					if y % 32 < 3 or x < 3 or x > 124:
						couleur = Color("#6d4423")  # les fentes entre les planches
				"paille":
					couleur = Color("#e8c35a").darkened(0.3 * g)
			image.set_pixel(x, y, couleur)
	image.generate_mipmaps()
	textures[nom] = ImageTexture.create_from_image(image)
	return textures[nom]


func _matiere_texture(nom: String, repetition := Vector3.ONE) -> StandardMaterial3D:
	var matiere := StandardMaterial3D.new()
	matiere.albedo_texture = _texture(nom)
	matiere.uv1_scale = repetition
	matiere.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return matiere


# Y a-t-il de la place ici, assez loin de la route ?
func _libre(ou: Vector2, marge: float) -> bool:
	var tribunes := repere(-14.0).origin
	if ou.distance_to(Vector2(tribunes.x, tribunes.z)) < 22.0:
		return false  # on garde la place des tribunes
	for p in jalons:
		if Vector2(p.x, p.z).distance_to(ou) < largeur / 2.0 + marge:
			return false
	return true


func _au_hasard_dans_la_zone() -> Vector2:
	return Vector2(hasard.randf_range(zone.position.x, zone.end.x), hasard.randf_range(zone.position.y, zone.end.y))


# ── Ce qu'on pose sur la route ───────────────────────────────

func _ligne_de_depart() -> void:
	var r := repere(0.0)
	var cases := 8
	var cote := largeur / cases
	for i in cases:
		for j in 2:
			var ou := r.translated_local(Vector3((i + 0.5) * cote - largeur / 2.0, 0.03, (j - 0.5) * cote))
			_boite(Vector3(cote, 0.04, cote), ou, "#111111" if (i + j) % 2 == 0 else "#ffffff")

	# L'arche au-dessus de la ligne, avec le nom du jeu.
	var demi := largeur / 2.0 + 0.9
	for x in [-demi, demi]:
		_boite(Vector3(0.7, 7.0, 0.7), r.translated_local(Vector3(x, 3.2, 0)), "#f5f5f5")
	_boite(Vector3(demi * 2.0 + 0.7, 1.6, 0.6), r.translated_local(Vector3(0, 6.2, 0)), "#e53935")
	for face in [1.0, -1.0]:
		var titre := Label3D.new()
		titre.text = R.TITRE
		titre.font_size = 110
		titre.pixel_size = 0.011
		titre.outline_size = 24
		titre.outline_modulate = Color("#1d2433")
		titre.transform = r.translated_local(Vector3(0, 6.2, 0.32 * face))
		if face < 0.0:
			titre.rotate_object_local(Vector3.UP, PI)
		add_child(titre)


func _turbo(distance: float) -> void:
	var r := repere(distance)
	_boite(Vector3(largeur * 0.5, 0.06, 5.0), r.translated_local(Vector3(0, 0.04, 0)), R.COULEUR_TURBO)
	# Trois flèches pour montrer le sens.
	for i in 3:
		for cote: float in [-1.0, 1.0]:
			var ou := r.translated_local(Vector3(cote * 0.9, 0.08, 1.4 - i * 1.5)).rotated_local(Vector3.UP, cote * 0.7)
			_boite(Vector3(0.45, 0.03, 2.2), ou, "#fff8e1")


func _tremplin(distance: float) -> void:
	var r := repere(distance)
	var taille := Vector3(largeur * 0.6, 0.4, 8.0)
	var base := r.basis.rotated(r.basis.x, 0.2)  # la pente du tremplin
	var centre := r.origin - base.z * (taille.z / 2.0) - base.y * (taille.y / 2.0)
	var ou := Transform3D(base, centre)
	_boite(taille, ou, R.COULEUR_TREMPLIN)
	var forme := BoxShape3D.new()
	forme.size = taille
	_solide(forme, ou, "route")


# Une rangée de cagettes de fruits en travers de la route. C'est course.gd qui regarde
# si un kart en touche une.
func _rangee_de_cagettes(distance: float) -> void:
	var r := repere(distance)
	var caisse := BoxMesh.new()
	caisse.size = Vector3.ONE * 1.1
	var bois := _matiere_texture("bois")
	for i in 4:
		var cagette := Node3D.new()
		cagette.position = r.origin + r.basis.x * (i - 1.5) * largeur / 5.0 + r.basis.y * 1.0
		add_child(cagette)
		_objet(caisse, bois, Vector3.ZERO, Vector3.ONE, cagette)
		for j in 4:
			var fruit := _matiere(FRUITS[(i + j) % FRUITS.size()])
			_objet(_boule(0.3), fruit, Vector3((j % 2 - 0.5) * 0.5, 0.6, (j >> 1) * 0.5 - 0.25), Vector3.ONE, cagette)
		cagettes.append(cagette)


# ── Le décor ─────────────────────────────────────────────────

func _ciel_et_lumiere() -> void:
	var ciel := Sky.new()
	var bleu := ProceduralSkyMaterial.new()
	bleu.sky_top_color = Color(R.COULEUR_CIEL[0])
	bleu.sky_horizon_color = Color(R.COULEUR_CIEL[1])
	bleu.ground_horizon_color = Color(R.COULEUR_CIEL[1])
	bleu.ground_bottom_color = Color(R.COULEUR_HERBE)
	ciel.sky_material = bleu
	var ambiance := Environment.new()
	ambiance.background_mode = Environment.BG_SKY
	ambiance.sky = ciel
	ambiance.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	ambiance.ambient_light_energy = 0.8
	var monde := WorldEnvironment.new()
	monde.environment = ambiance
	add_child(monde)

	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-55, 35, 0)
	soleil.shadow_enabled = true
	soleil.directional_shadow_max_distance = 120.0
	add_child(soleil)


func _sol() -> void:
	var pre := PlaneMesh.new()
	pre.size = Vector2(2000, 2000)
	_objet(pre, _matiere_texture("herbe", Vector3(250, 250, 1)), Vector3(0, -0.3, 0))
	var forme := BoxShape3D.new()
	forme.size = Vector3(2000, 1, 2000)
	_solide(forme, Transform3D(Basis.IDENTITY, Vector3(0, -0.8, 0)), "herbe")


# Trois sortes d'arbres : des ronds, des sapins et des arbres fruitiers.
func _arbres() -> void:
	var tronc := _cylindre(0.4, 0.6, 3.0)
	var feuillage := _boule(2.6)
	var etage := _cylindre(0.0, 2.2, 3.0)
	var fruit := _boule(0.35)
	var bois := _matiere("#7a5230")
	var verts := [_matiere("#2f8f3a"), _matiere("#3fa34d"), _matiere("#267a45")]
	var sapin := _matiere("#1f6b4a")

	for i in R.NOMBRE_ARBRES:
		var ou := _au_hasard_dans_la_zone()
		var sorte := hasard.randi_range(0, 2)
		var echelle := hasard.randf_range(0.8, 1.4)
		var couleur_fruit := _matiere(FRUITS[hasard.randi_range(0, 2)])
		if not _libre(ou, 5.0):
			continue
		var arbre := Node3D.new()
		arbre.position = Vector3(ou.x, -0.3, ou.y)
		arbre.scale = Vector3.ONE * echelle
		arbre.rotation.y = hasard.randf() * TAU
		add_child(arbre)
		_objet(tronc, bois, Vector3(0, 1.5, 0), Vector3.ONE, arbre)
		if sorte == 1:
			for j in 3:
				_objet(etage, sapin, Vector3(0, 3.2 + j * 1.6, 0), Vector3.ONE * (1.0 - j * 0.22), arbre)
		else:
			_objet(feuillage, verts[i % 3], Vector3(0, 4.6, 0), Vector3.ONE, arbre)
			_objet(feuillage, verts[(i + 1) % 3], Vector3(1.4, 3.8, 0.6), Vector3.ONE * 0.6, arbre)
			if sorte == 2:
				for j in 7:
					var direction := Vector3(cos(j * 0.9), 0.3 * sin(j * 2.1), sin(j * 0.9)).normalized()
					_objet(fruit, couleur_fruit, Vector3(0, 4.6, 0) + direction * 2.55, Vector3.ONE, arbre)


func _rochers_et_buissons() -> void:
	var caillou := _boule(1.0)
	var gris := [_matiere("#8a8f98"), _matiere("#6f747d")]
	for i in R.NOMBRE_ROCHERS:
		var ou := _au_hasard_dans_la_zone()
		var taille := hasard.randf_range(0.6, 2.0)
		if _libre(ou, 3.0):
			var m := _objet(caillou, gris[i % 2], Vector3(ou.x, -0.3, ou.y), Vector3(1.4, 0.8, 1.0) * taille)
			m.rotation.y = hasard.randf() * TAU

	var touffe := _boule(1.0)
	var verts := [_matiere("#3c8d3f"), _matiere("#56a64b")]
	for i in R.NOMBRE_BUISSONS:
		var ou := _au_hasard_dans_la_zone()
		var taille := hasard.randf_range(0.7, 1.3)
		if _libre(ou, 2.5):
			for j in 3:
				_objet(touffe, verts[(i + j) % 2], Vector3(ou.x + (j - 1) * 0.9 * taille, 0.1, ou.y + (j % 2) * 0.5), Vector3(1.0, 0.75, 1.0) * taille)


# Des fleurs de toutes les couleurs au bord de la route.
func _fleurs() -> void:
	var fleurs := MultiMesh.new()
	fleurs.transform_format = MultiMesh.TRANSFORM_3D
	fleurs.use_colors = true
	fleurs.mesh = _boule(0.2)
	fleurs.instance_count = R.NOMBRE_FLEURS
	var palette := ["#ffffff", "#ffeb3b", "#ff80ab", "#ff7043", "#b39ddb"]
	for i in R.NOMBRE_FLEURS:
		var r := repere(hasard.randf() * longueur)
		var cote := 1.0 if hasard.randf() < 0.5 else -1.0
		var ou := r.origin + r.basis.x * cote * (largeur / 2.0 + hasard.randf_range(1.2, 14.0))
		var libre := r.origin.y < 0.5 and _libre(Vector2(ou.x, ou.z), 1.0)
		# Une fleur qui tomberait sur la route est cachée sous l'herbe.
		fleurs.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(ou.x, -0.2 if libre else -5.0, ou.z)))
		fleurs.set_instance_color(i, Color(palette[i % palette.size()]))
	var matiere := StandardMaterial3D.new()
	matiere.vertex_color_use_as_albedo = true
	var champ := MultiMeshInstance3D.new()
	champ.multimesh = fleurs
	champ.material_override = matiere
	champ.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(champ)


func _bottes_de_paille() -> void:
	var botte := _cylindre(0.8, 0.8, 1.5)
	var paille := _matiere_texture("paille", Vector3(3, 1, 1))
	for i in 24:
		var r := repere(hasard.randf() * longueur)
		var cote := 1.0 if i % 2 == 0 else -1.0
		var ou := r.origin + r.basis.x * cote * (largeur / 2.0 + 2.2)
		if r.origin.y < 0.5 and _libre(Vector2(ou.x, ou.z), 1.5):
			var m := _objet(botte, paille, Vector3(ou.x, 0.5, ou.z))
			m.basis = Basis(r.basis.y, -r.basis.z, r.basis.x)  # couchée le long de la route


# Les tribunes près du départ, avec des fruits qui regardent la course.
func _tribunes() -> void:
	var spectateur := _boule(0.45)
	var feuille := _boule(0.15)
	var vert := _matiere("#43a047")
	for cote: float in [-1.0, 1.0]:
		var r := repere(-14.0)
		var bord := largeur / 2.0 + 3.0
		for marche in 3:
			var hauteur := 1.0 + marche
			var ou := r.translated_local(Vector3(cote * (bord + marche * 1.6 + 0.8), hauteur / 2.0 - 0.3, 0))
			_boite(Vector3(1.6, hauteur, 16.0), ou, "#cfd8dc" if marche % 2 == 0 else "#b0bec5")
			for place in 10:
				var assis := ou.translated_local(Vector3(0, hauteur / 2.0 + 0.4, (place - 4.5) * 1.5 + hasard.randf_range(-0.2, 0.2)))
				_objet(spectateur, _matiere(FRUITS[hasard.randi_range(0, FRUITS.size() - 1)]), assis.origin)
				_objet(feuille, vert, assis.origin + Vector3(0, 0.48, 0), Vector3(1.4, 0.4, 0.8))
		# Le toit et ses poteaux.
		var toit := r.translated_local(Vector3(cote * (bord + 2.4), 5.6, 0))
		_boite(Vector3(5.6, 0.25, 17.0), toit, "#e53935" if cote < 0.0 else "#1e88e5")
		for z in [-8.0, 8.0]:
			_boite(Vector3(0.3, 5.6, 0.3), r.translated_local(Vector3(cote * (bord + 4.9), 2.6, z)), "#f5f5f5")


# Ce qu'on voit au loin : des collines, des nuages et des montgolfières.
func _lointain() -> void:
	var centre := zone.get_center()
	var rayon := maxf(zone.size.x, zone.size.y) / 2.0 + 200.0
	var boule := _boule(1.0)
	var colline := _matiere(Color(R.COULEUR_HERBE).darkened(0.2).to_html())
	for i in 11:
		var angle := i * TAU / 11.0 + hasard.randf_range(-0.2, 0.2)
		var taille := Vector3(hasard.randf_range(110, 190), hasard.randf_range(25, 70), hasard.randf_range(110, 190))
		_objet(boule, colline, Vector3(centre.x + cos(angle) * rayon, -2.0, centre.y + sin(angle) * rayon), taille)

	var blanc := StandardMaterial3D.new()
	blanc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in R.NOMBRE_NUAGES:
		var ou := _au_hasard_dans_la_zone() * 1.8
		var hauteur := hasard.randf_range(55, 90)
		for j in 4:
			var m := _objet(boule, blanc, Vector3(ou.x + j * 7.0, hauteur + (j % 2) * 2.0, ou.y), Vector3(9, 4.5, 7) * hasard.randf_range(0.7, 1.2))
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for i in 3:
		var ou := _au_hasard_dans_la_zone()
		var ballon := Node3D.new()
		ballon.position = Vector3(ou.x, hasard.randf_range(30, 55), ou.y)
		add_child(ballon)
		_objet(_boule(6.0), _matiere(FRUITS[i]), Vector3.ZERO, Vector3(1, 1.15, 1), ballon)
		_objet(_cylindre(4.2, 1.2, 5.0), _matiere(FRUITS[i + 3]), Vector3(0, -6.0, 0), Vector3.ONE, ballon)
		_objet(_cylindre(1.0, 0.9, 1.4), _matiere("#7a5230"), Vector3(0, -10.5, 0), Vector3.ONE, ballon)
