# Un kart : une boule qui roule vraiment sur la piste (c'est le moteur physique
# qui gère les pentes, les sauts et les chocs), avec le fruit posé dessus.
extends Node3D

signal tire(kart: Node3D)   # le kart lance un pépin
signal verse(kart: Node3D)  # le kart verse une flaque de jus

const R = preload("res://donnees/reglages.gd")
const Fruit = preload("res://jeu/fruit.gd")

const RAYON := 0.9

var pilote: Dictionary
var piste: Node3D
var humain := false
var auto := true          # true = conduit par l'ordinateur
var actif := false        # false pendant le compte à rebours
var commande := Vector2.ZERO  # x = volant (-1 gauche, 1 droite), y = gaz (-1 à 1)
var bouton_derapage := false
var bouton_saut := false
var bouton_tir := false
var bouton_objet := false

var vmax := 30.0
var acceleration := 20.0
var braquage := 2.2

var boule: RigidBody3D
var visuel: Node3D
var cap := 0.0            # direction du kart, en radians
var vitesse := 0.0
var turbo := 0.0
var au_sol := false
var normale := Vector3.UP # l'inclinaison du sol sous le kart
var penche := 0.0

var derapage := 0.0       # 0 = non, -1 = dérapage à gauche, 1 = à droite
var charge := 0.0         # depuis combien de secondes on dérape
var travers := 0.0        # l'angle du kart mis en travers
var etincelles: Array = []
var lueur := StandardMaterial3D.new()

var pepins := 0           # combien de pépins on peut tirer
var objet := ""           # le bonus gardé en réserve : "turbo", "bouclier", "jus" ou "" (rien)
var annonce := ""         # le texte à montrer au joueur quand il ramasse un bonus
var annonce_temps := 0.0
var bouclier := 0.0       # secondes de bouclier qui restent
var toupie := 0.0         # secondes de tête-à-queue qui restent
var englue := 0.0         # secondes de ralentissement dans le jus qui restent
var repos_saut := 0.0
var tir_avant := false
var objet_avant := false
var bulle: MeshInstance3D
var modele: Node3D
var volant_vu := 0.0
var adversaires: Array = []  # tous les karts de la course
var attente_ordi := 3.0

var position_piste := 0.0 # où est le kart sur le tour, en mètres depuis le départ
var distance := 0.0       # distance totale parcourue depuis la ligne de départ
var arrivee := -1.0       # temps à l'arrivée (-1 = pas encore arrivé)
var cote := 0.0           # les ordinateurs ne roulent pas tous au milieu
var temps_perdu := 0.0

# Pour les essais automatiques.
var retours := 0
var vitesse_max := 0.0
var hauteur_max := 0.0


func preparer(le_pilote: Dictionary, la_piste: Node3D, est_humain: bool, vehicule: Dictionary = {}) -> void:
	pilote = le_pilote
	piste = la_piste
	humain = est_humain
	auto = not est_humain

	var niveau := 1.0 if humain else R.NIVEAU_ORDIS * randf_range(0.95, 1.03)
	# Les points du pilote, plus ou moins ceux de son véhicule.
	vmax = (26.0 + (pilote["vitesse"] + vehicule.get("vitesse", 0)) * 1.5) * niveau
	acceleration = 12.0 + (pilote["acceleration"] + vehicule.get("acceleration", 0)) * 4.0
	braquage = 1.5 + (pilote["maniabilite"] + vehicule.get("maniabilite", 0)) * 0.25
	cote = randf_range(-0.3, 0.3) * piste.largeur
	_fabriquer(vehicule)


# Fabrique le corps du kart (la boule qui roule) et son apparence.
func _fabriquer(vehicule: Dictionary) -> void:
	boule = RigidBody3D.new()
	var forme := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RAYON
	forme.shape = sphere
	boule.add_child(forme)
	var glisse := PhysicsMaterial.new()
	glisse.friction = 0.0
	glisse.bounce = 0.0
	boule.physics_material_override = glisse
	boule.gravity_scale = R.GRAVITE * piste.ambiance["gravite"]
	boule.collision_layer = 2    # les karts
	boule.collision_mask = 1 | 2 # se cognent au décor et entre eux
	boule.continuous_cd = true
	add_child(boule)

	visuel = Node3D.new()
	modele = Fruit.creer(pilote, vehicule)
	visuel.add_child(modele)
	add_child(visuel)

	_creer_la_bulle()

	# Les étincelles du dérapage, sous les roues arrière.
	lueur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var etincelle := SphereMesh.new()
	etincelle.radius = 0.22
	etincelle.height = 0.44
	for x in [-0.8, 0.8]:
		var m := MeshInstance3D.new()
		m.mesh = etincelle
		m.material_override = lueur
		m.position = Vector3(x, 0.15, 1.15)
		m.visible = false
		visuel.add_child(m)
		etincelles.append(m)


