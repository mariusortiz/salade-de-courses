# ─────────────────────────────────────────────────────────────
#  LES COUPES
#  Une coupe, c'est plusieurs courses de suite contre les mêmes adversaires.
#  À chaque course on gagne des points selon sa place, et à la fin on additionne tout.
#  Monter sur le podium donne un trophée (or, argent ou bronze) et un cadeau.
#
#    nom        le nom de la coupe
#    couleur    la couleur de sa carte dans le menu
#    circuits   les numéros des circuits, dans l'ordre des courses
#               (0 = le premier circuit de donnees/circuits.gd, 1 = le deuxième...)
#    cadeau     ce qu'on gagne la première fois qu'on monte sur le podium :
#                 {"pilote": "Mûre"}    le pilote de ce nom (dans donnees/pilotes.gd)
#                 {"vehicule": "Bolide doré"}  le véhicule de ce nom (dans donnees/vehicules.gd)
#                 {"coupe": "Coupe Mystère"}   ouvre une autre coupe
#    secrete    true = la coupe est cachée tant qu'une autre coupe ne l'a pas ouverte
#
#  Un pilote ou un véhicule qui est un cadeau porte le nom de sa coupe (clé "coupe") :
#  on ne peut pas le choisir tant qu'on n'a pas gagné cette coupe.
# ─────────────────────────────────────────────────────────────
extends RefCounted

const TOURS := 3                    # le nombre de tours de chaque course
const POINTS := [10, 7, 5, 3, 2, 1]  # les points gagnés en finissant 1er, 2e, 3e...
const GRAINES := [150, 100, 60]     # les graines en plus pour un trophée d'or, d'argent, de bronze
const TROPHEES := ["Or", "Argent", "Bronze"]
const COULEUR_TROPHEES := ["#ffd54f", "#cfd8dc", "#d7935b"]

# Les noms et les cadeaux sont provisoires : à remplacer par les idées des enfants.
const COUPES := [
	{
		"nom": "Coupe Cerise",
		"couleur": "#e53935",
		"circuits": [0, 1, 8],  # Le Verger, Le Grand Huit, Le Potager Géant
		"cadeau": {"pilote": "Mûre"},
	},
	{
		"nom": "Coupe Citron",
		"couleur": "#fdd835",
		"circuits": [5, 6, 7],  # La Pizza Géante, L'Aquarium, Le Frigo
		"cadeau": {"vehicule": "Bolide doré"},
	},
	{
		"nom": "Coupe Ananas",
		"couleur": "#fb8c00",
		"circuits": [4, 3, 2],  # La Grotte aux Cristaux, Le Grand Pic, La Comète
		"cadeau": {"coupe": "Coupe Mystère"},
	},
	{
		"nom": "Coupe Mystère",
		"couleur": "#8e24aa",
		"circuits": [1, 6, 3],  # provisoire : le nouveau circuit viendra ici
		"secrete": true,
	},
]
