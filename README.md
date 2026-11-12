# Salade de Courses

Un jeu de course de karts en 3D où les pilotes sont des fruits.
Projet de famille, fait avec le moteur de jeu [Godot](https://godotengine.org) : on apprend à fabriquer un jeu en le modifiant.

## Jouer

Dans le navigateur, sans rien installer : <https://mariusortiz.github.io/salade-de-courses/>

Pour modifier le jeu, il faut Godot :

1. Installer Godot 4.7 ou plus récent (gratuit) : <https://godotengine.org/download>
2. Ouvrir Godot, cliquer sur « Importer », choisir le fichier `project.godot` de ce dossier.
3. Appuyer sur F5 (ou le bouton ▶ en haut à droite).

| Action | 1 joueur | À deux : joueur 1 | À deux : joueur 2 | Manette |
| --- | --- | --- | --- | --- |
| Conduire | flèches ou Z Q S D | flèches | Z Q S D | stick, A accélérer, B freiner |
| Déraper | Maj | J (ou Entrée) | Maj | RB |
| Sauter | Espace | K | Espace | LB |
| Tirer un pépin | F (ou Entrée) | L | F | X |
| Utiliser l'objet | E | M | E | Y |

- Déraper : tenir le bouton en tournant. Le kart se met en travers et des étincelles apparaissent.
  Quand elles deviennent jaunes puis roses, relâcher donne un turbo.
- Les cagettes sur la route donnent un bonus au hasard : des pépins à tirer (un kart touché fait
  un tête-à-queue), un turbo, un bouclier, ou du jus à verser derrière soi pour ralentir les autres.
  Les pépins se tirent tout de suite ; le turbo, le bouclier et le jus se gardent en réserve.
- Sauter permet de passer au-dessus d'une flaque de jus ou d'un pépin.

Si le kart sort de la piste, il y est reposé au bout de deux secondes.

## Modifier le jeu

Quatre fichiers sont faits pour être changés. Chacun commence par son mode d'emploi.

| Fichier | Ce qu'on y change |
| --- | --- |
| `donnees/circuits.gd` | Les circuits : la liste des points par où passe la route (avec leur hauteur), les turbos, les tremplins, les cagettes à bonus, la musique |
| `donnees/pilotes.gd` | Les fruits : nom, forme, motif de la peau, couleurs, vitesse, accélération, maniabilité, modèle 3D |
| `donnees/vehicules.gd` | Les véhicules : nom, forme, et ce qu'ils ajoutent ou enlèvent en vitesse, accélération, maniabilité |
| `donnees/reglages.gd` | Le titre, la gravité, l'adhérence, le turbo, le saut, les bonus, le volume de la musique, le niveau des ordinateurs, le nombre de karts, les nombres de tours proposés, le décor, les couleurs |

Le reste du code est dans `jeu/` :

- `piste.gd` construit la route, les barrières, les cagettes et le décor à partir des points du circuit, et dessine les textures ;
- `kart.gd` gère la conduite (une boule qui roule sur la piste, avec le fruit posé dessus) ;
- `decor.gd` contient les décors (campagne, espace, montagne, grotte, pizza, aquarium, frigo, potager) : leurs couleurs, leur lumière, et les objets posés autour de la route ;
- `fruit.gd` dessine le fruit (avec ses bras et ses jambes) et son véhicule ;
- `course.gd` gère le départ, les touches, les bonus, les écrans des joueurs et le classement ;
- `main.gd` gère le menu et la musique.

## Ajouter un circuit ou un décor

Pour un nouveau circuit, copier un circuit dans `donnees/circuits.gd`, changer son nom et ses points,
et choisir son `decor`. Pour un nouveau décor, ouvrir `jeu/decor.gd` : ajouter une ambiance dans
`AMBIANCES` (les couleurs, la lumière, la gravité, l'adhérence) et une fonction du même nom qui pose
les objets. Le plus simple est de copier un décor existant et de le transformer.

## Utiliser des modèles 3D

Les fruits et les karts sont assemblés à partir de formes simples (boules, tubes, boîtes). Pour les remplacer par un modèle :

1. Trouver un modèle gratuit au format `.glb`. Bonnes adresses, sous licence CC0 (libre, sans obligation) :
   [Kenney](https://kenney.nl/assets), [Quaternius](https://quaternius.com), [Poly Pizza](https://poly.pizza)
   (sur Poly Pizza, vérifier la licence de chaque modèle).
2. Le déposer dans le dossier `modeles/`, par exemple `modeles/pomme.glb`. Godot l'importe tout seul.
3. Dans `donnees/pilotes.gd`, remplacer `"modele": ""` par `"modele": "res://modeles/pomme.glb"`.
4. Régler `modele_taille` si le modèle est trop grand ou trop petit, et `modele_rotation`
   (90, 180, 270) s'il roule de travers.

Noter dans `modeles/CREDITS.md` d'où vient chaque modèle et sa licence.

## Changer la musique

Les musiques sont dans le dossier `musique/` (format `.mp3` ou `.ogg`). Celle du menu et celle de
l'arrivée se choisissent dans `donnees/reglages.gd`, celle de chaque circuit dans `donnees/circuits.gd`.
Comme le dépôt est public, on n'y met que de la musique sous licence CC0, et on note sa provenance
dans `musique/CREDITS.md`. Les musiques de Pixabay ne conviennent pas : leur licence interdit de les
redistribuer telles quelles.

## Vérifier que tout marche

Faire courir les ordinateurs seuls sur tous les circuits, sans ouvrir de fenêtre :

```
godot --headless --path . --fixed-fps 60 -- --simulation
```

Chaque kart doit arriver. « Retours en piste » compte les fois où un kart est sorti de la route.

Pour voir tous les pilotes de face dans une image : `godot --path . -- --galerie=/chemin/image.png`.

## Mettre en ligne

```
./publier.sh
```

Le script exporte le jeu pour le navigateur et l'envoie sur GitHub Pages (branche `gh-pages`).
Il faut avoir installé une fois les modèles d'export Web de Godot (Éditeur > Gérer les modèles d'export).

## Idées pour la suite

De nouveaux bonus et de nouveaux pièges, des bruitages (moteur, pépin, cagette), un chrono du
meilleur tour, de nouveaux circuits et de nouveaux décors.

## Règles du projet

- Le jeu est original : on s'inspire d'un genre, on ne recopie pas les personnages, objets,
  circuits ou musiques d'un jeu existant.
- Le dépôt est public : pas de prénoms, de photos, de voix ni d'informations personnelles.
- On n'ajoute que des ressources dont la licence le permet (CC0 de préférence).