# La bulle du bouclier.
func _creer_la_bulle() -> void:
	var savon := StandardMaterial3D.new()
	savon.albedo_color = Color(0.5, 0.9, 1.0, 0.35)
	savon.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var sphere_bulle := SphereMesh.new()
	sphere_bulle.radius = 1.9
	sphere_bulle.height = 3.8
	bulle = MeshInstance3D.new()
	bulle.mesh = sphere_bulle
	bulle.material_override = savon
	bulle.position = Vector3(0, 1.0, 0)
	bulle.visible = false
	visuel.add_child(bulle)


# Pose le kart sur la piste, à une distance du départ et décalé sur le côté.
func placer(distance_piste: float, decalage: float) -> void:
	var r: Transform3D = piste.repere(distance_piste)
	var ou := r.origin + r.basis.x * decalage + Vector3.UP * (RAYON + 0.1)
	boule.position = ou
	if boule.is_inside_tree():
		PhysicsServer3D.body_set_state(boule.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.IDENTITY, ou))
	boule.linear_velocity = Vector3.ZERO
	boule.angular_velocity = Vector3.ZERO
	var avant := -r.basis.z
	cap = atan2(-avant.x, -avant.z)
	vitesse = 0.0
	temps_perdu = 0.0
	position_piste = fposmod(distance_piste, piste.longueur)


func ou_suis_je() -> Vector3:
	return boule.global_position


func tour() -> int:
	return int(floor(distance / piste.longueur)) + 1


# La direction vers l'avant du kart, couchée sur le sol.
func devant() -> Vector3:
	var direction := Vector3(-sin(cap), 0, -cos(cap))
	return (direction - normale * direction.dot(normale)).normalized()


# ── Les bonus ────────────────────────────────────────────────

# Le kart roule sur une cagette : il gagne une chose au hasard.
func ramasser() -> void:
	var bonus: String = R.BONUS.pick_random()
	if bonus == "pepins" or objet != "":
		# Si on a déjà un objet en réserve, on gagne des pépins à la place.
		pepins = mini(R.PEPINS_MAXIMUM, pepins + R.PEPINS_PAR_BONUS)
		annonce = "+%d pépins" % R.PEPINS_PAR_BONUS
	else:
		objet = bonus
		annonce = {"turbo": "Turbo !", "bouclier": "Bouclier !", "jus": "Jus !"}.get(bonus, bonus)
	annonce_temps = 1.5
	attente_ordi = randf_range(1.5, 5.0)


func _tirer() -> void:
	if pepins > 0:
		pepins -= 1
		tire.emit(self)


func _utiliser_objet() -> void:
	match objet:
		"turbo":
			turbo = R.TURBO_DUREE
		"bouclier":
			bouclier = R.BOUCLIER_DUREE
		"jus":
			verse.emit(self)
	objet = ""


# Le kart reçoit un pépin : tête-à-queue, sauf si le bouclier le protège.
func recevoir_pepin() -> void:
	if bouclier > 0.0:
		bouclier = 0.0  # le bouclier éclate
	elif toupie <= 0.0:
		toupie = R.TETE_A_QUEUE
		derapage = 0.0


# Le kart roule dans une flaque de jus : il est ralenti, sauf avec un bouclier.
func rouler_dans_le_jus() -> void:
	if bouclier <= 0.0:
		englue = 1.0


# L'ordinateur utilise ses bonus : l'objet après quelques secondes,
# les pépins quand un autre kart est juste devant lui.
func _bonus_de_l_ordi(dt: float) -> void:
	attente_ordi -= dt
	if attente_ordi > 0.0 or not R.ORDIS_UTILISENT_BONUS or arrivee >= 0.0:
		return
	if objet != "":
		_utiliser_objet()
		attente_ordi = 2.0
	elif pepins > 0:
		var avant := devant()
		for k in adversaires:
			var vers: Vector3 = k.ou_suis_je() - ou_suis_je()
			var loin := vers.length()
			if k != self and loin > 4.0 and loin < 30.0 and avant.dot(vers / loin) > 0.97:
				_tirer()
				attente_ordi = 1.5
				break


