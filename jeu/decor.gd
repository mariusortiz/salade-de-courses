# Les décors. Chaque circuit choisit le sien avec "decor" (voir donnees/circuits.gd).
# Un décor, c'est une ambiance (les couleurs, la lumière, la gravité...) dans AMBIANCES,
# et une fonction du même nom, plus bas, qui pose les objets autour de la route.
extends RefCounted

const R = preload("res://donnees/reglages.gd")
const Fruit = preload("res://jeu/fruit.gd")

const FRUITS = ["#e53935", "#fb8c00", "#fdd835", "#8e24aa", "#d81b60", "#7cb342"]

# Ce qu'on peut régler dans une ambiance (tout ce qui manque est pris dans "campagne") :
#   ciel        la couleur du ciel en haut, puis à l'horizon
#   sol         les deux couleurs mélangées du sol, ou [] s'il n'y a pas de sol (le vide !)
#   sol_grain   petit = grandes taches, grand = petits grains (sol_dessine : false = le décor dessine le sol lui-même)
#   route       les deux couleurs du bitume        lignes     les bords, puis les pointillés
#   barrieres   les deux couleurs des barrières
#   soleil      la force du soleil (0 = nuit)      lumiere    la couleur et la force de la lumière partout
#   brume       la couleur et l'épaisseur du brouillard (0 = pas de brouillard)
#   gravite     1 = normale, 0.5 = on flotte       adherence  1 = normale, 0.4 = ça glisse
#   arc_en_ciel true = la route change de couleur tout le long
#   tribunes    true = des tribunes au départ
const AMBIANCES = {
	"campagne": {
		"ciel": R.COULEUR_CIEL, "sol": R.COULEUR_HERBE, "sol_grain": 0.05, "sol_dessine": true,
		"route": R.COULEUR_ROUTE, "lignes": R.COULEUR_LIGNES, "barrieres": R.COULEUR_BARRIERES,
		"soleil": 1.0, "lumiere": ["#dbe9ff", 0.75], "brume": ["#ffffff", 0.0],
		"gravite": 1.0, "adherence": 1.0, "arc_en_ciel": false, "tribunes": true,
	},
	"espace": {
		"ciel": ["#02030a", "#0b0a24"], "sol": [],
		"route": ["#2a2350", "#342b63"], "lignes": ["#40e0ff", "#ff5cf4"], "barrieres": ["#40e0ff", "#7b5cff"],
		"soleil": 0.9, "lumiere": ["#b9b4ff", 0.7], "gravite": 0.6, "tribunes": false,
	},
	"montagne": {
		"ciel": ["#2f7fd6", "#c4e3fb"], "sol": ["#467538", "#6f9659"],
		"route": ["#6b6f78", "#5d616a"], "barrieres": ["#f5f5f5", "#c62828"],
		"brume": ["#e8f4ff", 0.0005], "lumiere": ["#dbe9ff", 0.6],
	},
	"grotte": {
		"ciel": ["#050308", "#0a0612"], "sol": ["#2a2433", "#3b3346"], "sol_grain": 0.12,
		"route": ["#8f8f9c", "#7c7c8a"], "lignes": ["#ffffff", "#ffffff"], "barrieres": ["#b8b8c6", "#8d8d9c"],
		"soleil": 0.0, "lumiere": ["#c9beff", 0.6], "brume": ["#0a0612", 0.0025],
		"arc_en_ciel": true, "tribunes": false,
	},
	"pizza": {
		"ciel": ["#f4b860", "#ffe9c4"], "sol": ["#f2c14e", "#f7dc8b"], "sol_grain": 0.09,
		"route": ["#c0392b", "#a93226"], "lignes": ["#ffe9a8", "#ffe9a8"], "barrieres": ["#d9a05b", "#b9773a"],
		"lumiere": ["#fff1d6", 0.85], "sol_dessine": false,
	},
	"aquarium": {
		"ciel": ["#0a4f7a", "#2aa5c9"], "sol": ["#a8915c", "#c4ae78"], "sol_grain": 0.1,
		"route": ["#2f6f8f", "#28627f"], "lignes": ["#bff3ff", "#ffe082"], "barrieres": ["#ff8a65", "#fff3e0"],
		"soleil": 0.5, "lumiere": ["#9fe3ff", 0.6], "brume": ["#1f8fb5", 0.007],
		"gravite": 0.8, "tribunes": false,
	},
	"frigo": {
		"ciel": ["#9fcbe6", "#d6ecf7"], "sol": ["#7fb2cf", "#a5cde2"], "sol_grain": 0.03,
		"route": ["#5f93b3", "#5487a7"], "lignes": ["#ffffff", "#1e88e5"], "barrieres": ["#1e88e5", "#ffffff"],
		"soleil": 0.4, "lumiere": ["#eaf6ff", 0.5], "brume": ["#e3f2fa", 0.0012],
		"adherence": 0.4, "tribunes": false,
	},
	"potager": {
		"ciel": ["#3f8fe0", "#cfeaff"], "sol": ["#6b4a2e", "#84603d"], "sol_grain": 0.08,
		"route": ["#8a8f7a", "#7d826e"], "barrieres": ["#8d5a2b", "#c9925a"],
	},
}

