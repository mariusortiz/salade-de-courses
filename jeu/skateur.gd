# Un skateur : un fruit debout sur sa planche, dans le skatepark.
# Au sol il roule en suivant le relief. En l'air il peut faire des figures.
# Tout ce qu'il enchaîne sans retoucher le sol forme un combo (voir donnees/skate.gd).
extends Node3D

const S = preload("res://donnees/skate.gd")
const Fruit = preload("res://jeu/fruit.gd")

var pilote: Dictionary
var parc: Node3D
var humain := false
var actif := false               # false avant le départ et après la fin du temps
var commande := Vector2.ZERO     # x : tourner (-1 gauche, 1 droite) ; y : pousser (1) ou freiner (-1)
var boutons: Array = [false, false, false, false]  # [—, sauter, tonneau, attraper]

var ou := Vector3.ZERO           # où est le skateur (ses roues)
var elan := Vector3.ZERO         # sa vitesse en l'air
var vitesse := 0.0               # sa vitesse au sol
var cap := 0.0                   # vers où il regarde
var route := 0.0                 # vers où il va (la caméra regarde par là)
var au_sol := true
var barre := -1                  # le numéro de la barre sur laquelle il glisse (-1 = aucune)
var sur_la_barre := 0.0          # où il en est sur la barre, en mètres
var sens_de_barre := 1.0

var score := 0
var combo: Array = []            # les figures du combo en cours : {cle, nom, points}
var tour := 0.0                  # de combien il a tourné sur lui-même depuis le décollage
var salto := 0.0                 # de combien il a basculé en avant (ou en arrière)
var tonneau := 0.0               # le temps qu'il reste au tonneau en cours
var attrape := 0.0               # depuis combien de temps il tient sa planche
var glissade := 0.0              # depuis combien de temps il glisse sur la barre
var depart := 0.0                # la hauteur d'où il a décollé
var sommet := 0.0                # la plus grande hauteur atteinte pendant le saut
var chute := 0.0                 # le temps qu'il reste par terre après une chute
var annonce := ""                # le message du moment (« + 900 ! », « Chute ! »)
var annonce_temps := 0.0
var meilleur_combo := 0
var chutes := 0
var figures := 0
var bavard := false              # pour les essais : écrit ce qui se passe

var modele: Node3D
var sautait := false
var tonnait := false
# Les figures ne partent que si on appuie APRÈS avoir décollé : comme ça, pousser (haut) ou
# tourner en quittant une rampe ne lance pas un salto ou une toupie sans le vouloir.
var toupie_prete := false
var salto_pret := false


func preparer(le_pilote: Dictionary, le_parc: Node3D, est_humain: bool, planche: Dictionary) -> void:
	pilote = le_pilote
	parc = le_parc
	humain = est_humain
	modele = Fruit.creer(pilote, planche, false)
	add_child(modele)


func placer(x: float, z: float, vers: float) -> void:
	ou = Vector3(x, parc.hauteur(x, z), z)
	cap = vers
	route = vers
	vitesse = 0.0
	au_sol = true
	barre = -1


func ou_suis_je() -> Vector3:
	return ou


func _physics_process(dt: float) -> void:
	annonce_temps = maxf(0.0, annonce_temps - dt)
	var volant := commande.x if actif else 0.0
	var gaz := commande.y if actif else 0.0
	var saute: bool = actif and boutons[1]
	var veut_sauter := saute and not sautait
	sautait = saute
	if chute > 0.0:
		chute -= dt
		vitesse = 0.0
	elif barre >= 0:
		_glisser(dt, veut_sauter)
	elif au_sol:
		_rouler(dt, volant, gaz, veut_sauter)
	else:
		_voler(dt, volant, gaz)
	_dessiner()


# ── Au sol ───────────────────────────────────────────────────