# Les bonus et les ennuis : le bouclier, le jus, le tête-à-queue, les boutons pour tirer
# et pour utiliser l'objet. Répond true pendant un tête-à-queue.
func _gerer_les_bonus(dt: float) -> bool:
	bouclier = maxf(0.0, bouclier - dt)
	englue = maxf(0.0, englue - dt)
	annonce_temps = maxf(0.0, annonce_temps - dt)
	repos_saut = maxf(0.0, repos_saut - dt)
	var en_toupie := toupie > 0.0
	toupie = maxf(0.0, toupie - dt)
	if en_toupie:
		pass
	elif actif and auto:
		_bonus_de_l_ordi(dt)
	elif actif:
		if bouton_tir and not tir_avant:
			_tirer()
		if bouton_objet and not objet_avant:
			_utiliser_objet()
	tir_avant = bouton_tir
	objet_avant = bouton_objet
	return en_toupie


func _physics_process(dt: float) -> void:
	_avancer(dt)


func _process(dt: float) -> void:
	_dessiner(dt)


# La conduite, soixante fois par seconde.
func _avancer(dt: float) -> void:
	var ici := boule.global_position

	# Qu'y a-t-il sous les roues ?
	var rayon := PhysicsRayQueryParameters3D.create(ici, ici + Vector3.DOWN * (RAYON + 0.4), 1)
	var touche := get_world_3d().direct_space_state.intersect_ray(rayon)
	au_sol = not touche.is_empty()
	var sol := ""
	if au_sol:
		normale = normale.lerp(touche["normal"], minf(1.0, dt * 12.0)).normalized()
		sol = touche["collider"].get_meta("sol", "")
	else:
		normale = normale.lerp(Vector3.UP, minf(1.0, dt * 2.0)).normalized()

	var volant := 0.0
	var gaz := 0.0
	if actif:
		var ordre := _pilote_auto() if auto else commande
		volant = ordre.x
		gaz = ordre.y

	var en_toupie := _gerer_les_bonus(dt)
	if en_toupie:
		volant = 0.0
		gaz = 0.0

	# Le saut : seulement quand on touche le sol.
	var saute := actif and not auto and bouton_saut and au_sol and repos_saut <= 0.0 and not en_toupie
	if saute:
		repos_saut = 0.5

	# Les turbos.
	for t in piste.turbos:
		if au_sol and absf(wrapf(position_piste - t, -piste.longueur / 2.0, piste.longueur / 2.0)) < 3.0:
			turbo = R.TURBO_DUREE
	turbo = maxf(0.0, turbo - dt)

	# Le dérapage : on appuie sur le bouton en tournant, le kart se met en travers.
	# Plus on tient longtemps, plus le turbo est fort quand on relâche.
	var bouton := actif and not auto and bouton_derapage
	if derapage == 0.0:
		if bouton and au_sol and absf(volant) > 0.3 and vitesse > vmax * 0.5:
			derapage = signf(volant)
			charge = 0.0
	elif not bouton or vitesse < vmax * 0.3 or en_toupie:
		if not bouton and charge >= R.DERAPAGE_GRAND_TURBO:
			turbo = R.TURBO_DUREE
		elif not bouton and charge >= R.DERAPAGE_PETIT_TURBO:
			turbo = R.TURBO_DUREE * 0.5
		derapage = 0.0
	elif au_sol:
		charge += dt
	if derapage != 0.0:
		volant = derapage * 0.6 + volant * 0.5  # on tourne toujours du côté du dérapage
	travers = lerpf(travers, derapage * 0.45, minf(1.0, dt * 8.0))
	var niveau := 0 if derapage == 0.0 else (2 if charge >= R.DERAPAGE_GRAND_TURBO else (1 if charge >= R.DERAPAGE_PETIT_TURBO else 0))
	lueur.albedo_color = Color(R.COULEUR_ETINCELLES[niveau])
	for e in etincelles:
		e.visible = derapage != 0.0
		e.scale = Vector3.ONE * (0.6 + 0.4 * niveau + 0.15 * sin(charge * 40.0))

	# La vitesse. On ne change que la vitesse vers l'avant : la gravité et les chocs
	# restent gérés par le moteur physique.
	var direction := Vector3(-sin(cap), 0, -cos(cap))
	if au_sol:
		var avant := (direction - normale * direction.dot(normale)).normalized()
		var v := boule.linear_velocity
		var v_avant := v.dot(avant)
		var v_haut := v.dot(normale)
		var v_cote := v - avant * v_avant - normale * v_haut

		var limite := vmax * (R.HERBE if sol == "herbe" else 1.0)
		if englue > 0.0:
			limite *= R.JUS_RALENTI
		if en_toupie:
			limite *= 0.2
		if saute:
			v_haut = maxf(v_haut, 0.0) + R.SAUT_FORCE * sqrt(piste.ambiance["gravite"])
		if turbo > 0.0:
			limite *= R.TURBO_FORCE
			gaz = 1.0
		if gaz > 0.0:
			if v_avant < limite:
				v_avant = minf(limite, v_avant + acceleration * gaz * (3.0 if turbo > 0.0 else 1.0) * dt)
		elif gaz < 0.0:
			v_avant = maxf(-vmax * 0.35, v_avant - 30.0 * dt)
		else:
			v_avant = move_toward(v_avant, 0.0, 8.0 * dt)
		if v_avant > limite:
			v_avant = maxf(limite, v_avant - (60.0 if en_toupie else 30.0) * dt)

		v_cote *= exp(-R.ADHERENCE * piste.ambiance["adherence"] * (R.DERAPAGE_GLISSE if derapage != 0.0 else 1.0) * dt)
		boule.linear_velocity = avant * v_avant + v_cote + normale * v_haut
		vitesse = v_avant

	# Le volant. On tourne moins bien à l'arrêt et en l'air.
	var prise := clampf(absf(vitesse) / 8.0, 0.0, 1.0) * (1.0 if vitesse >= 0.0 else -1.0)
	if not au_sol:
		prise *= 0.4
	cap -= volant * braquage * prise * dt
	penche = lerpf(penche, volant * prise * 0.12, minf(1.0, dt * 8.0))
	volant_vu = volant

	# Où en est-on sur le tour ?
	var p: float = piste.courbe.get_closest_offset(ici)
	var avance := wrapf(p - position_piste, -piste.longueur / 2.0, piste.longueur / 2.0)
	var perdu := absf(avance) > 15.0 or ici.y < -5.0 or (au_sol and sol == "herbe")
	if not perdu:
		distance += avance
		position_piste = p
	if actif and auto and absf(vitesse) < 2.0:
		perdu = true  # un ordinateur coincé contre une barrière
	temps_perdu = temps_perdu + dt if perdu else 0.0
	if temps_perdu > 2.0:
		retours += 1
		placer(position_piste, 0.0)  # retour sur la piste
	vitesse_max = maxf(vitesse_max, vitesse)
	hauteur_max = maxf(hauteur_max, ici.y - piste.courbe.sample_baked(position_piste).y)


