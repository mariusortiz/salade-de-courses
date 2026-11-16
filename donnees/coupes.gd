# ─────────────────────────────────────────────────────────────
#  LES COUPES
#  Une coupe, c'est plusieurs courses de suite contre les mêmes adversaires.
#  À chaque course on gagne des points selon sa place, et à la fin on additionne tout.
#  Monter sur le podium donne un trophée (or, argent ou bronze) et un cadeau.
#
#    nom        le nom de la coupe
#    couleur    la couleur de son nom dans le menu
#    circuits   les numéros des circuits, dans l'ordre des courses
#               (0 = le premier circuit de donnees/circuits.gd, 1 = le deuxième...)
#    cadeau     ce qu'on gagne la première fois qu'on monte sur le podium (on peut en mettre plusieurs) :
#                 "pilote": "Melon"        le pilote de ce nom (dans donnees/pilotes.gd)
#                 "vehicule": "Buggy"      le véhicule de ce nom (dans donnees/vehicules.gd)
#                 "coupe": "Coupe Bleue"   ouvre une autre coupe
#                 "skins": true            les skins des pilotes (la liste est plus bas)
#                 "sac": true              le sac de pépins : on démarre chaque course avec des pépins
#                 "pepins_dores": true     les pépins dorés : plus rapides, ils traversent les boucliers
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

const COUPES := [
	{
		"nom": "Coupe Cerise",
		"couleur": "#e53935",
		"circuits": [0, 1, 8],  # Le Verger, Le Grand Huit, Le Potager Géant
		"cadeau": {"pilote": "Melon"},
	},
	{
		"nom": "Coupe Citron",
		"couleur": "#fdd835",
		"circuits": [5, 6, 7],  # La Pizza Géante, L'Aquarium, Le Frigo
		"cadeau": {"sac": true},
	},
	{
		"nom": "Coupe Ananas",
		"couleur": "#fb8c00",
		"circuits": [4, 3, 2],  # La Grotte aux Cristaux, Le Grand Pic, La Comète
		"cadeau": {"skins": true, "coupe": "Coupe Bleue"},
	},
	{
		"nom": "Coupe Bleue",
		"couleur": "#42a5f5",
		"circuits": [1, 6, 3],  # Le Grand Huit, L'Aquarium, Le Grand Pic
		"cadeau": {"pepins_dores": true},
		"secrete": true,
	},
]

# Le sac de pépins : combien de pépins on a au départ de chaque course.
const SAC_DE_PEPINS := 5

# Les pépins dorés
const PEPIN_DORE_VITESSE := 15.0  # la vitesse en plus d'un pépin normal
const PEPIN_DORE_TOUPIE := 1.5    # le tête-à-queue dure 1,5 fois plus longtemps

# Les skins : de nouvelles couleurs pour les pilotes.
#    couleur  la couleur du fruit       kart   la couleur du kart
#    motif    "uni", "rayures" ou "points" (si on n'écrit rien, le fruit garde le sien)
# La première, « Normal », garde les couleurs du pilote.
const SKINS := [
	{"nom": "Normal"},
	{"nom": "Doré", "couleur": "#ffc107", "kart": "#263238", "motif": "uni"},
	{"nom": "Nuit", "couleur": "#283593", "kart": "#00e5ff", "motif": "points"},
	{"nom": "Glace", "couleur": "#b3e5fc", "kart": "#eceff1", "motif": "uni"},
	{"nom": "Zèbre", "couleur": "#fafafa", "kart": "#212121", "motif": "rayures"},
	{"nom": "Lave", "couleur": "#ff5722", "kart": "#212121", "motif": "rayures"},
	{"nom": "Fraise", "couleur": "#e91e63", "kart": "#f8bbd0", "motif": "points"},
]