func _rouler(dt: float, volant: float, gaz: float, veut_sauter: bool) -> void:
	cap -= volant * S.BRAQUAGE * clampf(absf(vitesse) / 4.0, 0.35, 1.0) * dt
	var avant := Vector3(-sin(cap), 0, -cos(cap))
	# La pente sous la planche : en montée on ralentit, en descente on accélère.
	var derriere := ou - avant * 0.3
	var devant := ou + avant * 0.3
	var pente := clampf(atan2(parc.hauteur(ou.x, ou.z) - parc.hauteur(derriere.x, derriere.z), 0.3), -1.3, 1.3)
	if not parc.dedans(derriere.x, derriere.z):
		# Tout en haut d'une rampe du tour, dos au mur : on regarde la pente devant soi.
		pente = clampf(atan2(parc.hauteur(devant.x, devant.z) - parc.hauteur(ou.x, ou.z), 0.3), -1.3, 1.3)
	if gaz > 0.0 and vitesse < S.VITESSE:
		vitesse = minf(S.VITESSE, vitesse + S.POUSSEE * gaz * dt)
	elif gaz < 0.0:
		vitesse = move_toward(vitesse, 0.0, 16.0 * dt)
	vitesse -= S.GRAVITE * sin(pente) * dt
	vitesse -= vitesse * 0.12 * dt
	if vitesse < -0.5:
		# On repart en arrière (en haut d'une rampe, par exemple) : demi-tour, et on redescend.
		cap += PI
		vitesse = -vitesse
		avant = -avant
		pente = -pente
	route = cap
	var mouvement := (avant * cos(pente) + Vector3.UP * sin(pente)) * vitesse
	if veut_sauter:
		_decoller(mouvement + Vector3.UP * S.SAUT)
		return
	var suite := ou + mouvement * dt
	if not parc.dedans(suite.x, suite.z):
		_decoller(mouvement)  # en haut d'une rampe du tour : on s'envole le long du mur
		return
	var sol: float = parc.hauteur(suite.x, suite.z)
	if sol > suite.y + 0.6:
		vitesse = -vitesse * 0.3  # un mur (le côté d'un tremplin) : on rebondit
		return
	if sol < suite.y - 0.5 * S.GRAVITE * dt * dt - 0.004:
		ou = suite
		_decoller(mouvement)  # le sol se dérobe : on est en l'air
		return
	ou = Vector3(suite.x, sol, suite.z)


func _decoller(avec: Vector3) -> void:
	au_sol = false
	elan = avec
	if barre < 0:
		tour = 0.0
		salto = 0.0
		tonneau = 0.0
		attrape = 0.0
	barre = -1
	depart = ou.y
	sommet = ou.y
	toupie_prete = false
	salto_pret = false


# ── En l'air ─────────────────────────────────────────────────

func _voler(dt: float, volant: float, gaz: float) -> void:
	elan.y -= S.GRAVITE * dt
	ou += elan * dt
	# Le mur du tour : on ne le traverse pas, on monte et on redescend le long.
	if absf(ou.x) > parc.demi.x:
		ou.x = signf(ou.x) * parc.demi.x
		elan.x = 0.0
	if absf(ou.z) > parc.demi.y:
		ou.z = signf(ou.z) * parc.demi.y
		elan.z = 0.0
	sommet = maxf(sommet, ou.y)
	if Vector2(elan.x, elan.z).length() > 2.0:
		route = atan2(-elan.x, -elan.z)

	# Les figures. Gauche et droite : la toupie. Haut et bas : le salto.
	toupie_prete = toupie_prete or absf(volant) < 0.3
	salto_pret = salto_pret or absf(gaz) < 0.3
	if toupie_prete:
		cap -= volant * S.TOUPIE_VITESSE * dt
		tour += volant * S.TOUPIE_VITESSE * dt
	if salto_pret:
		salto += gaz * S.SALTO_VITESSE * dt
	var tonne: bool = actif and boutons[2]
	if tonne and not tonnait and tonneau <= 0.0:
		tonneau = S.TONNEAU_DUREE
	tonnait = tonne
	if tonneau > 0.0:
		tonneau -= dt
		if tonneau <= 0.0:
			_figure("tonneau", 1.0)
	if actif and boutons[3]:
		attrape += dt
	elif attrape > 0.0:
		_fin_de_l_attrape()

	# Une barre juste dessous ? On se pose dessus et on glisse.
	if elan.y <= 0.0:
		for numero in parc.barres.size():
			var b: Dictionary = parc.barres[numero]
			var le_long: Vector3 = (b["b"] - b["a"]) / b["longueur"]
			var distance: float = clampf((ou - b["a"]).dot(le_long), 0.0, b["longueur"])
			var point: Vector3 = b["a"] + le_long * distance
			if Vector2(ou.x - point.x, ou.z - point.z).length() < 0.8 and ou.y <= point.y + 0.15 and ou.y > point.y - 0.6:
				barre = numero
				sur_la_barre = distance
				sens_de_barre = 1.0 if elan.dot(le_long) >= 0.0 else -1.0
				vitesse = maxf(5.0, absf(elan.dot(le_long)))
				glissade = 0.0
				_fin_de_l_attrape()
				tonneau = 0.0
				salto = 0.0
				return

	var sol: float = parc.hauteur(ou.x, ou.z)
	if ou.y <= sol:
		_atterrir(sol)


