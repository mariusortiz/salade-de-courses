# ─────────────────────────────────────────────────────────────
#  LES DÉFIS DU JOUR
#  Chaque jour, le jeu choisit un circuit, un mode (karts ou avions) et une règle
#  dans cette liste. Tout le monde a le même défi le même jour.
#
#    nom     le nom de la règle, affiché dans le menu
#    texte   une phrase qui l'explique
#    effet   ce que la règle change. Les effets possibles :
#              ""           rien de spécial
#              "pepins"     tout le monde part avec le maximum de pépins
#              "rapides"    les ordinateurs sont aussi rapides que le joueur
#              "obstacles"  deux fois plus d'obstacles
#              "lune"       la gravité est deux fois plus faible (karts seulement)
#              "patinoire"  la route glisse (karts seulement)
#
#  On gagne une étoile en finissant la course, deux sur le podium, trois en gagnant.
#
#  LES DÉFIS DES CIRCUITS
#  Chaque circuit a trois défis, à réussir quand on veut. Ils se jouent seul, en 3 tours.
#  Un circuit peut choisir les siens avec "defis" (voir donnees/circuits.gd), sinon il en
#  reçoit trois : le chrono, un défi de kart et un défi d'avion.
#
#    nom      le nom du défi
#    texte    ce qu'il faut faire (%d est remplacé par le nombre « combien »)
#    avions   true = le défi se joue en avion
#    combien  le nombre à atteindre
# ─────────────────────────────────────────────────────────────
extends RefCounted

const REGLES := [
	{"nom": "Course classique", "texte": "Pas de piège aujourd'hui : que le meilleur gagne !", "effet": ""},
	{"nom": "Pluie de pépins", "texte": "Tout le monde part avec plein de pépins.", "effet": "pepins"},
	{"nom": "Ordinateurs en forme", "texte": "Les ordinateurs vont aussi vite que toi.", "effet": "rapides"},
	{"nom": "Champ d'obstacles", "texte": "Il y a deux fois plus d'obstacles.", "effet": "obstacles"},
	{"nom": "Gravité de la Lune", "texte": "On retombe tout doucement après un saut.", "effet": "lune"},
	{"nom": "Patinoire", "texte": "La route glisse comme de la glace.", "effet": "patinoire"},
]

const ETOILES := ["Finir la course", "Finir sur le podium", "Gagner la course"]

const EPREUVES := {
	"chrono": {"nom": "Contre la montre", "texte": "Finis les 3 tours en moins de %d secondes.", "avions": false, "combien": 0},
	"sans_faute": {"nom": "Sans une égratignure", "texte": "Finis sans toucher d'obstacle et sans sortir de la piste.", "avions": false, "combien": 0},
	"tireur": {"nom": "Tireur d'élite", "texte": "Touche %d adversaires avec tes pépins.", "avions": false, "combien": 3},
	"gourmand": {"nom": "Gourmand", "texte": "Ramasse %d cagettes.", "avions": false, "combien": 6},
	"glisse": {"nom": "Roi de la glisse", "texte": "Gagne %d turbos en dérapant.", "avions": false, "combien": 4},
	"as": {"nom": "As du ciel", "texte": "En avion, finis sans rater un seul anneau.", "avions": true, "combien": 0},
	"vol": {"nom": "Premier de la classe", "texte": "En avion, gagne la course.", "avions": true, "combien": 0},
}

# Pour le chrono : la vitesse moyenne à tenir, en mètres par seconde. Plus grand = plus dur.
const CHRONO_VITESSE := 26.0

# Les défis donnés aux circuits qui n'ont pas choisi les leurs : le chrono, puis un de chaque liste, à tour de rôle.
const AU_CHOIX_KART := ["sans_faute", "tireur", "gourmand", "glisse"]
const AU_CHOIX_AVION := ["as", "vol"]