var p: Node3D                 # la piste qu'on décore
var h: RandomNumberGenerator  # le hasard de la piste (toujours le même décor)


static func ambiance(nom: String) -> Dictionary:
	var a: Dictionary = AMBIANCES["campagne"].duplicate()
	a.merge(AMBIANCES.get(nom, {}), true)
	return a


func planter(piste: Node3D, nom: String) -> void:
	p = piste
	h = piste.hasard
	if has_method(nom):
		call(nom)
	else:
		push_warning("Décor inconnu : %s. On met la campagne." % nom)
		campagne()


# ── Les décors ───────────────────────────────────────────────

func campagne() -> void:
	_arbres(R.NOMBRE_ARBRES, [0, 1, 2])
	_rochers(R.NOMBRE_ROCHERS)
	_buissons(R.NOMBRE_BUISSONS)
	_fleurs()
	_bottes_de_paille()
	_collines(Color(R.COULEUR_HERBE[0]).darkened(0.1))
	_nuages()
	_montgolfieres()


func espace() -> void:
	# Les étoiles, tout autour.
	var etoiles = MultiMesh.new()
	etoiles.transform_format = MultiMesh.TRANSFORM_3D
	etoiles.mesh = p._boule(1.0)
	etoiles.instance_count = 700
	for i in 700:
		var direction = Vector3(h.randfn(), h.randfn(), h.randfn()).normalized()
		etoiles.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * h.randf_range(0.5, 1.6)), _milieu() + direction * 480.0))
	var ciel = MultiMeshInstance3D.new()
	ciel.multimesh = etoiles
	ciel.material_override = _lumineux(Color.WHITE)
	p.add_child(ciel)

	# Quatre planètes, dont une avec un anneau.
	var couleurs = ["#e07a3f", "#4fb3d9", "#c9a0ff", "#7bd67b"]
	for i in 4:
		var angle = i * TAU / 4.0 + 0.6
		var rayon = h.randf_range(35, 65)
		var ou = _milieu() + Vector3(cos(angle) * 330.0, h.randf_range(-60, 120), sin(angle) * 330.0)
		p._objet(p._boule(1.0), p._matiere(couleurs[i]), ou, Vector3.ONE * rayon)
		if i == 0:
			var anneau = TorusMesh.new()
			anneau.inner_radius = 1.4
			anneau.outer_radius = 2.1
			var m: MeshInstance3D = p._objet(anneau, p._matiere("#f3d9a4"), ou, Vector3(rayon, rayon * 0.05, rayon))
			m.rotation.z = 0.4

	# Des astéroïdes qui flottent près de la route, et d'autres qui tournent autour du circuit.
	var gris = [p._matiere("#8a8f98"), p._matiere("#6b5f58")]
	for b in _bords(60, 4.0, 30.0):
		var taille = h.randf_range(0.8, 3.5)
		p._objet(p._boule(1.0), gris[h.randi_range(0, 1)], b[0] + Vector3(0, h.randf_range(-8, 8), 0), Vector3(1.3, 0.9, 1.0) * taille)
	for i in 8:
		var m: MeshInstance3D = p._objet(p._boule(1.0), gris[i % 2], Vector3.ZERO, Vector3(5, 3.5, 4) * h.randf_range(0.6, 1.5))
		p.animes.append({"noeud": m, "centre": _milieu() + Vector3(0, h.randf_range(15, 45), 0), "rayon": h.randf_range(60, 150), "vitesse": h.randf_range(0.03, 0.1), "angle": h.randf() * TAU})

	# Deux fusées garées près du départ.
	for cote: float in [-1.0, 1.0]:
		var fusee = Node3D.new()
		fusee.transform = p.repere(18.0).translated_local(Vector3(cote * (p.largeur / 2.0 + 14.0), -4.0, 0))
		p.add_child(fusee)
		p._objet(p._cylindre(2.5, 2.5, 14.0), p._matiere("#f5f5f5"), Vector3(0, 9, 0), Vector3.ONE, fusee)
		p._objet(p._cylindre(0.0, 2.5, 5.0), p._matiere("#e53935"), Vector3(0, 18.5, 0), Vector3.ONE, fusee)
		p._objet(p._cylindre(1.6, 2.6, 2.0), p._matiere("#455a64"), Vector3(0, 1.0, 0), Vector3.ONE, fusee)
		p._objet(p._boule(1.1), p._matiere("#4fc3f7"), Vector3(0, 12, -2.0), Vector3.ONE, fusee)
		for i in 3:
			var aile: MeshInstance3D = p._objet(p._cylindre(0.0, 2.2, 5.0), p._matiere("#e53935"), Vector3(cos(i * TAU / 3.0) * 3.0, 3.5, sin(i * TAU / 3.0) * 3.0), Vector3(1, 1, 0.3), fusee)
			aile.rotation.y = -i * TAU / 3.0 + PI / 2.0


