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


static func etoiles_du_jour() -> int:
	return int(_lire().get(_date(), 0))


# Note le résultat d'aujourd'hui (on garde le meilleur) et répond le nombre d'étoiles gagnées.
static func noter(place: int) -> int:
	var etoiles := 3 if place == 1 else (2 if place <= 3 else 1)
	var tout := _lire()
	tout[_date()] = maxi(etoiles, int(tout.get(_date(), 0)))
	var fichier := FileAccess.open(FICHIER, FileAccess.WRITE)
	if fichier != null:
		fichier.store_string(JSON.stringify(tout))
	return etoiles


# Depuis combien de jours de suite a-t-on réussi le défi ?
static func serie() -> int:
	var tout := _lire()
	var jours := 0
	var depuis := 0 if tout.has(_date()) else 1  # si on n'a pas encore joué aujourd'hui, la série tient toujours
	while tout.has(_date(depuis + jours)):
		jours += 1
	return jours
