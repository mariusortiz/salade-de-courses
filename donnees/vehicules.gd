# ─────────────────────────────────────────────────────────────
#  LES VÉHICULES
#  Chaque joueur choisit son véhicule dans le menu. Il prend la couleur de son pilote.
#
#    nom           le nom affiché dans le menu
#    avion         son nom dans le mode Avions, où chaque véhicule devient un avion
#    forme         "kart", "buggy", "bolide", "tracteur" ou "cagette"
#                  (les formes sont fabriquées dans jeu/fruit.gd)
#    prix          son prix au magasin, en graines (0 = on l'a dès le début)
#    prix_avion    le prix de l'avion
#    vitesse, acceleration, maniabilite
#                  ce que le véhicule ajoute (1) ou enlève (-1) aux points du pilote
#
#  Astuce : un bon véhicule donne autant qu'il enlève. Ici le total fait 0 pour tout le monde.
# ─────────────────────────────────────────────────────────────
extends RefCounted

const VEHICULES := [
	{"nom": "Kart", "avion": "Monoplan", "forme": "kart", "vitesse": 0, "acceleration": 0, "maniabilite": 0, "prix": 0, "prix_avion": 0},
	{"nom": "Buggy", "avion": "Biplan", "forme": "buggy", "vitesse": -1, "acceleration": 0, "maniabilite": 1, "prix": 200, "prix_avion": 200},
	{"nom": "Bolide", "avion": "Jet", "forme": "bolide", "vitesse": 1, "acceleration": 0, "maniabilite": -1, "prix": 400, "prix_avion": 400},
	{"nom": "Tracteur", "avion": "Coucou", "forme": "tracteur", "vitesse": -1, "acceleration": 1, "maniabilite": 0, "prix": 200, "prix_avion": 200},
	{"nom": "Cagette", "avion": "Planeur", "forme": "cagette", "vitesse": 0, "acceleration": -1, "maniabilite": 1, "prix": 300, "prix_avion": 300},
]
