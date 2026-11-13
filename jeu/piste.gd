# Construit un circuit en 3D à partir de sa liste de points (donnees/circuits.gd) :
# la route, les barrières, les turbos, les tremplins et les cagettes à bonus.
# Le décor autour est posé par decor.gd.
extends Node3D

const R = preload("res://donnees/reglages.gd")
const Decor = preload("res://jeu/decor.gd")

const FRUITS := ["#e53935", "#fb8c00", "#fdd835", "#8e24aa", "#d81b60", "#7cb342"]

static var textures := {}  # les textures sont dessinées une seule fois, puis gardées

var courbe := Curve3D.new()
var longueur := 0.0
var largeur := 12.0
var tours := 3
var turbos: Array = []    # positions des turbos, en mètres depuis le départ
const RAYON_ANNEAU := 6.0
const LARGEUR_RACCOURCI := 7.0

var anneaux: Array = []   # les anneaux du mode Avions, dans l'ordre
var obstacles: Array = [] # les obstacles : les toucher fait faire un tête-à-queue
var horloge := 0.0
var raccourcis: Array = []  # les raccourcis : leur courbe, où ils commencent et combien de route ils remplacent
var pas_de_raccourci: Array[Vector3] = []  # un point de raccourci tous les 1,5 mètre
var graines: Array = []   # les graines à ramasser pendant une chasse aux graines
var regle := ""           # la règle du défi du jour, s'il y en a une (voir donnees/defis.gd)
var niveau_ordis: float = R.NIVEAU_ORDIS
var cagettes: Array = []  # les cagettes à bonus posées sur la route
var jalons: Array[Vector3] = []  # un point de la route tous les 4 mètres, pour placer le décor
var zone := Rect2()
var hasard := RandomNumberGenerator.new()
var ambiance: Dictionary  # les couleurs et les réglages du décor (voir decor.gd)
var animes: Array = []    # les objets du décor qui bougent : poissons, bulles, astéroïdes


# aerien : true = le mode Avions, avec des anneaux à traverser au-dessus de la route.
func construire(def: Dictionary, aerien := false) -> void:
	largeur = def.get("largeur", 12.0)
	tours = def.get("tours", 3)
	var decor: String = def.get("decor", "campagne")
	ambiance = Decor.ambiance(decor)
	match regle:
		"lune":
			ambiance["gravite"] *= 0.5
		"patinoire":
			ambiance["adherence"] *= 0.4
		"rapides":
			niveau_ordis = 1.0
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
	if not aerien:
		for bouts in def.get("raccourcis", []):
			_tracer_un_raccourci(float(bouts[0]) * longueur, float(bouts[1]) * longueur)
	_route()
	_piliers()
	for numero in raccourcis.size():
		_construire_un_raccourci(numero)
	_ligne_de_depart()
	for part in def.get("turbos", []):
		turbos.append(float(part) * longueur)
		_turbo(float(part) * longueur)
	for part in def.get("tremplins", []):
		_tremplin(float(part) * longueur)
	if aerien:
		_anneaux(def)
	else:
		for part in def.get("bonus", []):
			_rangee_de_cagettes(float(part) * longueur)
	if ambiance["tribunes"]:
		_tribunes()
	var decorateur := Decor.new()
	decorateur.planter(self, decor)
	_obstacles(def, aerien, decorateur, decor)