func montagne() -> void:
	# La grande montagne au milieu du circuit, avec sa neige au sommet.
	var roche = p._matiere_texture("roche", "bruit", ["#6f7480", "#9aa0ab"], 0.15, Vector3(8, 6, 1))
	var neige = p._matiere("#ffffff")
	_pic(_milieu(), 46.0, 95.0, roche, neige)
	for i in 10:
		var angle = i * TAU / 10.0 + h.randf_range(-0.2, 0.2)
		var loin = maxf(p.zone.size.x, p.zone.size.y) / 2.0 + h.randf_range(170, 260)
		_pic(_milieu() + Vector3(cos(angle) * loin, 0, sin(angle) * loin), h.randf_range(80, 140), h.randf_range(110, 200), roche, neige)

	_arbres(170, [1])
	_rochers(60)
	for ou in _places(40, 4.0):
		p._objet(p._boule(1.0), neige, ou, Vector3(h.randf_range(3, 7), 0.5, h.randf_range(3, 6)))  # des plaques de neige

	# Trois chalets.
	var toit = PrismMesh.new()
	toit.size = Vector3(8.5, 3.5, 9.0)
	for ou in _places(3, 9.0):
		var chalet = Node3D.new()
		chalet.position = ou
		chalet.rotation.y = h.randf() * TAU
		p.add_child(chalet)
		p._objet(_boite(Vector3(7, 4.5, 8)), p._matiere_texture("bois", "bois", []), Vector3(0, 2.25, 0), Vector3.ONE, chalet)
		p._objet(toit, p._matiere("#b03a2e"), Vector3(0, 6.2, 0), Vector3.ONE, chalet)
		p._objet(_boite(Vector3(1.5, 2.4, 0.2)), p._matiere("#5d4037"), Vector3(0, 1.2, 4.05), Vector3.ONE, chalet)
	_nuages()


func grotte() -> void:
	var roche = p._matiere_texture("roche-sombre", "bruit", ["#2a2433", "#4a4058"], 0.12, Vector3(4, 4, 1))
	# Le plafond, avec ses stalactites qui pendent.
	var plafond = PlaneMesh.new()
	plafond.size = Vector2(1200, 1200)
	var m: MeshInstance3D = p._objet(plafond, p._matiere("#17121f"), _milieu() + Vector3(0, 42, 0))
	m.rotation.x = PI
	for i in 110:
		var ou = p._au_hasard_dans_la_zone()
		var long = h.randf_range(6, 18)
		p._objet(p._cylindre(h.randf_range(1.2, 3.0), 0.0, long), roche, Vector3(ou.x, 42.0 - long / 2.0, ou.y))
	# Les stalagmites qui montent du sol.
	for ou in _places(70, 3.0):
		var haut = h.randf_range(3, 10)
		p._objet(p._cylindre(0.0, h.randf_range(1.0, 2.4), haut), roche, ou + Vector3(0, haut / 2.0, 0))
	_rochers(40)

	# Les cristaux de toutes les couleurs. Ils brillent, et certains éclairent vraiment.
	var cristal = p._cylindre(0.0, 0.7, 3.5)
	cristal.radial_segments = 6
	var n = 0
	for b in _bords(150, 1.6, 9.0):
		var couleur = Color.from_hsv(fposmod(b[1] / p.longueur * 3.0, 1.0), 0.75, 1.0)
		var matiere = _lumineux(couleur)
		for j in 3:
			var c: MeshInstance3D = p._objet(cristal, matiere, b[0] + Vector3(j * 1.3 - 1.3, 2.2 + (j % 2) * 1.0, (j % 2) * 1.1), Vector3.ONE * h.randf_range(1.2, 2.6))
			c.rotation = Vector3(h.randf_range(-0.4, 0.4), 0, h.randf_range(-0.4, 0.4))
		n += 1
		if n % 4 == 0:
			var lampe = OmniLight3D.new()
			lampe.light_color = couleur
			lampe.light_energy = 2.0
			lampe.omni_range = 24.0
			lampe.position = b[0] + Vector3(0, 3.5, 0)
			p.add_child(lampe)
	# De gros cristaux au loin.
	for ou in _places(30, 12.0):
		var c: MeshInstance3D = p._objet(cristal, _lumineux(Color.from_hsv(h.randf(), 0.7, 1.0)), ou + Vector3(0, 4, 0), Vector3.ONE * h.randf_range(2.5, 5.0))
		c.rotation = Vector3(h.randf_range(-0.5, 0.5), 0, h.randf_range(-0.5, 0.5))


