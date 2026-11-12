# ─────────────────────────────────────────────────────────────
#  LES VÉHICULES
#  Chaque joueur choisit son véhicule dans le menu. Il prend la couleur de son pilote.
#
#    nom           le nom affiché dans le menu
#    avion         son nom dans le mode Avions, où chaque véhicule devient un avion
#    forme         "kart", "buggy", "bolide", "tracteur" ou "cagette"
#                  (les formes sont fabriquées dans jeu/fruit.gd)
#    vitesse, acceleration, maniabilite
#                  ce que le véhicule ajoute (1) ou enlève (-1) aux points du pilote
#
#  Astuce : un bon véhicule donne autant qu'il enlève. Ici le total fait 0 pour tout le monde.
# ─────────────────────────────────────────────────────────────
extends RefCounted

const VEHICULES := [
	{"nom": "Kart", "avion": "Monoplan", "forme": "kart", "vitesse": 0, "acceleration": 0, "maniabilite": 0},
	{"nom": "Buggy", "avion": "Biplan", "forme": "buggy", "vitesse": -1, "acceleration": 0, "maniabilite": 1},
	{"nom": "Bolide", "avion": "Jet", "forme": "bolide", "vitesse": 1, "acceleration": 0, "maniabilite": -1},
	{"nom": "Tracteur", "avion": "Coucou", "forme": "tracteur", "vitesse": -1, "acceleration": 1, "maniabilite": 0},
	{"nom": "Cagette", "avion": "Planeur", "forme": "cagette", "vitesse": 0, "acceleration": -1, "maniabilite": 1},
]