func _process(dt: float) -> void:
	for c in cagettes:
		c.rotate_y(dt * 1.5)
	# Les obstacles : certains ne bougent pas, d'autres vont et viennent.
	horloge += dt
	for o in obstacles:
		var va_et_vient: float = o["amplitude"] * sin(horloge * R.OBSTACLES_VITESSE + o["phase"])
		o["noeud"].position = o["base"] + o["axe"] * va_et_vient
		o["noeud"].rotate_y(dt)
		o["voie"] = o["voie_de_base"] + (va_et_vient if o["en_travers"] else 0.0)
	for g in graines:
		g["noeud"].rotate_y(dt * 3.0)
	for a in animes:
		var noeud: Node3D = a["noeud"]
		if a.has("monte"):
			# Une bulle monte, puis repart du sol.
			noeud.position.y = fposmod(noeud.position.y + a["monte"] * dt, a["plafond"])
		else:
			# Un poisson ou un astéroïde tourne en rond.
			a["angle"] += a["vitesse"] * dt
			noeud.position = a["centre"] + Vector3(cos(a["angle"]), 0.08 * sin(a["angle"] * 3.0), sin(a["angle"])) * a["rayon"]
			noeud.rotation.y = -a["angle"]


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
		var lueur := Color.WHITE
		if ambiance["arc_en_ciel"]:
			lueur = Color.from_hsv(fposmod(da / longueur * 3.0, 1.0), 0.45, 1.0)
		_carre(route, ag, bg, bd, ad, a.basis.y, lueur,
			Vector2(0, da / 8.0), Vector2(0, db / 8.0), Vector2(1, db / 8.0), Vector2(1, da / 8.0))

		# Les barrières ont une épaisseur, et la route repose sur une dalle en béton.
		var rouge_blanc := Color(ambiance["barrieres"][(i >> 1) & 1]) * lueur
		for cote: float in [-1.0, 1.0]:
			var pa := a.origin + a.basis.x * demi * cote
			var pb := b.origin + b.basis.x * demi * cote
			var oa := pa + a.basis.x * 0.4 * cote
			var ob := pb + b.basis.x * 0.4 * cote
			if _sur_un_raccourci((pa + pb) / 2.0):
				continue  # pas de barrière devant l'entrée ou la sortie d'un raccourci
			_carre(murs, pa, pa + h, pb + h, pb, -a.basis.x * cote, rouge_blanc)
			_carre(murs, pa + h, oa + h, ob + h, pb + h, Vector3.UP, rouge_blanc.darkened(0.15))
			_carre(murs, oa, oa + h, ob + h, ob, a.basis.x * cote, rouge_blanc)
			_carre(murs, oa, ob, ob + dalle, oa + dalle, a.basis.x * cote, beton)

	var bitume := StandardMaterial3D.new()
	bitume.albedo_texture = _texture("route-" + str(ambiance["route"]), "route", ambiance["route"] + ambiance["lignes"], 0.3)
	bitume.vertex_color_use_as_albedo = true
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
func _poser(maillage: ArrayMesh, sol: String, matiere: Material, raccourci := -1) -> MeshInstance3D:
	var visible_ := MeshInstance3D.new()
	visible_.mesh = maillage
	visible_.material_override = matiere
	add_child(visible_)

	var forme: ConcavePolygonShape3D = maillage.create_trimesh_shape()
	forme.backface_collision = true
	_solide(forme, Transform3D.IDENTITY, sol, raccourci)
	return visible_


func _solide(forme: Shape3D, ou: Transform3D, sol: String, raccourci := -1) -> void:
	var corps := StaticBody3D.new()
	corps.set_meta("sol", sol)
	if raccourci >= 0:
		corps.set_meta("raccourci", raccourci)  # pour que le kart sache où il en est (voir kart.gd)
	corps.transform = ou
	var collision := CollisionShape3D.new()
	collision.shape = forme
	corps.add_child(collision)
	add_child(corps)


# ── Les raccourcis ───────────────────────────────────────────

# Un raccourci part de la route, coupe tout droit, et la rejoint plus loin.
func _tracer_un_raccourci(de: float, a: float) -> void:
	var debut := repere(de)
	var bout := repere(a)
	var corde := bout.origin - debut.origin
	# Il quitte la route en douceur, et la retrouve en douceur.
	var sortie := (-debut.basis.z + corde.normalized()).normalized() * corde.length() * 0.3
	var entree := (-bout.basis.z + corde.normalized()).normalized() * corde.length() * 0.3
	var trace := Curve3D.new()
	trace.bake_interval = 1.0
	trace.add_point(debut.origin, Vector3.ZERO, sortie)
	trace.add_point(bout.origin, -entree, Vector3.ZERO)
	raccourcis.append({"courbe": trace, "longueur": trace.get_baked_length(), "de": de, "remplace": a - de})
	var d := 0.0
	while d < trace.get_baked_length():
		pas_de_raccourci.append(trace.sample_baked(d))
		d += 1.5


