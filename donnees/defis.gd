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
