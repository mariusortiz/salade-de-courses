# ─────────────────────────────────────────────────────────────
#  LES VÉHICULES
#  Chaque joueur choisit son véhicule dans le menu. Il prend la couleur de son pilote.
#
#    nom           le nom affiché dans le menu
#    forme         "kart", "buggy", "bolide", "tracteur" ou "cagette"
#                  (les formes sont fabriquées dans jeu/fruit.gd)
#    vitesse, acceleration, maniabilite
#                  ce que le véhicule ajoute (1) ou enlève (-1) aux points du pilote
#
#  Astuce : un bon véhicule donne autant qu'il enlève. Ici le total fait 0 pour tout le monde.
# ─────────────────────────────────────────────────────────────
extends RefCounted

const VEHICULES := [
	{"nom": "Kart", "forme": "kart", "vitesse": 0, "acceleration": 0, "maniabilite": 0},
	{"nom": "Buggy", "forme": "buggy", "vitesse": -1, "acceleration": 0, "maniabilite": 1},
	{"nom": "Bolide", "forme": "bolide", "vitesse": 1, "acceleration": 0, "maniabilite": -1},
	{"nom": "Tracteur", "forme": "tracteur", "vitesse": -1, "acceleration": 1, "maniabilite": 0},
	{"nom": "Cagette", "forme": "cagette", "vitesse": 0, "acceleration": -1, "maniabilite": 1},
]
