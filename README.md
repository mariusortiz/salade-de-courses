# Salade de Courses

Un jeu de course de karts en 3D où les pilotes sont des fruits.
Projet de famille, fait avec le moteur de jeu [Godot](https://godotengine.org) : on apprend à fabriquer un jeu en le modifiant.

## Jouer

Dans le navigateur, sans rien installer : <https://mariusortiz.github.io/salade-de-courses/>

Pour modifier le jeu, il faut Godot :

1. Installer Godot 4.7 ou plus récent (gratuit) : <https://godotengine.org/download>
2. Ouvrir Godot, cliquer sur « Importer », choisir le fichier `project.godot` de ce dossier.
3. Appuyer sur F5 (ou le bouton ▶ en haut à droite).

- 1 joueur : les flèches, ou Z Q S D.
- 2 joueurs sur le même écran : joueur 1 les flèches, joueur 2 Z Q S D.
- Manette : le stick pour tourner, A pour accélérer, B pour freiner, X ou RB pour déraper.
- Déraper : tenir Espace (ou Maj) en tournant. À deux : Entrée pour le joueur 1, Espace pour le joueur 2.
  Le kart se met en travers et des étincelles apparaissent. Quand elles deviennent jaunes puis roses,
  relâcher donne un turbo.

Si le kart sort de la piste, il y est reposé au bout de deux secondes.

## Modifier le jeu

Trois fichiers sont faits pour être changés. Chacun commence par son mode d'emploi.

| Fichier | Ce qu'on y change |
| --- | --- |
| `donnees/circuits.gd` | Les circuits : la liste des points par où passe la route (avec leur hauteur), les turbos, les tremplins |
| `donnees/pilotes.gd` | Les fruits : nom, forme, couleurs, vitesse, accélération, maniabilité, modèle 3D |
| `donnees/reglages.gd` | Le titre, la gravité, l'adhérence, la force du turbo, le niveau des ordinateurs, les couleurs |

Le reste du code est dans `jeu/` :

- `piste.gd` construit la route, les barrières et le décor à partir des points du circuit ;
- `kart.gd` gère la conduite (une boule qui roule sur la piste, avec le fruit posé dessus) ;
- `fruit.gd` dessine le fruit et son kart ;
- `course.gd` gère le départ, les écrans des joueurs et le classement ;
- `main.gd` gère le menu.

## Utiliser des modèles 3D

Les fruits et les karts sont faits de formes simples en attendant mieux. Pour les remplacer :

1. Trouver un modèle gratuit au format `.glb`. Bonnes adresses, sous licence CC0 (libre, sans obligation) :
   [Kenney](https://kenney.nl/assets), [Quaternius](https://quaternius.com), [Poly Pizza](https://poly.pizza)
   (sur Poly Pizza, vérifier la licence de chaque modèle).
2. Le déposer dans le dossier `modeles/`, par exemple `modeles/pomme.glb`. Godot l'importe tout seul.
3. Dans `donnees/pilotes.gd`, remplacer `"modele": ""` par `"modele": "res://modeles/pomme.glb"`.
4. Régler `modele_taille` si le modèle est trop grand ou trop petit, et `modele_rotation`
   (90, 180, 270) s'il roule de travers.

Noter dans `modeles/CREDITS.md` d'où vient chaque modèle et sa licence.

## Vérifier que tout marche

Faire courir les ordinateurs seuls sur tous les circuits, sans ouvrir de fenêtre :

```
godot --headless --path . --fixed-fps 60 -- --simulation
```

Chaque kart doit arriver. « Retours en piste » compte les fois où un kart est sorti de la route.

## Mettre en ligne

```
./publier.sh
```

Le script exporte le jeu pour le navigateur et l'envoie sur GitHub Pages (branche `gh-pages`).
Il faut avoir installé une fois les modèles d'export Web de Godot (Éditeur > Gérer les modèles d'export).

## Idées pour la suite

Le turbo et le tremplin sont là pour tester. Les vrais bonus, pièges et circuits sont à inventer :
des objets à ramasser, des bruitages, un chrono du meilleur tour, de nouveaux décors.

## Règles du projet

- Le jeu est original : on s'inspire d'un genre, on ne recopie pas les personnages, objets,
  circuits ou musiques d'un jeu existant.
- Le dépôt est public : pas de prénoms, de photos, de voix ni d'informations personnelles.
- On n'ajoute que des ressources dont la licence le permet (CC0 de préférence).