func _fin_de_l_attrape() -> void:
	if attrape >= 0.25:
		_figure("attrape", attrape)
	attrape = 0.0


# ── Sur une barre ────────────────────────────────────────────

func _glisser(dt: float, veut_sauter: bool) -> void:
	var b: Dictionary = parc.barres[barre]
	var le_long: Vector3 = (b["b"] - b["a"]) / b["longueur"] * sens_de_barre
	sur_la_barre += vitesse * sens_de_barre * dt
	glissade += dt
	ou = b["a"] + (b["b"] - b["a"]) / b["longueur"] * clampf(sur_la_barre, 0.0, b["longueur"])
	cap = atan2(-le_long.x, -le_long.z)
	route = cap
	var au_bout: bool = sur_la_barre <= 0.0 or sur_la_barre >= b["longueur"]
	if veut_sauter or au_bout:
		_figure("glissade", maxf(glissade, 0.2))
		glissade = 0.0
		_decoller(le_long * vitesse + Vector3.UP * (S.SAUT if veut_sauter else 1.5))
		tour = 0.0


# ── Les figures et le combo ──────────────────────────────────

# Ajoute une figure au combo. « combien » : le nombre de tours, ou de secondes.
func _figure(cle: String, combien: float, nom := "") -> void:
	var modele_de_figure: Dictionary = S.FIGURES[cle]
	var points: float = modele_de_figure["points"] * combien
	for deja in combo:
		if deja["cle"] == cle:
			points *= 0.5  # la même figure, encore : elle rapporte moitié moins
	combo.append({"cle": cle, "nom": nom if nom != "" else modele_de_figure["nom"], "points": int(points)})
	figures += 1
	if bavard:
		print("  figure : %s (%d points)" % [combo[-1]["nom"], combo[-1]["points"]])


# Le texte du combo en cours, pour l'écran.
func texte_du_combo() -> String:
	if combo.is_empty():
		return ""
	var noms := PackedStringArray()
	for f in combo:
		noms.append(f["nom"])
	return "%s   =   %d  x %d" % [" + ".join(noms), _points_du_combo(), combo.size()]


func _points_du_combo() -> int:
	var total := 0
	for f in combo:
		total += f["points"]
	return total