func _sur_un_raccourci(ou: Vector3) -> bool:
	for p in pas_de_raccourci:
		if absf(p.y - ou.y) < 2.0 and Vector2(p.x - ou.x, p.z - ou.z).length() < LARGEUR_RACCOURCI / 2.0 + 0.6:
			return true
	return false


func _construire_un_raccourci(numero: int) -> void:
	var trace: Curve3D = raccourcis[numero]["courbe"]
	var long: float = raccourcis[numero]["longueur"]
	var chemin := SurfaceTool.new()
	var murs := SurfaceTool.new()
	chemin.begin(Mesh.PRIMITIVE_TRIANGLES)
	murs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var demi := LARGEUR_RACCOURCI / 2.0
	var h := Vector3.UP * R.HAUTEUR_BARRIERES
	var dessus := Vector3.UP * 0.04  # un tout petit peu au-dessus de la route, là où ils se touchent
	var troncons := int(ceil(long / 2.0))
	for i in troncons:
		var a := _repere_de(trace, i * long / troncons)
		var b := _repere_de(trace, (i + 1) * long / troncons)
		_carre(chemin, a.origin - a.basis.x * demi + dessus, b.origin - b.basis.x * demi + dessus, b.origin + b.basis.x * demi + dessus, a.origin + a.basis.x * demi + dessus,
			Vector3.UP, Color.WHITE, Vector2(0, i * 0.25), Vector2(0, (i + 1) * 0.25), Vector2(1, (i + 1) * 0.25), Vector2(1, i * 0.25))
		var teinte := Color(ambiance["lignes"][1] if i % 2 == 0 else ambiance["barrieres"][0])
		for cote: float in [-1.0, 1.0]:
			var pa := a.origin + a.basis.x * demi * cote
			var pb := b.origin + b.basis.x * demi * cote
			# Pas de barrière là où le raccourci est encore sur la route.
			var milieu := (pa + pb) / 2.0
			var route := courbe.get_closest_point(milieu)
			if absf(route.y - milieu.y) < 2.5 and Vector2(route.x - milieu.x, route.z - milieu.z).length() < largeur / 2.0 + 0.5:
				continue
			var oa := pa + a.basis.x * 0.3 * cote
			var ob := pb + b.basis.x * 0.3 * cote
			_carre(murs, pa, pa + h, pb + h, pb, -a.basis.x * cote, teinte)
			_carre(murs, pa + h, oa + h, ob + h, pb + h, Vector3.UP, teinte.darkened(0.15))
			_carre(murs, oa + Vector3.DOWN * 0.7, oa + h, ob + h, ob + Vector3.DOWN * 0.7, a.basis.x * cote, teinte)
		# Des piliers si le raccourci est en hauteur.
		if i % 6 == 3 and a.origin.y > 1.5 and not ambiance["sol"].is_empty():
			_objet(_cylindre(0.7, 0.9, 1.0), _matiere("#8d939e"), Vector3(a.origin.x, a.origin.y / 2.0 - 0.2, a.origin.z), Vector3(1, a.origin.y + 0.2, 1))

	var terre := _matiere_texture("raccourci-" + str(ambiance["route"]), "bruit", [Color(ambiance["route"][0]).lightened(0.35).to_html(), Color(ambiance["route"][1]).lightened(0.2).to_html()], 0.25)
	terre.cull_mode = BaseMaterial3D.CULL_DISABLED
	terre.vertex_color_use_as_albedo = true
	_poser(chemin.commit(), "route", terre, numero)
	var peinture := StandardMaterial3D.new()
	peinture.vertex_color_use_as_albedo = true
	peinture.cull_mode = BaseMaterial3D.CULL_DISABLED
	_poser(murs.commit(), "mur", peinture).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Un panneau à l'entrée.
	var entree := _repere_de(trace, minf(22.0, long * 0.3))
	var panneau := Label3D.new()
	panneau.text = "RACCOURCI"
	panneau.font_size = 90
	panneau.pixel_size = 0.012
	panneau.outline_size = 22
	panneau.modulate = Color(ambiance["lignes"][1])
	panneau.outline_modulate = Color("#1d2433")
	panneau.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	panneau.position = entree.origin + Vector3.UP * 4.5
	add_child(panneau)