func _dessiner(dt: float) -> void:
	# Le fruit suit la boule, tourné dans la direction du kart et incliné comme le sol.
	var direction := Vector3(-sin(cap), 0, -cos(cap))
	var avant := (direction - normale * direction.dot(normale)).normalized()
	var droite := avant.cross(normale).normalized()
	var tete_a_queue := toupie / R.TETE_A_QUEUE * TAU * 2.0  # deux tours sur soi-même
	var base := Basis(droite, normale, -avant).rotated(avant, -penche).rotated(normale, -travers + tete_a_queue)
	visuel.global_transform = Transform3D(base, boule.global_position - normale * RAYON)
	bulle.visible = bouclier > 0.0

	# Les roues tournent, et celles de devant suivent le volant.
	for roue in modele.get_meta("roues", []):
		roue.rotate_x(-vitesse * dt / 0.34)
	for pivot in modele.get_meta("directrices", []):
		pivot.rotation.y = lerpf(pivot.rotation.y, -volant_vu * 0.45, minf(1.0, dt * 10.0))


# L'ordinateur vise un point un peu plus loin sur la piste.
func _pilote_auto() -> Vector2:
	var cible: Transform3D = piste.repere(position_piste + 8.0 + absf(vitesse) * 0.35)
	var vers := cible.origin + cible.basis.x * cote - boule.global_position
	var ecart := wrapf(atan2(-vers.x, -vers.z) - cap, -PI, PI)
	var trop_vite := absf(ecart) > 0.6 and vitesse > vmax * 0.6
	return Vector2(clampf(-ecart * 3.0, -1.0, 1.0), -1.0 if trop_vite else 1.0)
