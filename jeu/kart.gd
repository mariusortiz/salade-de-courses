# Un kart : une boule qui roule vraiment sur la piste (c'est le moteur physique
# qui gère les pentes, les sauts et les chocs), avec le fruit posé dessus.
extends Node3D

const R = preload("res://donnees/reglages.gd")
const Fruit = preload("res://jeu/fruit.gd")

const RAYON := 0.9

var pilote: Dictionary
var piste: Node3D
var humain := false
var auto := true          # true = conduit par l'ordinateur
var actif := false        # false pendant le compte à rebours
var commande := Vector2.ZERO  # x = volant (-1 gauche, 1 droite), y = gaz (-1 à 1)

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

var position_piste := 0.0 # où est le kart sur le tour, en mètres depuis le départ
var distance := 0.0       # distance totale parcourue depuis la ligne de départ
var arrivee := -1.0       # temps à l'arrivée (-1 = pas encore arrivé)
var cote := 0.0           # les ordinateurs ne roulent pas tous au milieu
var temps_perdu := 0.0

# Pour les essais automatiques.
var retours := 0
var vitesse_max := 0.0
var hauteur_max := 0.0


func preparer(le_pilote: Dictionary, la_piste: Node3D, est_humain: bool) -> void:
	pilote = le_pilote
	piste = la_piste
	humain = est_humain
	auto = not est_humain

	var niveau := 1.0 if humain else R.NIVEAU_ORDIS * randf_range(0.95, 1.03)
	vmax = (26.0 + pilote["vitesse"] * 1.5) * niveau
	acceleration = 12.0 + pilote["acceleration"] * 4.0
	braquage = 1.5 + pilote["maniabilite"] * 0.25
	cote = randf_range(-0.3, 0.3) * piste.largeur

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
	boule.gravity_scale = R.GRAVITE
	boule.collision_layer = 2    # les karts
	boule.collision_mask = 1 | 2 # se cognent au décor et entre eux
	boule.continuous_cd = true
	add_child(boule)

	visuel = Fruit.creer(pilote)
	add_child(visuel)


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


func _physics_process(dt: float) -> void:
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

	# Les turbos.
	for t in piste.turbos:
		if au_sol and absf(wrapf(position_piste - t, -piste.longueur / 2.0, piste.longueur / 2.0)) < 3.0:
			turbo = R.TURBO_DUREE
	turbo = maxf(0.0, turbo - dt)

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
			v_avant = maxf(limite, v_avant - 30.0 * dt)

		v_cote *= exp(-R.ADHERENCE * dt)
		boule.linear_velocity = avant * v_avant + v_cote + normale * v_haut
		vitesse = v_avant

	# Le volant. On tourne moins bien à l'arrêt et en l'air.
	var prise := clampf(absf(vitesse) / 8.0, 0.0, 1.0) * (1.0 if vitesse >= 0.0 else -1.0)
	if not au_sol:
		prise *= 0.4
	cap -= volant * braquage * prise * dt
	penche = lerpf(penche, volant * prise * 0.12, minf(1.0, dt * 8.0))

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


func _process(_dt: float) -> void:
	# Le fruit suit la boule, tourné dans la direction du kart et incliné comme le sol.
	var direction := Vector3(-sin(cap), 0, -cos(cap))
	var avant := (direction - normale * direction.dot(normale)).normalized()
	var droite := avant.cross(normale).normalized()
	var base := Basis(droite, normale, -avant).rotated(avant, -penche)
	visuel.global_transform = Transform3D(base, boule.global_position - normale * RAYON)


# L'ordinateur vise un point un peu plus loin sur la piste.
func _pilote_auto() -> Vector2:
	var devant: Transform3D = piste.repere(position_piste + 8.0 + absf(vitesse) * 0.35)
	var vers := devant.origin + devant.basis.x * cote - boule.global_position
	var ecart := wrapf(atan2(-vers.x, -vers.z) - cap, -PI, PI)
	var trop_vite := absf(ecart) > 0.6 and vitesse > vmax * 0.6
	return Vector2(clampf(-ecart * 3.0, -1.0, 1.0), -1.0 if trop_vite else 1.0)
