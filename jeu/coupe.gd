# Les coupes : les trophées gagnés, et ce qu'ils débloquent (pilotes, véhicules, coupes secrètes).
# Les trophées sont gardés sur l'appareil, dans le même fichier que les défis,
# sous la clé « coupes » : le nom de la coupe → {"kart": meilleure place, "avion": meilleure place}.
extends RefCounted

const Defi = preload("res://jeu/defi.gd")
const Coupes = preload("res://donnees/coupes.gd")


static func _trophees() -> Dictionary:
	var coupes = Defi._lire().get("coupes", {})
	return coupes if coupes is Dictionary else {}


# La meilleure place sur le podium dans ce mode (1, 2 ou 3), ou 0 si pas encore de trophée.
static func trophee(nom: String, avions: bool) -> int:
	var places = _trophees().get(nom, {})
	return int(places.get("avion" if avions else "kart", 0)) if places is Dictionary else 0


# A-t-on déjà gagné cette coupe (un trophée, en kart ou en avion) ?
static func gagnee(nom: String) -> bool:
	return trophee(nom, false) > 0 or trophee(nom, true) > 0


# Note la place finale. On garde le meilleur trophée. Répond true si c'est un nouveau trophée.
static func noter(nom: String, avions: bool, place: int) -> bool:
	if place < 1 or place > 3:
		return false
	var avant := trophee(nom, avions)
	if avant > 0 and avant <= place:
		return false
	var tout: Dictionary = Defi._lire()
	var coupes: Dictionary = tout.get("coupes", {}) if tout.get("coupes") is Dictionary else {}
	var places: Dictionary = coupes.get(nom, {}) if coupes.get(nom) is Dictionary else {}
	places["avion" if avions else "kart"] = place
	coupes[nom] = places
	tout["coupes"] = coupes
	Defi._ecrire(tout)
	return true


# Une coupe secrète est ouverte quand on a gagné la coupe qui la donne en cadeau.
static func ouverte(coupe: Dictionary) -> bool:
	if not coupe.get("secrete", false):
		return true
	for autre in Coupes.COUPES:
		if autre.get("cadeau", {}).get("coupe", "") == coupe["nom"] and gagnee(autre["nom"]):
			return true
	return false


# Un pilote ou un véhicule est-il à nous ? Oui, sauf si c'est le cadeau d'une coupe pas encore gagnée.
static func debloque(chose: Dictionary) -> bool:
	return not chose.has("coupe") or gagnee(chose["coupe"])


# Le cadeau d'une coupe, en mots : « le pilote Mûre », « la Coupe Mystère »...
static func cadeau_en_mots(coupe: Dictionary) -> String:
	var cadeau: Dictionary = coupe.get("cadeau", {})
	if cadeau.has("pilote"):
		return "le pilote " + cadeau["pilote"]
	if cadeau.has("vehicule"):
		return "le véhicule " + cadeau["vehicule"]
	if cadeau.has("coupe"):
		return "la " + cadeau["coupe"]
	return ""
