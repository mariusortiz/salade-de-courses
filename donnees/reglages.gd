# ─────────────────────────────────────────────────────────────
#  LES RÉGLAGES
#  Change un nombre, enregistre, relance le jeu, et regarde ce que ça fait.
# ─────────────────────────────────────────────────────────────
extends RefCounted

const TITRE := "Salade de Courses"

# La conduite
const GRAVITE := 2.5          # 1 = comme sur Terre. Plus grand = on retombe plus vite après un saut
const ADHERENCE := 7.0        # petit = le kart glisse dans les virages, grand = il colle à la route
const HERBE := 0.45           # vitesse sur l'herbe (0.45 = 45 % de la vitesse normale)
const TURBO_FORCE := 1.6      # 1.6 = 60 % plus vite pendant un turbo
const TURBO_DUREE := 1.5      # en secondes
const NOMBRE_DE_KARTS := 6    # combien de karts au départ, joueurs compris
const CHOIX_DE_TOURS := [1, 3, 5]  # les nombres de tours proposés dans le menu
const NIVEAU_ORDIS := 0.9     # vitesse des karts de l'ordinateur (1 = aussi rapides que toi)

# Le dérapage
const DERAPAGE_GLISSE := 0.35       # petit = le kart glisse beaucoup en dérapage
const DERAPAGE_PETIT_TURBO := 0.8   # secondes de dérapage pour gagner un petit turbo
const DERAPAGE_GRAND_TURBO := 1.8   # secondes de dérapage pour gagner un grand turbo
const COULEUR_ETINCELLES := ["#ffffff", "#ffd54f", "#ff4081"]  # au début, petit turbo, grand turbo

# Le mode Avions
const AVION_MANCHE := 1.8     # la vitesse à laquelle l'avion lève ou baisse le nez
const AVION_PLAFOND := 32.0   # la hauteur maximum au-dessus de la route
const ANNEAUX_ECART := 40.0   # la distance entre deux anneaux, à peu près
const COULEUR_ANNEAUX := ["#ffffff", "#ffb300", "#ffee58"]  # normal, turbo, le prochain à traverser

# Le saut
const SAUT_FORCE := 6.5       # plus grand = on saute plus haut (au-dessus de 7, on passe par-dessus les barrières)

# Les bonus : chaque cagette donne une chose au hasard dans cette liste.
# Répète un mot pour qu'il sorte plus souvent. Les mots possibles :
# "pepins" (des pépins à tirer), "turbo", "bouclier", "jus" (une flaque à verser derrière soi).
const BONUS := ["pepins", "pepins", "turbo", "bouclier", "jus"]
const CAGETTE_RETOUR := 4.0   # secondes avant qu'une cagette ramassée revienne
const PEPINS_PAR_BONUS := 3
const PEPINS_MAXIMUM := 9
const PEPIN_VITESSE := 35.0   # la vitesse du pépin, en plus de celle du kart qui tire
const TETE_A_QUEUE := 1.2     # secondes perdues quand on reçoit un pépin
const BOUCLIER_DUREE := 8.0   # secondes de protection (un pépin reçu fait éclater le bouclier)
const JUS_DUREE := 15.0       # secondes pendant lesquelles la flaque reste sur la route
const JUS_RALENTI := 0.5      # vitesse dans le jus (0.5 = moitié moins vite)
const ORDIS_UTILISENT_BONUS := true  # false = les ordinateurs ne tirent pas et ne versent rien

# La musique (des fichiers du dossier musique/). 0 = pas de musique, 1 = fort.
const VOLUME_MUSIQUE := 0.5
const MUSIQUE_MENU := "res://musique/menu.mp3"
const MUSIQUE_ARRIVEE := "res://musique/arrivee.mp3"

# Le décor
const HAUTEUR_BARRIERES := 0.9
const NOMBRE_ARBRES := 90
const NOMBRE_ROCHERS := 25
const NOMBRE_BUISSONS := 40
const NOMBRE_FLEURS := 500
const NOMBRE_NUAGES := 14
const COULEUR_CIEL := ["#3f8fe0", "#bfe6ff"]  # en haut, puis à l'horizon
const COULEUR_HERBE := ["#3f8a30", "#5cb046"]  # deux verts mélangés
const COULEUR_ROUTE := ["#5b6170", "#4f5564"]
const COULEUR_LIGNES := ["#f5f5f5", "#ffd54f"]  # les bords de la route, puis les pointillés du milieu
const COULEUR_BARRIERES := ["#e53935", "#f5f5f5"]
const COULEUR_TURBO := "#ffb300"
const COULEUR_TREMPLIN := "#ff7043"
