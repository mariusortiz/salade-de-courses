# Le défi du jour : il est tiré au sort à partir de la date, donc tout le monde a le même.
# Les étoiles gagnées sont gardées dans un petit fichier sur l'appareil du joueur.
extends RefCounted

const Defis = preload("res://donnees/defis.gd")
const Circuits = preload("res://donnees/circuits.gd")

const FICHIER := "user://defis.json"
const SEULEMENT_EN_KART := ["lune", "patinoire"]


static func _date(jours_avant := 0) -> String:
	var jour := Time.get_date_dict_from_system()
	var secondes := Time.get_unix_time_from_datetime_dict(jour) - jours_avant * 86400
	return Time.get_date_string_from_unix_time(secondes)


# Le défi d'aujourd'hui : un circuit, un mode, un nombre de tours et une règle.
static func du_jour() -> Dictionary:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = _date().hash()
	var avions := hasard.randi_range(0, 2) == 0  # un jour sur trois, on vole
	var regles: Array = Defis.REGLES.filter(func(r): return not (avions and SEULEMENT_EN_KART.has(r["effet"])))
	return {
		"circuit": hasard.randi_range(0, Circuits.CIRCUITS.size() - 1),
		"avions": avions,
		"tours": 3 if hasard.randi_range(0, 1) == 0 else 2,
		"regle": regles[hasard.randi_range(0, regles.size() - 1)],
	}


# Toutes les étoiles déjà gagnées : la date → le nombre d'étoiles.
static func _lire() -> Dictionary:
	if not FileAccess.file_exists(FICHIER):
		return {}
	var contenu = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	return contenu if contenu is Dictionary else {}


static func _ecrire(tout: Dictionary) -> void:
	var fichier := FileAccess.open(FICHIER, FileAccess.WRITE)
	if fichier != null:
		fichier.store_string(JSON.stringify(tout))


static func etoiles_du_jour() -> int:
	return int(_lire().get(_date(), 0))


# Note le résultat d'aujourd'hui (on garde le meilleur) et répond le nombre d'étoiles gagnées.
static func noter(place: int) -> int:
	var etoiles := 3 if place == 1 else (2 if place <= 3 else 1)
	var tout := _lire()
	tout[_date()] = maxi(etoiles, int(tout.get(_date(), 0)))
	_ecrire(tout)
	return etoiles


# Depuis combien de jours de suite a-t-on réussi le défi ?
static func serie() -> int:
	var tout := _lire()
	var jours := 0
	var depuis := 0 if tout.has(_date()) else 1  # si on n'a pas encore joué aujourd'hui, la série tient toujours
	while tout.has(_date(depuis + jours)):
		jours += 1
	return jours


# ── Les défis des circuits ───────────────────────────────────

# La courbe d'un circuit, la même que celle de la piste (voir piste.gd).
static func courbe(circuit: Dictionary) -> Curve3D:
	var trace := Curve3D.new()
	var points: Array = circuit["points"]
	var n := points.size()
	for i in n + 1:
		var poignee: Vector3 = (points[(i + 1) % n] - points[(i - 1 + n) % n]) / 6.0
		trace.add_point(points[i % n], -poignee, poignee)
	return trace


# Les trois défis d'un circuit, avec leur texte prêt à afficher.
static func du_circuit(numero: int) -> Array:
	var circuit: Dictionary = Circuits.CIRCUITS[numero]
	var choisis: Array = circuit.get("defis", ["chrono", Defis.AU_CHOIX_KART[numero % Defis.AU_CHOIX_KART.size()], Defis.AU_CHOIX_AVION[numero % Defis.AU_CHOIX_AVION.size()]])
	var epreuves: Array = []
	for cle in choisis:
		var e: Dictionary = Defis.EPREUVES[cle].duplicate()
		e["cle"] = cle
		if cle == "chrono":
			e["combien"] = int(courbe(circuit).get_baked_length() * 3.0 / Defis.CHRONO_VITESSE)
		if "%d" in e["texte"]:
			e["texte"] = e["texte"] % e["combien"]
		epreuves.append(e)
	return epreuves


# Le défi est-il réussi ? « r » est le résultat du joueur à la fin de la course (voir course.gd).
static func reussie(epreuve: Dictionary, r: Dictionary) -> bool:
	if r["temps"] < 0.0:
		return false  # il faut au moins finir la course
	match epreuve["cle"]:
		"chrono":
			return r["temps"] <= epreuve["combien"]
		"sans_faute":
			return r["touches"] == 0 and r["retours"] == 0
		"tireur":
			return r["tirs"] >= epreuve["combien"]
		"gourmand":
			return r["cagettes"] >= epreuve["combien"]
		"glisse":
			return r["glisses"] >= epreuve["combien"]
		"as":
			return r["retours"] == 0
		"vol":
			return r["place"] == 1
	return false


# Les défis déjà réussis sur un circuit (la liste de leurs clés).
static func reussis(nom_du_circuit: String) -> Array:
	var circuits = _lire().get("circuits", {})
	return circuits.get(nom_du_circuit, []) if circuits is Dictionary else []


static func valider(nom_du_circuit: String, cle: String) -> void:
	var tout := _lire()
	if not tout.get("circuits") is Dictionary:
		tout["circuits"] = {}
	var faits: Array = tout["circuits"].get(nom_du_circuit, [])
	if not faits.has(cle):
		faits.append(cle)
	tout["circuits"][nom_du_circuit] = faits
	_ecrire(tout)


# ── Les records du contre-la-montre ──────────────────────────

const RECORDS := "user://records.json"


# Le record d'un circuit : son temps et la trace de la course (pour le fantôme). Vide s'il n'y en a pas.
static func record(cle: String) -> Dictionary:
	if not FileAccess.file_exists(RECORDS):
		return {}
	var tout = JSON.parse_string(FileAccess.get_file_as_string(RECORDS))
	return tout.get(cle, {}) if tout is Dictionary else {}


static func noter_le_record(cle: String, temps: float, trace: Array) -> void:
	var tout = JSON.parse_string(FileAccess.get_file_as_string(RECORDS)) if FileAccess.file_exists(RECORDS) else {}
	if not tout is Dictionary:
		tout = {}
	tout[cle] = {"temps": temps, "trace": trace}
	var fichier := FileAccess.open(RECORDS, FileAccess.WRITE)
	if fichier != null:
		fichier.store_string(JSON.stringify(tout))