func _repere_de(trace: Curve3D, distance: float) -> Transform3D:
	var long := trace.get_baked_length()
	var d := clampf(distance, 0.0, long - 0.6)
	var p := trace.sample_baked(d, true)
	var avant := (trace.sample_baked(d + 0.5, true) - p).normalized()
	var droite := avant.cross(Vector3.UP).normalized()
	return Transform3D(Basis(droite, droite.cross(avant), -avant), p)


# Des piliers sous la route quand elle est en hauteur (sauf au-dessus d'une autre route).
func _piliers() -> void:
	if ambiance["sol"].is_empty():
		return  # pas de sol, pas de piliers
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
#   cle       un nom pour retrouver la texture (elle n'est dessinée qu'une fois)
#   sorte     "bruit" (deux couleurs mélangées), "route", "bois" ou "damier"
#   couleurs  les couleurs à utiliser
#   grain     petit = grandes taches, grand = petits grains
func _texture(cle: String, sorte: String, couleurs: Array, grain := 0.1) -> ImageTexture:
	if textures.has(cle):
		return textures[cle]
	var cote := 128
	var bruit := FastNoiseLite.new()
	bruit.seed = cle.hash()
	bruit.frequency = grain
	var taches: Image = bruit.get_seamless_image(cote, cote)
	var teintes: Array = couleurs.map(func(c): return Color(c))
	var image := Image.create(cote, cote, false, Image.FORMAT_RGB8)
	for y in cote:
		for x in cote:
			var g := taches.get_pixel(x, y).r
			var couleur := Color.WHITE
			match sorte:
				"route":
					# Deux bandes de bitume, les lignes des bords et les pointillés du milieu.
					couleur = teintes[y >> 6].darkened(0.25 * g)
					if (x >= 4 and x < 8) or (x >= 120 and x < 124):
						couleur = teintes[2]
					elif x >= 62 and x < 66 and y < 64:
						couleur = teintes[3]
				"bois":
					couleur = Color("#c58b4e").darkened(0.2 * g)
					if y % 32 < 3 or x < 3 or x > 124:
						couleur = Color("#6d4423")  # les fentes entre les planches
				"damier":
					couleur = teintes[((x >> 6) + (y >> 6)) % 2]
				_:
					couleur = teintes[0].lerp(teintes[1], g)
					if (x * 7 + y * 13) % 29 == 0:
						couleur = couleur.lightened(0.12)  # des petits points plus clairs
			image.set_pixel(x, y, couleur)
	image.generate_mipmaps()
	textures[cle] = ImageTexture.create_from_image(image)
	return textures[cle]


func _matiere_texture(cle: String, sorte: String, couleurs: Array, grain := 0.1, repetition := Vector3.ONE) -> StandardMaterial3D:
	var matiere := StandardMaterial3D.new()
	matiere.albedo_texture = _texture(cle, sorte, couleurs, grain)
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
	for p in pas_de_raccourci:
		if Vector2(p.x, p.z).distance_to(ou) < LARGEUR_RACCOURCI / 2.0 + marge:
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
	for i in 4:
		_cagette(r.origin + r.basis.x * (i - 1.5) * largeur / 5.0 + r.basis.y * 1.0)


func _cagette(ou: Vector3) -> void:
	var caisse := BoxMesh.new()
	caisse.size = Vector3.ONE * 1.1
	var cagette := Node3D.new()
	cagette.position = ou
	add_child(cagette)
	_objet(caisse, _matiere_texture("bois", "bois", []), Vector3.ZERO, Vector3.ONE, cagette)
	for j in 4:
		var fruit := _matiere(FRUITS[(cagettes.size() + j) % FRUITS.size()])
		_objet(_boule(0.3), fruit, Vector3((j % 2 - 0.5) * 0.5, 0.6, (j >> 1) * 0.5 - 0.25), Vector3.ONE, cagette)
	cagettes.append(cagette)


