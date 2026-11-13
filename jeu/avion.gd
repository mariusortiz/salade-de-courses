# Un avion : c'est un kart qui vole. Il garde tout ce que sait faire un kart (les bonus,
# les pépins, le bouclier...) mais il ne roule pas : il avance tout seul dans la direction
# de son nez, et il doit traverser les anneaux dans l'ordre.
extends "res://jeu/kart.gd"

var ou := Vector3.ZERO   # où est l'avion
var tangage := 0.0       # le nez vers le haut (positif) ou vers le bas (négatif)
var roulis := 0.0        # l'avion se penche dans les virages
var frein_ordi := false  # l'ordinateur freine quand l'anneau est trop sur le côté
var etage := 0.0         # les ordinateurs ne visent pas tous le milieu de l'anneau
var prochain := 0        # le numéro du prochain anneau (on continue de compter à chaque tour)


func _fabriquer(vehicule: Dictionary) -> void:
	visuel = Node3D.new()
	modele = Fruit.creer(pilote, vehicule, true)
	visuel.add_child(modele)
	add_child(visuel)
	_creer_la_bulle()
	au_sol = true  # pour que les bonus marchent comme sur un kart
	cote = randf_range(-2.5, 2.5)
	etage = randf_range(-2.5, 2.5)


# Pose l'avion au-dessus de la piste, à une distance du départ et décalé sur le côté.
func placer(distance_piste: float, decalage: float) -> void:
	var r: Transform3D = piste.repere(distance_piste)
	ou = r.origin + r.basis.x * decalage + Vector3.UP * 7.0
	var avant := -r.basis.z
	cap = atan2(-avant.x, -avant.z)
	tangage = 0.0
	vitesse = 0.0
	position_piste = fposmod(distance_piste, piste.longueur)


func _ranger() -> void:
	ou = Vector3(0, -1000, 0)


func ou_suis_je() -> Vector3:
	return ou


func devant() -> Vector3:
	return Vector3(-sin(cap) * cos(tangage), sin(tangage), -cos(cap) * cos(tangage))


func _avancer(dt: float) -> void:
	var volant := 0.0
	var montee := 0.0
	if actif:
		var ordre := _pilote_auto() if auto else commande
		volant = ordre.x
		montee = ordre.y
		if not auto and not R.AVION_HAUT_MONTE:
			montee = -montee
	var en_vrille := _gerer_les_bonus(dt)
	if en_vrille:
		volant = 0.0
		montee = 0.0
	turbo = maxf(0.0, turbo - dt)

	# La vitesse : l'avion avance tout seul. Le bouton du dérapage sert de frein.
	var limite := vmax * bonus_vitesse if actif else 0.0
	if turbo > 0.0:
		limite *= R.TURBO_FORCE
	if englue > 0.0:
		limite *= R.JUS_RALENTI
	if en_vrille:
		limite *= 0.3
	if actif and (frein_ordi if auto else bouton_derapage):
		limite *= 0.55
	var poussee := acceleration * (3.0 if turbo > 0.0 else 1.0) if vitesse < limite else 30.0
	vitesse = move_toward(vitesse, limite, poussee * dt)

	# Le manche : gauche et droite pour tourner, haut et bas pour monter et descendre.
	# Quand on lâche le manche, l'avion se remet à plat tout seul.
	cap -= volant * braquage * 0.7 * dt
	if absf(montee) > 0.1:
		tangage = clampf(tangage + montee * R.AVION_MANCHE * dt, -0.7, 0.7)
	else:
		tangage = move_toward(tangage, 0.0, 0.8 * dt)
	roulis = lerpf(roulis, volant * 0.6, minf(1.0, dt * 5.0))
	volant_vu = volant

	var avant := ou
	ou += devant() * vitesse * dt

	# Où en est-on sur le tour ? On cherche le point de la piste le plus proche,
	# seulement un peu derrière et un peu devant l'endroit où on était.
	var meilleur := position_piste
	var proche := INF
	for i in range(-5, 21):
		var d := position_piste + i * 2.0
		var ecart: float = piste.courbe.sample_baked(fposmod(d, piste.longueur)).distance_squared_to(ou)
		if ecart < proche:
			proche = ecart
			meilleur = d
	distance += meilleur - position_piste
	position_piste = fposmod(meilleur, piste.longueur)

	# On ne peut pas traverser le sol ni la route, ni monter trop haut.
	var route: Vector3 = piste.courbe.sample_baked(position_piste)
	var plancher := -25.0 if piste.ambiance["sol"].is_empty() else 1.5
	if Vector2(ou.x - route.x, ou.z - route.z).length() < piste.largeur / 2.0 + 1.5 and ou.y > route.y - 1.0:
		plancher = maxf(plancher, route.y + 1.8)
	var plafond := route.y + R.AVION_PLAFOND
	if ou.y < plancher:
		ou.y = plancher
		tangage = maxf(tangage, 0.0)
	if ou.y > plafond:
		ou.y = plafond
		tangage = minf(tangage, 0.0)

	_traverser_les_anneaux(avant)
	vitesse_max = maxf(vitesse_max, vitesse)
	hauteur_max = maxf(hauteur_max, ou.y - route.y)


# A-t-on traversé le prochain anneau ? Si on passe à côté, on est reposé juste devant lui.
func _traverser_les_anneaux(avant: Vector3) -> void:
	var anneau: Dictionary = piste.anneaux[prochain % piste.anneaux.size()]
	var centre: Vector3 = anneau["centre"]
	var axe: Vector3 = anneau["axe"]
	var derriere := (avant - centre).dot(axe)
	var passe := (ou - centre).dot(axe)
	var rate := passe > 18.0 and ou.distance_to(centre) < 80.0
	if derriere < 0.0 and passe >= 0.0:
		var croisement := avant.lerp(ou, derriere / (derriere - passe))
		if croisement.distance_to(centre) < piste.RAYON_ANNEAU + 0.5:
			prochain += 1
			if anneau["turbo"]:
				turbo = R.TURBO_DUREE
		else:
			rate = true
	if rate:
		retours += 1
		ou = centre - axe * 24.0
		cap = atan2(-axe.x, -axe.z)
		tangage = 0.0
		vitesse *= 0.5
		var ici: float = fposmod(anneau["distance"] - 24.0, piste.longueur)
		distance -= wrapf(position_piste - ici, -piste.longueur / 2.0, piste.longueur / 2.0)
		position_piste = ici


func _dessiner(dt: float) -> void:
	var vrille := toupie / R.TETE_A_QUEUE * TAU * 2.0  # deux tonneaux quand on reçoit un pépin
	var base := Basis.from_euler(Vector3(tangage, cap, -roulis + vrille))
	visuel.global_transform = Transform3D(base, ou - base.y * 0.9)
	bulle.visible = bouclier > 0.0
	for helice in modele.get_meta("helices", []):
		helice.rotate_z(dt * (10.0 + vitesse))


# L'ordinateur vise le milieu du prochain anneau.
func _pilote_auto() -> Vector2:
	var anneau: Dictionary = piste.anneaux[prochain % piste.anneaux.size()]
	var vers: Vector3 = anneau["centre"] + anneau["droite"] * cote + Vector3.UP * etage - ou
	var ecart := wrapf(atan2(-vers.x, -vers.z) - cap, -PI, PI)
	var pente := atan2(vers.y, Vector2(vers.x, vers.z).length())
	frein_ordi = absf(ecart) > 0.45 or absf(pente - tangage) > 0.4
	return Vector2(clampf(-ecart * 3.0, -1.0, 1.0), clampf((pente - tangage) * 4.0, -1.0, 1.0))
