# ─────────────────────────────────────────────────────────────
#  LES ÉPREUVES
#  Les différentes façons de jouer, choisies dans le menu.
#
#    cle      le nom de l'épreuve pour le jeu (ne pas le changer)
#    nom      le nom affiché dans le menu
#    texte    la règle, en une phrase
#    avions   true = on peut aussi y jouer en avion
#    seul     true = l'épreuve se joue à un seul joueur
#
#  Les réglages des épreuves (durées, nombre de graines...) sont dans reglages.gd.
# ─────────────────────────────────────────────────────────────
extends RefCounted

const EPREUVES := [
	{"cle": "course", "nom": "Course", "texte": "Le premier arrivé gagne.", "avions": true, "seul": false},
	{"cle": "elimination", "nom": "Élimination", "texte": "À la fin de chaque tour, le dernier est éliminé. Le dernier en piste gagne.", "avions": true, "seul": false},
	{"cle": "chrono", "nom": "Contre-la-montre", "texte": "Seul sur la piste : bats ton record, et le fantôme de ta meilleure course.", "avions": true, "seul": true},
	{"cle": "chasse", "nom": "Chasse aux graines", "texte": "Ramasse le plus de graines avant la fin du temps. Un pépin reçu en fait perdre deux.", "avions": false, "seul": false},
	{"cle": "patate", "nom": "Patate chaude", "texte": "Refile la patate en touchant un autre kart (ou avec un pépin) avant qu'elle n'éclate !", "avions": false, "seul": false},
]
