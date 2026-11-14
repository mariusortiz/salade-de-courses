# ─────────────────────────────────────────────────────────────
#  LE MODE SKATE
#  Dans le skatepark, on ne fait pas la course : on fait des figures pour marquer
#  le plus de points possible avant la fin du temps.
#
#  Un combo, c'est tout ce qu'on enchaîne sans retoucher le sol (figures en l'air,
#  glissades sur les barres). Quand on retombe bien, on gagne :
#      (les points de toutes les figures)  x  (le nombre de figures)
#  Si on tombe, le combo est perdu. Refaire la même figure dans un combo rapporte moitié moins.
# ─────────────────────────────────────────────────────────────
extends RefCounted

const DUREE := 120.0   # la durée d'une session, en secondes

# ── Le skateur ───────────────────────────────────────────────
const VITESSE := 15.0        # la vitesse maximum en poussant (en descente on peut aller plus vite)
const POUSSEE := 9.0         # la force quand on pousse
const BRAQUAGE := 2.6        # la vitesse à laquelle on tourne au sol
const GRAVITE := 18.0        # plus c'est grand, plus on retombe vite
const SAUT := 7.5            # la force du saut
const TOUPIE_VITESSE := 6.0  # la vitesse à laquelle on tourne sur soi-même en l'air
const SALTO_VITESSE := 7.0   # la vitesse des saltos
const TONNEAU_DUREE := 0.5   # le temps que prend un tonneau, en secondes
const CHUTE_DUREE := 1.3     # le temps qu'on reste par terre après une chute

# ── Les figures ──────────────────────────────────────────────
#  nom     le nom affiché à l'écran
#  points  ce que rapporte la figure
const FIGURES := {
	"toupie": {"nom": "Toupie", "points": 100},          # par demi-tour sur soi-même
	"salto": {"nom": "Salto", "points": 400},            # par tour complet, en avant ou en arrière
	"tonneau": {"nom": "Tonneau", "points": 250},        # un tour sur le côté
	"attrape": {"nom": "Attrapé", "points": 300},        # par seconde où on tient sa planche
	"glissade": {"nom": "Glissade", "points": 250},      # par seconde sur une barre
	"grand_saut": {"nom": "Grand saut", "points": 40},   # par mètre de hauteur (à partir de 2,5 m)
}

# ── Les graines gagnées ──────────────────────────────────────
const POINTS_PAR_GRAINE := 400   # une graine tous les 400 points...
const GRAINES_MAXIMUM := 60      # ...mais pas plus de 60 par session
const GRAINES_RECORD := 30       # en plus, quand on bat son record

# ── Les planches (on choisit dans le menu, ça ne change que l'allure) ──
const PLANCHES := [
	{"nom": "Skateboard", "forme": "skate"},
	{"nom": "Longboard", "forme": "longboard"},
]

# ── Le skatepark ─────────────────────────────────────────────
#  Le skatepark est un grand rectangle. Tout le tour, le sol remonte en rampe arrondie.
#  x va de -LARGEUR/2 à LARGEUR/2 (gauche à droite), z de -PROFONDEUR/2 à PROFONDEUR/2.
const LARGEUR := 90.0
const PROFONDEUR := 60.0
const RAYON_DES_BORDS := 6.0   # la taille des rampes du tour

#  Ce qu'on pose dedans :
#    "pyramide"  une butte à quatre pentes et au dessus plat.
#                x, z = son milieu ; longueur, largeur ; hauteur ; pente = la longueur des pentes
#    "tremplin"  une rampe qui lance en l'air. x, z = son pied ; angle = vers où elle monte
#                (0 = vers la droite, 90 = vers nous, 180 = vers la gauche, 270 = vers le fond)
#    "bosse"     une bosse toute ronde. x, z = son milieu ; rayon ; hauteur
#    "barre"     une barre pour glisser. de = un bout, a = l'autre bout ; hauteur
const MODULES := [
	{"sorte": "pyramide", "x": 0.0, "z": 0.0, "longueur": 20.0, "largeur": 15.0, "hauteur": 2.2, "pente": 5.0},
	{"sorte": "tremplin", "x": -30.0, "z": 0.0, "angle": 0.0, "longueur": 6.0, "largeur": 6.0, "hauteur": 1.8},
	{"sorte": "tremplin", "x": 30.0, "z": 0.0, "angle": 180.0, "longueur": 6.0, "largeur": 6.0, "hauteur": 1.8},
	{"sorte": "tremplin", "x": -24.0, "z": -15.0, "angle": 0.0, "longueur": 6.0, "largeur": 5.0, "hauteur": 2.0},
	{"sorte": "tremplin", "x": -5.0, "z": -15.0, "angle": 180.0, "longueur": 6.0, "largeur": 5.0, "hauteur": 2.0},
	{"sorte": "bosse", "x": 24.0, "z": 13.0, "rayon": 7.0, "hauteur": 1.6},
	{"sorte": "bosse", "x": -22.0, "z": 14.0, "rayon": 5.5, "hauteur": 1.2},
	{"sorte": "barre", "de": Vector2(6, -16), "a": Vector2(24, -16), "hauteur": 0.7},
	{"sorte": "barre", "de": Vector2(-12, 19), "a": Vector2(6, 19), "hauteur": 0.7},
	{"sorte": "barre", "de": Vector2(29, -6), "a": Vector2(36, -18), "hauteur": 0.8},
]

# Les couleurs : le sol (deux gris en damier), les rampes du tour, les modules, les murs, les barres.
const COULEUR_SOL := ["#7f8794", "#737b88"]
const COULEUR_BORDS := ["#c08a4e", "#ad7940"]
const COULEUR_PYRAMIDE := "#d9623f"
const COULEUR_TREMPLIN := "#2f8fc9"
const COULEUR_BOSSE := "#6f9f3f"
const COULEUR_MURS := ["#5c6bc0", "#ffd54f", "#ef5350", "#66bb6a"]
const COULEUR_BARRES := "#eceff1"
const MUSIQUE := "res://musique/course-2.mp3"
