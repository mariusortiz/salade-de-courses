# ─────────────────────────────────────────────────────────────
#  LES PILOTES
#  Chaque pilote est un fruit avec son kart.
#
#    nom           le nom affiché dans le jeu
#    forme         "ronde", "longue", "pointue", "poire" ou "grappe"
#    motif         "uni", "rayures" ou "points" : le dessin sur la peau du fruit
#    taille        1 = normal, 1.3 = gros, 0.8 = petit
#    couleur       la couleur du fruit
#    kart          la couleur du kart
#    vitesse       de 1 (lent) à 5 (très rapide)
#    acceleration  de 1 (démarre doucement) à 5 (démarre fort)
#    maniabilite   de 1 (tourne mal) à 5 (tourne très bien)
#    modele        "" = formes simples. Sinon le chemin d'un modèle 3D,
#                  par exemple "res://modeles/pomme.glb" (voir le README)
#    modele_taille    pour agrandir (2) ou rétrécir (0.5) le modèle
#    modele_rotation  à changer (90, 180, 270) si le modèle regarde de travers
#
#  Il n'y a que NOMBRE_DE_KARTS karts par course (voir reglages.gd) : les joueurs, plus des
#  pilotes tirés au hasard.
#
#  Astuce : un bon pilote n'a pas 5 partout. Ici le total fait 9 pour tout le monde.
# ─────────────────────────────────────────────────────────────
extends RefCounted

const PILOTES := [
	{"nom": "Pépin", "forme": "ronde", "motif": "uni", "taille": 1.0, "couleur": "#e53935", "kart": "#1e88e5", "vitesse": 3, "acceleration": 3, "maniabilite": 3, "modele": "", "modele_taille": 1.0, "modele_rotation": 0},
	{"nom": "Zeste", "forme": "ronde", "motif": "uni", "taille": 0.8, "couleur": "#fdd835", "kart": "#43a047", "vitesse": 2, "acceleration": 4, "maniabilite": 3, "modele": "", "modele_taille": 1.0, "modele_rotation": 0},
	{"nom": "Courbe", "forme": "longue", "motif": "uni", "taille": 1.0, "couleur": "#ffca28", "kart": "#8e24aa", "vitesse": 4, "acceleration": 2, "maniabilite": 3, "modele": "", "modele_taille": 1.0, "modele_rotation": 0},
	{"nom": "Mara", "forme": "pointue", "motif": "points", "taille": 1.0, "couleur": "#d81b60", "kart": "#fb8c00", "vitesse": 2, "acceleration": 3, "maniabilite": 4, "modele": "", "modele_taille": 1.0, "modele_rotation": 0},
	{"nom": "Pastek", "forme": "ronde", "motif": "rayures", "taille": 1.3, "couleur": "#2e7d32", "kart": "#c62828", "vitesse": 5, "acceleration": 2, "maniabilite": 2, "modele": "", "modele_taille": 1.0, "modele_rotation": 0},
	{"nom": "Grappe", "forme": "grappe", "motif": "uni", "taille": 0.9, "couleur": "#6a1b9a", "kart": "#00acc1", "vitesse": 3, "acceleration": 2, "maniabilite": 4, "modele": "", "modele_taille": 1.0, "modele_rotation": 0},
	{"nom": "Clem", "forme": "ronde", "motif": "uni", "taille": 0.95, "couleur": "#fb8c00", "kart": "#3949ab", "vitesse": 3, "acceleration": 4, "maniabilite": 2, "modele": "", "modele_taille": 1.0, "modele_rotation": 0},
	{"nom": "Poirette", "forme": "poire", "motif": "uni", "taille": 1.0, "couleur": "#c0ca33", "kart": "#6d4c41", "vitesse": 4, "acceleration": 3, "maniabilite": 2, "modele": "", "modele_taille": 1.0, "modele_rotation": 0},
	{"nom": "Griotte", "forme": "ronde", "motif": "uni", "taille": 0.7, "couleur": "#b71c1c", "kart": "#f48fb1", "vitesse": 2, "acceleration": 3, "maniabilite": 4, "modele": "", "modele_taille": 1.0, "modele_rotation": 0},
	{"nom": "Coco", "forme": "ronde", "motif": "uni", "taille": 1.2, "couleur": "#6d4c41", "kart": "#26a69a", "vitesse": 4, "acceleration": 1, "maniabilite": 4, "modele": "", "modele_taille": 1.0, "modele_rotation": 0},
	{"nom": "Mimi", "forme": "ronde", "motif": "uni", "taille": 0.75, "couleur": "#3f51b5", "kart": "#ffca28", "vitesse": 1, "acceleration": 4, "maniabilite": 4, "modele": "", "modele_taille": 1.0, "modele_rotation": 0},
	{"nom": "Kiko", "forme": "ronde", "motif": "points", "taille": 0.9, "couleur": "#8d6e3f", "kart": "#7cb342", "vitesse": 3, "acceleration": 2, "maniabilite": 4, "modele": "", "modele_taille": 1.0, "modele_rotation": 0},
]
