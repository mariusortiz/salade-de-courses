# Le magasin : on gagne des graines en course, et on les dépense pour acheter
# des voitures et des avions. Le porte-monnaie et le garage sont gardés sur l'appareil,
# dans le même fichier que les défis.
extends RefCounted

const Defi = preload("res://jeu/defi.gd")
const Vehicules = preload("res://donnees/vehicules.gd")


static func graines() -> int:
	return int(Defi._lire().get("graines", 0))


static func gagner(combien: int) -> void:
	var tout: Dictionary = Defi._lire()
	tout["graines"] = int(tout.get("graines", 0)) + combien
	Defi._ecrire(tout)


static func prix(numero: int, avion: bool) -> int:
	return int(Vehicules.VEHICULES[numero].get("prix_avion" if avion else "prix", 0))


# Le nom sous lequel un véhicule est rangé dans le garage.
static func _etiquette(numero: int, avion: bool) -> String:
	return ("avion:" if avion else "voiture:") + str(Vehicules.VEHICULES[numero]["forme"])


# Ce véhicule est-il à nous ? Ceux qui ne coûtent rien le sont toujours.
static func possede(numero: int, avion: bool) -> bool:
	if prix(numero, avion) <= 0:
		return true
	var garage = Defi._lire().get("garage", [])
	return garage is Array and garage.has(_etiquette(numero, avion))


# Les numéros de tous les véhicules qu'on possède, dans l'ordre.
static func garage(avion: bool) -> Array:
	return range(Vehicules.VEHICULES.size()).filter(func(i): return possede(i, avion))


# Achète un véhicule si on a assez de graines. Répond true si c'est fait.
static func acheter(numero: int, avion: bool) -> bool:
	var tout: Dictionary = Defi._lire()
	var cout := prix(numero, avion)
	if possede(numero, avion) or int(tout.get("graines", 0)) < cout:
		return false
	tout["graines"] = int(tout.get("graines", 0)) - cout
	var a_nous: Array = tout.get("garage", []) if tout.get("garage") is Array else []
	a_nous.append(_etiquette(numero, avion))
	tout["garage"] = a_nous
	Defi._ecrire(tout)
	return true