func pizza() -> void:
	# La nappe à carreaux, la pizza posée dessus, et sa croûte tout autour.
	var rayon = p.zone.size.length() / 2.0
	var nappe = PlaneMesh.new()
	nappe.size = Vector2(4000, 4000)
	p._objet(nappe, p._matiere_texture("nappe", "damier", ["#d32f2f", "#fafafa"], 0.0, Vector3(160, 160, 1)), Vector3(0, -1.6, 0))
	p._objet(p._cylindre(rayon, rayon, 1.3), p._matiere_texture("fromage", "bruit", p.ambiance["sol"], 0.09, Vector3(60, 60, 1)), _milieu() + Vector3(0, -0.95, 0))
	var bord = TorusMesh.new()
	bord.inner_radius = rayon - 5.0
	bord.outer_radius = rayon + 7.0
	bord.rings = 48
	p._objet(bord, p._matiere_texture("croute", "bruit", ["#b9773a", "#e0b070"], 0.2, Vector3(40, 3, 1)), _milieu() + Vector3(0, -0.5, 0), Vector3(1, 0.6, 1))

	# La garniture.
	var rouge = p._matiere("#a8322a")
	var noir = p._matiere("#1f1f24")
	var beige = p._matiere("#efe2c8")
	var vert = p._matiere("#2e8b3d")
	var olive = TorusMesh.new()
	olive.inner_radius = 0.5
	olive.outer_radius = 1.5
	for ou in _places(34, 5.0):
		p._objet(p._cylindre(1.0, 1.0, 0.35), rouge, ou + Vector3(0, 0.15, 0), Vector3(1, 1, 1) * h.randf_range(2.5, 4.5) * Vector3(1, 0.3, 1))
	for ou in _places(40, 2.5):
		p._objet(olive, noir, ou + Vector3(0, 0.7, 0))
	for ou in _places(26, 3.0):
		var champignon = Node3D.new()
		champignon.position = ou
		champignon.rotation = Vector3(h.randf_range(-0.3, 0.3), h.randf() * TAU, 1.2)
		p.add_child(champignon)
		p._objet(p._boule(2.2), beige, Vector3(0, 2.4, 0), Vector3(1, 0.55, 1), champignon)
		p._objet(p._cylindre(0.7, 0.9, 2.4), beige, Vector3(0, 1.2, 0), Vector3.ONE, champignon)
	for ou in _places(40, 2.5):
		var feuille: MeshInstance3D = p._objet(p._boule(1.0), vert, ou + Vector3(0, 0.15, 0), Vector3(3.2, 0.12, 1.8))
		feuille.rotation.y = h.randf() * TAU
	for ou in _places(22, 3.0):
		p._objet(p._boule(1.7), p._matiere("#e53935"), ou + Vector3(0, 1.3, 0))

	# Sur la table : la salière, la poivrière et un grand verre.
	for i in 3:
		var angle = 0.7 + i * 2.1
		var ou = _milieu() + Vector3(cos(angle), 0, sin(angle)) * (rayon + 70.0)
		if i == 2:
			var verre: MeshInstance3D = p._objet(p._cylindre(28, 22, 90), _verre(Color(0.8, 0.95, 1.0, 0.3)), ou + Vector3(0, 43, 0))
			verre.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			p._objet(p._cylindre(14, 18, 60), p._matiere("#fafafa" if i == 0 else "#4e342e"), ou + Vector3(0, 28, 0))
			p._objet(p._boule(15), p._matiere("#b0bec5"), ou + Vector3(0, 60, 0), Vector3(1, 0.7, 1))


