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
const NIVEAU_ORDIS := 0.9     # vitesse des karts de l'ordinateur (1 = aussi rapides que toi)

# Le décor
const HAUTEUR_BARRIERES := 0.9
const NOMBRE_ARBRES := 60
const COULEUR_CIEL := ["#3f8fe0", "#bfe6ff"]  # en haut, puis à l'horizon
const COULEUR_HERBE := "#4f9e3a"
const COULEUR_ROUTE := ["#5b6170", "#4f5564"]
const COULEUR_BARRIERES := ["#e53935", "#f5f5f5"]
const COULEUR_TURBO := "#ffb300"
const COULEUR_TREMPLIN := "#ff7043"
