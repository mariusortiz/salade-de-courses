# Construit un circuit en 3D à partir de sa liste de points (donnees/circuits.gd) :
# la route, les barrières, les turbos, les tremplins et le décor.
extends Node3D

const R = preload("res://donnees/reglages.gd")

var courbe := Curve3D.new()
var longueur := 0.0
var largeur := 12.0
var tours := 3
var turbos: Array = []  # positions des turbos, en mètres depuis le départ


func construire(def: Dictionary) -> void:
	largeur = def.get("largeur", 12.0)
	tours = def.get("tours", 3)

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

	_ciel_et_lumiere()
	_sol()
	_route()
	_ligne_de_depart()
	for part in def.get("turbos", []):
		turbos.append(float(part) * longueur)
		_turbo(float(part) * longueur)
	for part in def.get("tremplins", []):
		_tremplin(float(part) * longueur)
	_arbres()


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
	for i in troncons:
		var a := repere(i * longueur / troncons)
		var b := repere((i + 1) * longueur / troncons)
		var teinte := (i >> 1) & 1
		var ag := a.origin - a.basis.x * demi
		var ad := a.origin + a.basis.x * demi
		var bg := b.origin - b.basis.x * demi
		var bd := b.origin + b.basis.x * demi
		_carre(route, ag, bg, bd, ad, a.basis.y, Color(R.COULEUR_ROUTE[teinte]))
		var rouge_blanc := Color(R.COULEUR_BARRIERES[teinte])
		_carre(murs, ag, ag + h, bg + h, bg, a.basis.x, rouge_blanc)
		_carre(murs, ad, bd, bd + h, ad + h, -a.basis.x, rouge_blanc)

	_poser(route.commit(), "route")
	_poser(murs.commit(), "mur")


func _carre(outil: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normale: Vector3, couleur: Color) -> void:
	for sommet in [a, b, c, a, c, d]:
		outil.set_color(couleur)
		outil.set_normal(normale)
		outil.add_vertex(sommet)


# Affiche un maillage et le rend solide. « sol » dit aux karts sur quoi ils roulent.
func _poser(maillage: ArrayMesh, sol: String) -> void:
	var matiere := StandardMaterial3D.new()
	matiere.vertex_color_use_as_albedo = true
	matiere.cull_mode = BaseMaterial3D.CULL_DISABLED
	var visible_ := MeshInstance3D.new()
	visible_.mesh = maillage
	visible_.material_override = matiere
	add_child(visible_)

	var forme: ConcavePolygonShape3D = maillage.create_trimesh_shape()
	forme.backface_collision = true
	_solide(forme, Transform3D.IDENTITY, sol)


func _solide(forme: Shape3D, ou: Transform3D, sol: String) -> void:
	var corps := StaticBody3D.new()
	corps.set_meta("sol", sol)
	corps.transform = ou
	var collision := CollisionShape3D.new()
	collision.shape = forme
	corps.add_child(collision)
	add_child(corps)


func _boite(taille: Vector3, ou: Transform3D, couleur: String) -> void:
	var boite := BoxMesh.new()
	boite.size = taille
	var m := MeshInstance3D.new()
	m.mesh = boite
	m.material_override = _matiere(couleur)
	m.transform = ou
	add_child(m)


func _matiere(couleur: String) -> StandardMaterial3D:
	var matiere := StandardMaterial3D.new()
	matiere.albedo_color = Color(couleur)
	return matiere


# ── Ce qu'on pose sur la route ───────────────────────────────

func _ligne_de_depart() -> void:
	var r := repere(0.0)
	var cases := 8
	var cote := largeur / cases
	for i in cases:
		for j in 2:
			var ou := r.translated_local(Vector3((i + 0.5) * cote - largeur / 2.0, 0.03, (j - 0.5) * cote))
			_boite(Vector3(cote, 0.04, cote), ou, "#111111" if (i + j) % 2 == 0 else "#ffffff")


func _turbo(distance: float) -> void:
	var r := repere(distance)
	_boite(Vector3(largeur * 0.5, 0.06, 5.0), r.translated_local(Vector3(0, 0.04, 0)), R.COULEUR_TURBO)


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
	var m := MeshInstance3D.new()
	m.mesh = pre
	m.material_override = _matiere(R.COULEUR_HERBE)
	m.position.y = -0.3
	add_child(m)
	var forme := BoxShape3D.new()
	forme.size = Vector3(2000, 1, 2000)
	_solide(forme, Transform3D(Basis.IDENTITY, Vector3(0, -0.8, 0)), "herbe")


func _arbres() -> void:
	# On note où passe la route pour ne pas planter d'arbre dessus.
	var route: Array[Vector2] = []
	var zone := Rect2()
	var d := 0.0
	while d < longueur:
		var p := courbe.sample_baked(d)
		var plat := Vector2(p.x, p.z)
		zone = Rect2(plat, Vector2.ZERO) if route.is_empty() else zone.expand(plat)
		route.append(plat)
		d += 4.0
	zone = zone.grow(50.0)

	var tronc := CylinderMesh.new()
	tronc.top_radius = 0.4
	tronc.bottom_radius = 0.6
	tronc.height = 3.0
	var feuillage := SphereMesh.new()
	feuillage.radius = 2.6
	feuillage.height = 5.0
	var bois := _matiere("#7a5230")
	var feuilles := _matiere("#2f8f3a")

	var hasard := RandomNumberGenerator.new()
	hasard.seed = 7  # toujours les mêmes arbres aux mêmes endroits
	for i in R.NOMBRE_ARBRES:
		var ou := Vector2(hasard.randf_range(zone.position.x, zone.end.x), hasard.randf_range(zone.position.y, zone.end.y))
		var libre := true
		for p in route:
			if p.distance_to(ou) < largeur / 2.0 + 5.0:
				libre = false
				break
		if not libre:
			continue
		var echelle := hasard.randf_range(0.8, 1.4)
		for partie in [[tronc, bois, 1.2], [feuillage, feuilles, 4.4]]:
			var m := MeshInstance3D.new()
			m.mesh = partie[0]
			m.material_override = partie[1]
			m.position = Vector3(ou.x, partie[2] * echelle - 0.3, ou.y)
			m.scale = Vector3.ONE * echelle
			add_child(m)
