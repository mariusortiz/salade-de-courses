# ─────────────────────────────────────────────────────────────
#  LES CIRCUITS
#  Un circuit est une liste de points. La route passe par chaque point,
#  dans l'ordre, puis revient au premier : ça fait une boucle.
#
#  Un point s'écrit  Vector3(x, hauteur, z)  en mètres :
#    x        vers la droite (négatif = vers la gauche)
#    hauteur  0 = au sol, 8 = une belle colline
#    z        négatif = vers le fond, positif = vers nous
#
#  Le départ est au premier point, en direction du deuxième.
#
#    largeur    la largeur de la route
#    tours      le nombre de tours
#    turbos     où poser les turbos : 0.0 = au départ, 0.5 = à la moitié du tour
#    tremplins  pareil pour les tremplins (à mettre dans une ligne droite)
#
#  Conseils : garde au moins 30 mètres entre deux points, et ne monte pas
#  de plus de 4 mètres d'un point au suivant.
# ─────────────────────────────────────────────────────────────
extends RefCounted

const CIRCUITS := [
	{
		"nom": "Le Verger",
		"tours": 3,
		"largeur": 12.0,
		"turbos": [0.04, 0.6],
		"tremplins": [0.64],
		"points": [
			Vector3(0, 0, 0),
			Vector3(60, 0, 0),
			Vector3(115, 4, 0),
			Vector3(160, 8, -30),
			Vector3(160, 8, -85),
			Vector3(115, 3, -115),
			Vector3(60, 0, -115),
			Vector3(0, 0, -115),
			Vector3(-45, 0, -85),
			Vector3(-45, 0, -30),
		],
	},
	{
		"nom": "Le Grand Huit",
		"tours": 3,
		"largeur": 12.0,
		"turbos": [0.0, 0.62],
		"tremplins": [],
		"points": [
			Vector3(-50, 0, 0),
			Vector3(0, 0, 0),
			Vector3(55, 0, 0),
			Vector3(95, 0, -25),
			Vector3(95, 2, -65),
			Vector3(55, 5, -90),
			Vector3(8, 7, -60),
			Vector3(0, 7, 0),
			Vector3(0, 5, 45),
			Vector3(-25, 2, 85),
			Vector3(-70, 0, 85),
			Vector3(-98, 0, 50),
			Vector3(-92, 0, 15),
		],
	},
]