func aquarium() -> void:
	# La surface de l'eau, tout en haut, et les quatre vitres.
	var surface = PlaneMesh.new()
	surface.size = p.zone.size
	var eau: MeshInstance3D = p._objet(surface, _verre(Color(0.75, 0.95, 1.0, 0.55)), _milieu() + Vector3(0, 55, 0))
	eau.rotation.x = PI
	for i in 4:
		var long = p.zone.size.x if i < 2 else p.zone.size.y
		var ecart: float = (p.zone.size.y if i < 2 else p.zone.size.x) / 2.0
		var signe = 1.0 if i % 2 == 0 else -1.0
		var ou = _milieu() + (Vector3(0, 27, ecart * signe) if i < 2 else Vector3(ecart * signe, 27, 0))
		var vitre: MeshInstance3D = p._objet(_boite(Vector3(long, 56, 0.5)), _verre(Color(0.7, 0.95, 1.0, 0.18)), ou)
		vitre.rotation.y = 0.0 if i < 2 else PI / 2.0
		vitre.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			p._objet(_boite(Vector3(2, 58, 2)), p._matiere("#263238"), _milieu() + Vector3(x * p.zone.size.x / 2.0, 28, z * p.zone.size.y / 2.0))

	# Les algues, les coraux et les rochers.
	var algue = Fruit._capsule(0.35, 3.2)
	var verts = [p._matiere("#2e9e5b"), p._matiere("#1f7a4d"), p._matiere("#58b368")]
	for ou in _places(130, 1.5):
		var brins = h.randi_range(2, 4)
		for j in brins:
			var base: Vector3 = ou + Vector3(j * 0.7, 0, (j % 2) * 0.6)
			for etage in h.randi_range(2, 4):
				var brin: MeshInstance3D = p._objet(algue, verts[(j + etage) % 3], base + Vector3(sin(etage * 1.3 + j) * 0.5, 1.5 + etage * 2.6, 0))
				brin.rotation.z = sin(etage * 1.3 + j) * 0.35
	var teintes = ["#ff6f91", "#ff9671", "#c77dff", "#ffd166", "#f15bb5"]
	for ou in _places(60, 2.5):
		var teinte = p._matiere(teintes[h.randi_range(0, 4)])
		var taille = h.randf_range(0.8, 2.0)
		for j in 6:
			var bout: Vector3 = ou + Vector3(cos(j * 1.05) * 1.6, 2.0 + (j % 3) * 0.9, sin(j * 1.05) * 1.6) * taille
			Fruit._membre(p, ou, bout, 0.35 * taille, teinte)
			p._objet(p._boule(0.55 * taille), teinte, bout)
	_rochers(35)

	# Les bulles montent, les poissons tournent en rond.
	var savon = _verre(Color(0.9, 1.0, 1.0, 0.35))
	for i in 70:
		var ou = p._au_hasard_dans_la_zone()
		var bulle: MeshInstance3D = p._objet(p._boule(h.randf_range(0.25, 0.8)), savon, Vector3(ou.x, h.randf_range(0, 55), ou.y))
		bulle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.animes.append({"noeud": bulle, "monte": h.randf_range(2.0, 5.0), "plafond": 55.0})
	for i in 16:
		var poisson = Node3D.new()
		var peau = p._matiere(["#ff7043", "#ffca28", "#42a5f5", "#ec407a", "#7e57c2"][i % 5])
		var taille = h.randf_range(1.0, 3.0)
		p.add_child(poisson)
		p._objet(p._boule(1.0), peau, Vector3.ZERO, Vector3(0.6, 1.0, 2.0) * taille, poisson)
		var queue: MeshInstance3D = p._objet(p._cylindre(0.0, 1.0, 1.6), peau, Vector3(0, 0, 2.5) * taille, Vector3(0.25, 1, 1) * taille, poisson)
		queue.rotation.x = -PI / 2.0
		for x: float in [-1.0, 1.0]:
			p._objet(p._boule(0.22), p._matiere("#ffffff"), Vector3(x * 0.5, 0.3, -1.2) * taille, Vector3.ONE * taille, poisson)
			p._objet(p._boule(0.11), p._matiere("#111111"), Vector3(x * 0.6, 0.3, -1.3) * taille, Vector3.ONE * taille, poisson)
		var centre = p._au_hasard_dans_la_zone()
		p.animes.append({"noeud": poisson, "centre": Vector3(centre.x, h.randf_range(8, 30), centre.y), "rayon": h.randf_range(15, 50), "vitesse": h.randf_range(0.1, 0.3), "angle": h.randf() * TAU})

	# Le château et le coffre au trésor, comme dans tous les aquariums.
	for ou in _places(1, 18.0):
		var pierre = p._matiere("#b0a08a")
		p._objet(_boite(Vector3(18, 9, 4)), pierre, ou + Vector3(0, 4.5, 0))
		for x: float in [-1.0, 1.0]:
			p._objet(p._cylindre(3.5, 3.5, 16), pierre, ou + Vector3(x * 10.0, 8, 0))
			p._objet(p._cylindre(0.0, 4.5, 7), p._matiere("#c0392b"), ou + Vector3(x * 10.0, 19.5, 0))
		p._objet(_boite(Vector3(3.5, 5, 4.4)), p._matiere("#3e2723"), ou + Vector3(0, 2.5, 0))
	for ou in _places(2, 8.0):
		p._objet(_boite(Vector3(6, 3.5, 4)), p._matiere_texture("bois", "bois", []), ou + Vector3(0, 1.75, 0))
		for j in 8:
			p._objet(p._boule(0.6), _lumineux(Color("#ffd54f")), ou + Vector3(j * 0.7 - 2.4, 3.7, (j % 3) * 0.8 - 0.8))


func frigo() -> void:
	# Les parois du frigo : le fond, les deux côtés, et l'étagère du dessus.
	var blanc = p._matiere("#c3d2dc")
	var demi = p.zone.size / 2.0
	p._objet(_boite(Vector3(demi.x * 2.0 + 20, 140, 6)), blanc, _milieu() + Vector3(0, 60, -demi.y - 10))
	for x: float in [-1.0, 1.0]:
		p._objet(_boite(Vector3(6, 140, demi.y * 2.0 + 20)), blanc, _milieu() + Vector3(x * (demi.x + 10), 60, 0))
	var etagere: MeshInstance3D = p._objet(_boite(Vector3(demi.x * 2.0 + 20, 1.5, demi.y * 2.0 + 20)), _verre(Color(0.85, 0.95, 1.0, 0.35)), _milieu() + Vector3(0, 110, 0))
	etagere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Des glaçons un peu partout.
	var glace = _verre(Color(0.7, 0.92, 1.0, 0.55))
	for ou in _places(45, 3.0):
		var taille = h.randf_range(2.5, 5.0)
		var cube: MeshInstance3D = p._objet(_boite(Vector3.ONE), glace, ou + Vector3(0, taille * 0.45, 0), Vector3.ONE * taille)
		cube.rotation = Vector3(h.randf_range(-0.2, 0.2), h.randf() * TAU, h.randf_range(-0.2, 0.2))

	# Les pots de yaourt, avec leur couvercle de couleur.
	for ou in _places(14, 7.0):
		p._objet(p._cylindre(4.5, 3.5, 9.0), blanc, ou + Vector3(0, 4.5, 0))
		p._objet(p._cylindre(4.8, 4.8, 0.4), p._matiere(FRUITS[h.randi_range(0, 5)]), ou + Vector3(0, 9.2, 0))
	# Les œufs.
	for ou in _places(12, 5.0):
		p._objet(p._boule(1.0), p._matiere("#f3e3c7"), ou + Vector3(0, 3.6, 0), Vector3(3.0, 4.0, 3.0))
	# Le beurre sur son assiette, le fromage à trous et la bouteille de lait.
	for ou in _places(2, 12.0):
		p._objet(p._cylindre(13, 11, 0.8), blanc, ou + Vector3(0, 0.4, 0))
		p._objet(_boite(Vector3(16, 5, 8)), p._matiere("#ffe082"), ou + Vector3(0, 3.3, 0))
	var part = PrismMesh.new()
	part.size = Vector3(16, 9, 12)
	part.left_to_right = 0.0
	for ou in _places(3, 12.0):
		var fromage: MeshInstance3D = p._objet(part, p._matiere("#ffca28"), ou + Vector3(0, 4.5, 0))
		fromage.rotation.y = h.randf() * TAU
		for j in 6:
			p._objet(p._boule(1.1), p._matiere("#e0a800"), ou + Vector3(cos(j * 1.1) * 4.0, 2.0 + j * 0.7, sin(j * 1.1) * 4.0))
	for ou in _places(3, 10.0):
		p._objet(p._cylindre(6, 6, 26), blanc, ou + Vector3(0, 13, 0))
		p._objet(p._cylindre(2.5, 6, 6), blanc, ou + Vector3(0, 29, 0))
		p._objet(p._cylindre(2.8, 2.8, 2.5), p._matiere("#1e88e5"), ou + Vector3(0, 33, 0))