# Les anneaux du mode Avions suivent la route, en montant, en descendant et en se décalant.
# Ceux qui sont à la place d'un turbo donnent un turbo, ceux à la place d'un bonus portent des cagettes.
func _anneaux(def: Dictionary) -> void:
	var nombre := maxi(6, int(round(longueur / R.ANNEAUX_ECART)))
	var speciaux := {}  # numéro de l'anneau → "turbo" ou "bonus"
	for sorte in ["bonus", "turbos"]:
		for part in def.get(sorte, []):
			speciaux[int(round((float(part) * longueur - 25.0) / longueur * nombre)) % nombre] = sorte
	var cercle := TorusMesh.new()
	cercle.inner_radius = RAYON_ANNEAU - 0.4
	cercle.outer_radius = RAYON_ANNEAU + 0.4
	cercle.rings = 32
	for k in nombre:
		var d := 25.0 + k * longueur / nombre
		var r := repere(d)
		var centre := r.origin + Vector3.UP * (10.0 + 5.0 * sin(k * 1.7)) + r.basis.x * 4.0 * sin(k * 2.3)
		var turbo: bool = speciaux.get(k, "") == "turbos"
		var matiere := StandardMaterial3D.new()
		matiere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		matiere.albedo_color = Color(R.COULEUR_ANNEAUX[1 if turbo else 0])
		var m := _objet(cercle, matiere, centre)
		m.basis = Basis(r.basis.x, -r.basis.z, r.basis.y)  # debout, face à la route
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		anneaux.append({"centre": centre, "axe": -r.basis.z, "droite": r.basis.x, "distance": d, "turbo": turbo})
		if speciaux.get(k, "") == "bonus":
			for i in 3:
				_cagette(centre + r.basis.x * (i - 1) * 3.0)


# Pose une graine au hasard sur la route (ou la déplace si elle existe déjà).
func semer(graine: Dictionary = {}) -> void:
	if graine.is_empty():
		var forme := _boule(0.75)
		var dore := StandardMaterial3D.new()
		dore.albedo_color = Color("#ffd54f")
		dore.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		graine = {"noeud": _objet(forme, dore, Vector3.ZERO, Vector3(0.7, 1.0, 0.45))}
		graines.append(graine)
	graine["distance"] = randf() * longueur
	graine["voie"] = randf_range(-0.4, 0.4) * largeur
	var r := repere(graine["distance"])
	graine["noeud"].position = r.origin + r.basis.x * graine["voie"] + r.basis.y * 1.1
	graine["noeud"].visible = true


# Les obstacles. En kart : aux endroits écrits dans "obstacles" (une fois sur deux, deux obstacles
# qui ne bougent pas, sinon un obstacle qui traverse la route). En avion : entre deux anneaux.
func _obstacles(def: Dictionary, aerien: bool, decorateur: RefCounted, decor: String) -> void:
	if aerien:
		var pas: int = 1 if regle == "obstacles" else R.OBSTACLES_AVIONS
		for k in range(1, anneaux.size(), pas):
			var a: Dictionary = anneaux[k]
			var b: Dictionary = anneaux[(k + 1) % anneaux.size()]
			var monte := (k / pas) % 2 == 0  # une fois de haut en bas, une fois de gauche à droite
			_obstacle(decorateur, decor, (a["centre"] + b["centre"]) / 2.0, Vector3.UP if monte else a["droite"], 4.0, a["distance"], 0.0, not monte)
		return
	var occupes: Array = def.get("turbos", []) + def.get("tremplins", []) + def.get("bonus", [])
	var numero := 0
	var endroits: Array = def.get("obstacles", [0.3, 0.5, 0.7, 0.9])
	if regle == "obstacles":
		endroits = endroits + endroits.map(func(e): return fposmod(e + 0.1, 1.0))
	for part in endroits:
		# On décale un obstacle qui tomberait sur un turbo, un tremplin ou des cagettes.
		var ou: float = part
		for autre in occupes:
			if absf(ou - autre) < 0.03:
				ou = autre + 0.045
		var r := repere(ou * longueur)
		var base := r.origin + r.basis.y * 1.3
		if numero % 2 == 0:
			for voie in [-largeur * 0.24, largeur * 0.28]:
				_obstacle(decorateur, decor, base + r.basis.x * voie, r.basis.x, 0.0, ou * longueur, voie, true)
		else:
			_obstacle(decorateur, decor, base, r.basis.x, largeur / 2.0 - 2.4, ou * longueur, 0.0, true)
		numero += 1
	# Un obstacle qui va et vient au milieu de chaque raccourci : il faut le mériter !
	for raccourci in raccourcis:
		var milieu := _repere_de(raccourci["courbe"], raccourci["longueur"] / 2.0)
		_obstacle(decorateur, decor, milieu.origin + Vector3.UP * 1.3, milieu.basis.x, LARGEUR_RACCOURCI / 2.0 - 1.9, 0.0, 999.0, false)


