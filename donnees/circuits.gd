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
#    bonus      pareil pour les rangées de cagettes à bonus
#    obstacles  où poser les obstacles (si on n'écrit rien : 0.3, 0.5, 0.7 et 0.9).
#               Une fois sur deux ils ne bougent pas, sinon ils traversent la route.
#    raccourcis des passages étroits qui coupent tout droit : [où il commence, où il finit].
#               Il faut que la route fasse un détour entre les deux, sinon on ne gagne rien.
#    musique    le fichier de musique du circuit, dans le dossier musique/
#    defis      les trois défis du circuit (si on n'écrit rien, le jeu en choisit trois).
#               Les défis possibles sont dans donnees/defis.gd.
#    decor      "campagne" (si on n'écrit rien), "espace", "montagne", "grotte", "pizza",
#               "aquarium", "frigo" ou "potager". Les décors sont fabriqués dans jeu/decor.gd.
#               Certains changent la conduite : on flotte dans l'espace et dans l'aquarium,
#               ça glisse dans le frigo, et dans l'espace il n'y a pas de sol sous la route !
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
		"bonus": [0.15, 0.4, 0.85],
		"raccourcis": [[0.455, 0.796]],
		"musique": "res://musique/course-1.mp3",
		"points": [
			Vector3(0, 0, 0),
			Vector3(60, 0, 0),
			Vector3(115, 4, 0),
			Vector3(160, 8, -30),
			Vector3(160, 8, -85),
			Vector3(115, 3, -115),
			Vector3(60, 0, -160),  # le détour : la route fait le tour, le raccourci coupe tout droit
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
		"bonus": [0.12, 0.4, 0.8],
		"musique": "res://musique/course-2.mp3",
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
	{
		"nom": "La Comète",
		"decor": "espace",
		"tours": 3,
		"largeur": 14.0,
		"turbos": [0.05, 0.55],
		"tremplins": [],
		"bonus": [0.2, 0.45, 0.75],
		"musique": "res://musique/espace.ogg",
		"points": [
			Vector3(93, 5.6, -23),
			Vector3(79, 3.1, -54),
			Vector3(52, 1.2, -53),
			Vector3(18, 0.1, -22),
			Vector3(-19, 0.1, 23),
			Vector3(-53, 1.2, 54),
			Vector3(-79, 3.1, 53),
			Vector3(-93, 5.7, 22),
			Vector3(-93, 8.4, -23),
			Vector3(-79, 10.9, -54),
			Vector3(-52, 12.8, -53),
			Vector3(-18, 13.9, -22),
			Vector3(19, 13.9, 23),
			Vector3(53, 12.8, 54),
			Vector3(79, 10.9, 53),
			Vector3(93, 8.3, 22),
		],
	},
	{
		"nom": "Le Grand Pic",
		"decor": "montagne",
		"tours": 3,
		"largeur": 12.0,
		"turbos": [0.03],
		"tremplins": [],
		"bonus": [0.15, 0.5, 0.8],
		"raccourcis": [[0.363, 0.588]],
		"musique": "res://musique/montagne.ogg",
		"points": [
			Vector3(119, 0, 0),
			Vector3(102, 0.9, 32),
			Vector3(67, 3.5, 51),
			Vector3(35, 7.4, 65),
			Vector3(0, 12, 80),
			Vector3(-45, 16.6, 83),
			Vector3(-81, 20.5, 62),
			Vector3(-92, 23.1, 29),
			Vector3(-136, 24, 0),  # le détour : la route fait le tour, le raccourci coupe tout droit
			Vector3(-92, 23.1, -29),
			Vector3(-81, 20.5, -62),
			Vector3(-45, 16.6, -83),
			Vector3(0, 12, -80),
			Vector3(35, 7.4, -65),
			Vector3(67, 3.5, -51),
			Vector3(102, 0.9, -32),
		],
	},
	{
		"nom": "La Grotte aux Cristaux",
		"decor": "grotte",
		"tours": 3,
		"largeur": 12.0,
		"turbos": [0.05, 0.5],
		"tremplins": [],
		"bonus": [0.2, 0.6, 0.85],
		"raccourcis": [[0.531, 0.813]],
		"musique": "res://musique/grotte.ogg",
		"points": [
			Vector3(114, 3, 0),
			Vector3(92, 5.1, 24),
			Vector3(61, 6, 38),
			Vector3(38, 5.1, 57),
			Vector3(0, 3, 71),
			Vector3(-38, 0.9, 57),
			Vector3(-61, 0, 38),
			Vector3(-92, 0.9, 24),
			Vector3(-114, 3, 0),
			Vector3(-92, 5.1, -24),
			Vector3(-61, 6, -38),
			Vector3(-59, 5.1, -97),  # le détour : la route fait le tour, le raccourci coupe tout droit
			Vector3(0, 3, -71),
			Vector3(38, 0.9, -57),
			Vector3(61, 0, -38),
			Vector3(92, 0.9, -24),
		],
	},
	{
		"nom": "La Pizza Géante",
		"decor": "pizza",
		"tours": 3,
		"largeur": 12.0,
		"turbos": [0.1, 0.6],
		"tremplins": [],
		"bonus": [0.25, 0.5, 0.85],
		"raccourcis": [[0.404, 0.78]],
		"musique": "res://musique/pizza.ogg",
		"points": [
			Vector3(87, 0, 0),
			Vector3(67, 0, 30),
			Vector3(49, 0.1, 54),
			Vector3(27, 1.2, 83),
			Vector3(-8, 3.9, 73),
			Vector3(-37, 5.9, 63),
			Vector3(-71, 5.2, 51),
			Vector3(-72, 2.5, 15),
			Vector3(-72, 0.4, -15),
			Vector3(-99, 0, -72),  # le détour : la route fait le tour, le raccourci coupe tout droit
			Vector3(-37, 0, -63),
			Vector3(-8, 0, -73),
			Vector3(27, 0, -83),
			Vector3(49, 0, -54),
			Vector3(67, 0, -30),
		],
	},
	{
		"nom": "L'Aquarium",
		"decor": "aquarium",
		"tours": 3,
		"largeur": 12.0,
		"turbos": [0.06, 0.55],
		"tremplins": [],
		"bonus": [0.2, 0.45, 0.8],
		"raccourcis": [[0.481, 0.764]],
		"musique": "res://musique/aquarium.ogg",
		"points": [
			Vector3(105, 0, 26),
			Vector3(97, 0.9, 38),
			Vector3(74, 3, 35),
			Vector3(40, 5.1, 28),
			Vector3(0, 6, 24),
			Vector3(-40, 5.1, 28),
			Vector3(-74, 3, 35),
			Vector3(-97, 0.9, 38),
			Vector3(-105, 0, 26),
			Vector3(-97, 0.9, -1),
			Vector3(-74, 3, -35),
			Vector3(-62, 5.1, -104),  # le détour : la route fait le tour, le raccourci coupe tout droit
			Vector3(0, 6, -76),
			Vector3(40, 5.1, -65),
			Vector3(74, 3, -35),
			Vector3(97, 0.9, -1),
		],
	},
	{
		"nom": "Le Frigo",
		"decor": "frigo",
		"tours": 3,
		"largeur": 13.0,
		"turbos": [0.05],
		"tremplins": [],
		"bonus": [0.2, 0.5, 0.8],
		"raccourcis": [[0.292, 0.598]],
		"musique": "res://musique/frigo.ogg",
		"points": [
			Vector3(0, 0, 55),
			Vector3(-52, 0, 52),
			Vector3(-75, 0, 45),
			Vector3(-88, 0, 31),
			Vector3(-92, 0, 0),
			Vector3(-88, 0, -31),
			Vector3(-75, 0, -45),
			Vector3(-58, 0, -97),  # le détour : la route fait le tour, le raccourci coupe tout droit
			Vector3(0, 0, -55),
			Vector3(52, 0, -52),
			Vector3(75, 0, -45),
			Vector3(88, 0, -31),
			Vector3(92, 0, 0),
			Vector3(88, 0, 31),
			Vector3(75, 0, 45),
			Vector3(52, 0, 52),
		],
	},
	{
		"nom": "Le Potager Géant",
		"decor": "potager",
		"tours": 3,
		"largeur": 12.0,
		"turbos": [0.05, 0.5],
		"tremplins": [],
		"bonus": [0.15, 0.4, 0.7],
		"raccourcis": [[0.327, 0.612]],
		"musique": "res://musique/potager.ogg",
		"points": [
			Vector3(70, 2.1, 34),
			Vector3(38, 2.8, 44),
			Vector3(15, 0.6, 58),
			Vector3(-16, 0.4, 77),
			Vector3(-54, 2.6, 70),
			Vector3(-68, 2.4, 37),
			Vector3(-62, 0.2, 7),
			Vector3(-109, 0.9, -14),  # le détour : la route fait le tour, le raccourci coupe tout droit
			Vector3(-66, 2.9, -51),
			Vector3(-41, 1.8, -77),
			Vector3(-2, 0, -71),
			Vector3(24, 1.5, -51),
			Vector3(49, 3, -41),
			Vector3(82, 1.2, -26),
			Vector3(94, 0.1, 7),
		],
	},
]