func potager() -> void:
	var vert = p._matiere("#3fa34d")
	var fonce = p._matiere("#2f7d3a")
	var fane = Fruit._capsule(0.3, 5.0)
	# Les carottes : on ne voit que le haut, et les fanes.
	for ou in _places(34, 3.0):
		p._objet(p._cylindre(1.7, 1.4, 1.6), p._matiere("#f57c00"), ou + Vector3(0, 0.6, 0))
		for j in 6:
			var f: MeshInstance3D = p._objet(fane, vert if j % 2 == 0 else fonce, ou + Vector3(cos(j * 1.05) * 0.9, 3.4, sin(j * 1.05) * 0.9))
			f.rotation = Vector3(sin(j * 1.05) * 0.35, 0, -cos(j * 1.05) * 0.35)
	# Les citrouilles.
	for ou in _places(16, 5.0):
		var taille = h.randf_range(2.5, 4.5)
		for j in 5:
			var tranche: MeshInstance3D = p._objet(p._boule(1.0), p._matiere("#ef6c00" if j % 2 == 0 else "#f57c00"), ou + Vector3(0, taille * 0.75, 0), Vector3(0.75, 0.8, 1.0) * taille)
			tranche.rotation.y = j * PI / 5.0
		p._objet(p._cylindre(0.3, 0.45, 1.4), fonce, ou + Vector3(0, taille * 1.6, 0))
	# Les choux.
	for ou in _places(24, 3.5):
		p._objet(p._boule(2.4), p._matiere("#8bc34a"), ou + Vector3(0, 2.0, 0))
		for j in 6:
			var feuille: MeshInstance3D = p._objet(p._boule(2.2), fonce if j % 2 == 0 else vert, ou + Vector3(cos(j * 1.05) * 1.8, 1.2, sin(j * 1.05) * 1.8), Vector3(1.0, 0.8, 0.3))
			feuille.rotation.y = -j * 1.05 + PI / 2.0
	# Les pieds de tomates, avec leur tuteur.
	for ou in _places(18, 3.5):
		p._objet(p._cylindre(0.2, 0.2, 10.0), p._matiere("#8d6e63"), ou + Vector3(0, 5, 0))
		for j in 5:
			p._objet(p._boule(1.6), fonce if j % 2 == 0 else vert, ou + Vector3(cos(j * 2.4) * 0.9, 2.0 + j * 1.5, sin(j * 2.4) * 0.9))
			p._objet(p._boule(0.8), p._matiere("#e53935"), ou + Vector3(cos(j * 2.4 + 1.5) * 1.9, 2.4 + j * 1.5, sin(j * 2.4 + 1.5) * 1.9))
	# Les tournesols.
	for ou in _places(28, 3.0):
		var haut = h.randf_range(8, 12)
		var fleur = Node3D.new()
		fleur.position = ou + Vector3(0, haut, 0)
		fleur.rotation = Vector3(-0.3, h.randf() * TAU, 0)
		p.add_child(fleur)
		p._objet(p._cylindre(0.25, 0.3, haut), vert, ou + Vector3(0, haut / 2.0, 0))
		p._objet(p._cylindre(2.6, 2.6, 0.25), p._matiere("#fdd835"), Vector3(0, 0, 0.1), Vector3.ONE, fleur).rotation.x = PI / 2.0
		p._objet(p._cylindre(1.5, 1.5, 0.5), p._matiere("#5d4037"), Vector3.ZERO, Vector3.ONE, fleur).rotation.x = PI / 2.0
	# Quelques escargots qui regardent passer la course.
	for ou in _places(6, 5.0):
		var escargot = Node3D.new()
		escargot.position = ou
		escargot.rotation.y = h.randf() * TAU
		p.add_child(escargot)
		var corps = p._matiere("#e6cfa3")
		Fruit._membre(escargot, Vector3(0, 0.9, -3.5), Vector3(0, 0.9, 3.0), 0.9, corps)
		p._objet(p._boule(2.6), p._matiere("#a1662f"), Vector3(0, 3.2, 0.8), Vector3(0.7, 1, 1), escargot)
		p._objet(p._boule(1.5), p._matiere("#c98a4b"), Vector3(0, 3.2, 0.8), Vector3(0.85, 1, 1), escargot)
		for x: float in [-1.0, 1.0]:
			Fruit._membre(escargot, Vector3(x * 0.4, 1.4, -3.3), Vector3(x * 0.7, 3.4, -3.9), 0.15, corps)
			p._objet(p._boule(0.35), p._matiere("#222222"), Vector3(x * 0.7, 3.5, -3.9), Vector3.ONE, escargot)
	# Le grand arrosoir.
	for ou in _places(1, 16.0):
		var metal = p._matiere("#4caf93")
		p._objet(p._cylindre(8, 8, 15), metal, ou + Vector3(0, 7.5, 0))
		Fruit._membre(p, ou + Vector3(7, 4, 0), ou + Vector3(18, 15, 0), 1.2, metal)
		p._objet(p._cylindre(3.2, 1.2, 2.5), metal, ou + Vector3(19, 16, 0)).rotation.z = -0.8
		var anse = TorusMesh.new()
		anse.inner_radius = 5.0
		anse.outer_radius = 6.2
		p._objet(anse, metal, ou + Vector3(-8, 9, 0)).rotation.x = PI / 2.0
	_fleurs()
	_collines(Color("#4f9e3a"))
	_nuages()