func _obstacle(decorateur: RefCounted, decor: String, base: Vector3, axe: Vector3, amplitude: float, distance: float, voie: float, en_travers: bool) -> void:
	var noeud: Node3D = decorateur.obstacle(decor)
	noeud.position = base
	add_child(noeud)
	obstacles.append({"noeud": noeud, "base": base, "axe": axe, "amplitude": amplitude, "phase": obstacles.size() * 1.9,
		"distance": distance, "voie_de_base": voie, "voie": voie, "en_travers": en_travers})


# ── Le décor ─────────────────────────────────────────────────

func _ciel_et_lumiere() -> void:
	var ciel := Sky.new()
	var bleu := ProceduralSkyMaterial.new()
	bleu.sky_top_color = Color(ambiance["ciel"][0])
	bleu.sky_horizon_color = Color(ambiance["ciel"][1])
	bleu.ground_horizon_color = Color(ambiance["ciel"][1])
	bleu.ground_bottom_color = Color(ambiance["ciel"][0] if ambiance["sol"].is_empty() else ambiance["sol"][0])
	bleu.sun_angle_max = 0.0 if ambiance["soleil"] <= 0.0 else 30.0
	ciel.sky_material = bleu
	var air := Environment.new()
	air.background_mode = Environment.BG_SKY
	air.sky = ciel
	air.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	air.ambient_light_color = Color(ambiance["lumiere"][0])
	air.ambient_light_energy = ambiance["lumiere"][1]
	air.ambient_light_sky_contribution = 0.0
	if ambiance["brume"][1] > 0.0:
		air.fog_enabled = true
		air.fog_light_color = Color(ambiance["brume"][0])
		air.fog_density = ambiance["brume"][1]
		air.fog_sky_affect = 0.3
	var monde := WorldEnvironment.new()
	monde.environment = air
	add_child(monde)

	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-55, 35, 0)
	soleil.shadow_enabled = true
	soleil.light_energy = ambiance["soleil"]
	soleil.visible = ambiance["soleil"] > 0.0
	soleil.directional_shadow_max_distance = 120.0
	add_child(soleil)


func _sol() -> void:
	if ambiance["sol"].is_empty():
		return  # le vide : un kart qui tombe est reposé sur la piste
	var pre := PlaneMesh.new()
	pre.size = Vector2(2000, 2000)
	pre.subdivide_width = 100  # découpé en petits carrés, sinon le brouillard le recouvre d'un coup
	pre.subdivide_depth = 100
	if ambiance["sol_dessine"]:
		_objet(pre, _matiere_texture("sol-" + str(ambiance["sol"]), "bruit", ambiance["sol"], ambiance["sol_grain"], Vector3(250, 250, 1)), Vector3(0, -0.3, 0))
	var forme := BoxShape3D.new()
	forme.size = Vector3(2000, 1, 2000)
	_solide(forme, Transform3D(Basis.IDENTITY, Vector3(0, -0.8, 0)), "herbe")


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