func _atterrir(sol: float) -> void:
	ou.y = sol
	au_sol = true
	_fin_de_l_attrape()
	# La direction dans laquelle on repart : celle de l'élan, ou la descente si on tombe tout droit.
	var a_plat := Vector2(elan.x, elan.z)
	var direction := Vector3(-sin(cap), 0, -cos(cap))
	var n: Vector3 = parc.normale(ou.x, ou.z)
	if a_plat.length() > 1.5:
		direction = Vector3(a_plat.x, 0, a_plat.y).normalized()
	elif Vector2(n.x, n.z).length() > 0.15:
		direction = Vector3(n.x, 0, n.z).normalized()
	# Coincé tout en haut, contre le mur ou dans un coin : on repart vers le milieu du skatepark.
	var contre_le_mur: bool = not parc.dedans(ou.x + direction.x * 0.5, ou.z + direction.z * 0.5)
	if contre_le_mur:
		direction = Vector3(-ou.x, 0, -ou.z).normalized()
		ou += direction * 0.4
		sol = parc.hauteur(ou.x, ou.z)
		ou.y = sol
	var vers := atan2(-direction.x, -direction.z)

	# A-t-on bien fini ses figures ? Un salto pas terminé, un tonneau en cours ou une planche
	# de travers, et c'est la chute.
	var saltos := roundi(absf(salto) / TAU)
	var rate := absf(absf(salto) - saltos * TAU) > 0.9
	rate = rate or tonneau > 0.12
	var travers := absf(wrapf(cap - vers, -PI, PI))
	rate = rate or (minf(travers, PI - travers) > 1.0 and not contre_le_mur)
	if not rate:
		var demi_tours := int(floor((absf(tour) + 0.6) / PI))
		if demi_tours > 0:
			_figure("toupie", demi_tours, "Toupie %d" % (demi_tours * 180))
		if saltos > 0:
			_figure("salto", saltos, "Salto" if saltos == 1 else ("Double salto" if saltos == 2 else "Salto x%d" % saltos))
		var envol := sommet - maxf(depart, sol)
		if envol >= 2.5:
			_figure("grand_saut", envol)
	tour = 0.0
	salto = 0.0
	tonneau = 0.0

	if rate:
		if bavard:
			print("  chute ! combo perdu : %s" % texte_du_combo())
		combo.clear()
		chutes += 1
		chute = S.CHUTE_DUREE
		vitesse = 0.0
		annonce = "Chute !"
		annonce_temps = S.CHUTE_DUREE
		return
	if not combo.is_empty():
		var gagne := _points_du_combo() * combo.size()
		score += gagne
		meilleur_combo = maxi(meilleur_combo, gagne)
		annonce = "+ %d !" % gagne
		annonce_temps = 1.6
		if bavard:
			print("  combo réussi : %s -> + %d (score %d)" % [texte_du_combo(), gagne, score])
		combo.clear()

	# On repart en roulant dans la pente.
	var plus_loin := ou + direction * 0.3
	var pente := clampf(atan2(parc.hauteur(plus_loin.x, plus_loin.z) - sol, 0.3), -1.3, 1.3)
	vitesse = elan.dot(direction * cos(pente) + Vector3.UP * sin(pente))
	cap = vers
	route = vers


# ── Le dessin ────────────────────────────────────────────────

func _dessiner() -> void:
	var base := Basis(Vector3.UP, cap)
	if chute > 0.0:
		# Par terre, sur le côté, puis on se relève.
		base = base * Basis(Vector3.FORWARD, minf(1.0, chute / 0.3) * PI / 2.0)
		modele.scale = Vector3.ONE
		global_transform = Transform3D(base, ou + Vector3.UP * 0.5 * minf(1.0, chute / 0.3))
		return
	if au_sol and barre < 0:
		# Penché comme le sol.
		var n: Vector3 = parc.normale(ou.x, ou.z)
		var avant := Vector3(-sin(cap), 0, -cos(cap))
		avant = (avant - n * avant.dot(n)).normalized()
		base = Basis(avant.cross(n).normalized(), n, -avant)
		modele.scale = Vector3.ONE
		global_transform = Transform3D(base, ou)
		return
	# En l'air : la toupie tourne déjà avec le cap ; on ajoute le salto et le tonneau.
	var roulis := 0.0
	if tonneau > 0.0:
		roulis = (1.0 - tonneau / S.TONNEAU_DUREE) * TAU
	base = base * Basis(Vector3.RIGHT, -salto) * Basis(Vector3.FORWARD, roulis)
	modele.scale = Vector3(1, 0.72, 1) if attrape > 0.0 else Vector3.ONE  # accroupi pour attraper sa planche
	# On tourne autour du ventre du fruit, pas autour des roues.
	var ventre := Vector3.UP * 1.1
	global_transform = Transform3D(base, ou + ventre - base * ventre)