# ── Les morceaux de décor qui servent plusieurs fois ─────────

# sortes : 0 = arbre rond, 1 = sapin, 2 = arbre fruitier
func _arbres(nombre: int, sortes: Array) -> void:
	var tronc = p._cylindre(0.4, 0.6, 3.0)
	var feuillage = p._boule(2.6)
	var etage = p._cylindre(0.0, 2.2, 3.0)
	var fruit = p._boule(0.35)
	var bois = p._matiere("#7a5230")
	var verts = [p._matiere("#2f8f3a"), p._matiere("#3fa34d"), p._matiere("#267a45")]
	var sapin = p._matiere("#1f6b4a")
	var i = 0
	for ou in _places(nombre, 5.0):
		i += 1
		var sorte: int = sortes[h.randi_range(0, sortes.size() - 1)]
		var arbre = Node3D.new()
		arbre.position = ou
		arbre.scale = Vector3.ONE * h.randf_range(0.8, 1.4)
		arbre.rotation.y = h.randf() * TAU
		p.add_child(arbre)
		p._objet(tronc, bois, Vector3(0, 1.5, 0), Vector3.ONE, arbre)
		if sorte == 1:
			for j in 3:
				p._objet(etage, sapin, Vector3(0, 3.2 + j * 1.6, 0), Vector3.ONE * (1.0 - j * 0.22), arbre)
		else:
			p._objet(feuillage, verts[i % 3], Vector3(0, 4.6, 0), Vector3.ONE, arbre)
			p._objet(feuillage, verts[(i + 1) % 3], Vector3(1.4, 3.8, 0.6), Vector3.ONE * 0.6, arbre)
			if sorte == 2:
				var couleur = p._matiere(FRUITS[h.randi_range(0, 2)])
				for j in 7:
					var direction = Vector3(cos(j * 0.9), 0.3 * sin(j * 2.1), sin(j * 0.9)).normalized()
					p._objet(fruit, couleur, Vector3(0, 4.6, 0) + direction * 2.55, Vector3.ONE, arbre)


func _rochers(nombre: int) -> void:
	var gris = [p._matiere("#8a8f98"), p._matiere("#6f747d")]
	for ou in _places(nombre, 3.0):
		var m: MeshInstance3D = p._objet(p._boule(1.0), gris[h.randi_range(0, 1)], ou, Vector3(1.4, 0.8, 1.0) * h.randf_range(0.6, 2.0))
		m.rotation.y = h.randf() * TAU


func _buissons(nombre: int) -> void:
	var verts = [p._matiere("#3c8d3f"), p._matiere("#56a64b")]
	for ou in _places(nombre, 2.5):
		var taille = h.randf_range(0.7, 1.3)
		for j in 3:
			p._objet(p._boule(1.0), verts[j % 2], ou + Vector3((j - 1) * 0.9 * taille, 0.4, (j % 2) * 0.5), Vector3(1.0, 0.75, 1.0) * taille)


# Des fleurs de toutes les couleurs au bord de la route.
func _fleurs() -> void:
	var fleurs = MultiMesh.new()
	fleurs.transform_format = MultiMesh.TRANSFORM_3D
	fleurs.use_colors = true
	fleurs.mesh = p._boule(0.2)
	var bords = _bords(R.NOMBRE_FLEURS, 1.2, 14.0)
	fleurs.instance_count = bords.size()
	var palette = ["#ffffff", "#ffeb3b", "#ff80ab", "#ff7043", "#b39ddb"]
	for i in bords.size():
		fleurs.set_instance_transform(i, Transform3D(Basis.IDENTITY, bords[i][0] + Vector3(0, 0.1, 0)))
		fleurs.set_instance_color(i, Color(palette[i % palette.size()]))
	var matiere = StandardMaterial3D.new()
	matiere.vertex_color_use_as_albedo = true
	var champ = MultiMeshInstance3D.new()
	champ.multimesh = fleurs
	champ.material_override = matiere
	champ.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(champ)


func _bottes_de_paille() -> void:
	var paille = p._matiere_texture("paille", "bruit", ["#c99f3a", "#e8c35a"], 0.3, Vector3(3, 1, 1))
	for b in _bords(14, 2.2, 2.3):
		var r: Transform3D = p.repere(b[1])
		var m: MeshInstance3D = p._objet(p._cylindre(0.8, 0.8, 1.5), paille, b[0] + Vector3(0, 0.8, 0))
		m.basis = Basis(r.basis.y, -r.basis.z, r.basis.x)  # couchée le long de la route


func _collines(couleur: Color) -> void:
	var rayon = maxf(p.zone.size.x, p.zone.size.y) / 2.0 + 200.0
	var matiere = StandardMaterial3D.new()
	matiere.albedo_color = couleur
	for i in 11:
		var angle = i * TAU / 11.0 + h.randf_range(-0.2, 0.2)
		var taille = Vector3(h.randf_range(110, 190), h.randf_range(25, 70), h.randf_range(110, 190))
		p._objet(p._boule(1.0), matiere, _milieu() + Vector3(cos(angle) * rayon, -2.0, sin(angle) * rayon), taille)


func _nuages() -> void:
	var blanc = StandardMaterial3D.new()
	blanc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in R.NOMBRE_NUAGES:
		var ou = p._au_hasard_dans_la_zone() * 1.8
		var hauteur = h.randf_range(110, 150)
		for j in 4:
			var m: MeshInstance3D = p._objet(p._boule(1.0), blanc, Vector3(ou.x + j * 7.0, hauteur + (j % 2) * 2.0, ou.y), Vector3(9, 4.5, 7) * h.randf_range(0.7, 1.2))
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _montgolfieres() -> void:
	for i in 3:
		var ou = p._au_hasard_dans_la_zone()
		var ballon = Node3D.new()
		ballon.position = Vector3(ou.x, h.randf_range(30, 55), ou.y)
		p.add_child(ballon)
		p._objet(p._boule(6.0), p._matiere(FRUITS[i]), Vector3.ZERO, Vector3(1, 1.15, 1), ballon)
		p._objet(p._cylindre(4.2, 1.2, 5.0), p._matiere(FRUITS[i + 3]), Vector3(0, -6.0, 0), Vector3.ONE, ballon)
		p._objet(p._cylindre(1.0, 0.9, 1.4), p._matiere("#7a5230"), Vector3(0, -10.5, 0), Vector3.ONE, ballon)


# Une montagne pointue avec de la neige en haut.
func _pic(pied: Vector3, rayon: float, hauteur: float, roche: Material, neige: Material) -> void:
	p._objet(p._cylindre(0.0, rayon, hauteur), roche, pied + Vector3(0, hauteur / 2.0 - 0.5, 0))
	p._objet(p._cylindre(0.0, rayon * 0.36, hauteur * 0.35), neige, pied + Vector3(0, hauteur * 0.83, 0))


# ── Les outils ───────────────────────────────────────────────

func _milieu() -> Vector3:
	var c: Vector2 = p.zone.get_center()
	return Vector3(c.x, -0.3, c.y)


# Des endroits au hasard, posés sur le sol et assez loin de la route.
func _places(nombre: int, marge: float) -> Array[Vector3]:
	var places: Array[Vector3] = []
	for i in nombre:
		var ou: Vector2 = p._au_hasard_dans_la_zone()
		if p._libre(ou, marge):
			places.append(Vector3(ou.x, -0.3, ou.y))
	return places


# Des endroits au bord de la route, entre « pres » et « loin » mètres de la barrière.
# Chaque élément contient l'endroit, puis sa distance depuis le départ.
func _bords(nombre: int, pres: float, loin: float) -> Array:
	var bords: Array = []
	var sans_sol: bool = p.ambiance["sol"].is_empty()
	for i in nombre:
		var d: float = h.randf() * p.longueur
		var r: Transform3D = p.repere(d)
		var cote = 1.0 if h.randf() < 0.5 else -1.0
		var ou: Vector3 = r.origin + r.basis.x * cote * (p.largeur / 2.0 + h.randf_range(pres, loin))
		# Sans sol, les objets flottent à la hauteur de la route. Sinon, on ne garde que les endroits où la route est au sol.
		if p._libre(Vector2(ou.x, ou.z), 1.0) and (sans_sol or r.origin.y < 0.5):
			bords.append([Vector3(ou.x, ou.y if sans_sol else -0.3, ou.z), d])
	return bords


func _boite(taille: Vector3) -> BoxMesh:
	var boite = BoxMesh.new()
	boite.size = taille
	return boite


# Une matière qui brille toute seule, même dans le noir.
func _lumineux(couleur: Color) -> StandardMaterial3D:
	var matiere = StandardMaterial3D.new()
	matiere.albedo_color = couleur
	matiere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return matiere


# Une matière transparente : du verre, de l'eau, de la glace.
func _verre(couleur: Color) -> StandardMaterial3D:
	var matiere = StandardMaterial3D.new()
	matiere.albedo_color = couleur
	matiere.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	matiere.roughness = 0.1
	matiere.cull_mode = BaseMaterial3D.CULL_DISABLED
	return matiere
