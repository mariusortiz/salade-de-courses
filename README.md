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

### Le mode Avions

Dans le menu, « Mode : Avions » transforme chaque véhicule en avion. La course se fait dans les airs,
au-dessus du même circuit : il faut traverser les anneaux dans l'ordre. Le prochain est entouré de jaune.
Un anneau orange donne un turbo, et certains portent des cagettes à bonus.

- L'avion avance tout seul. Gauche et droite pour tourner. Comme avec un vrai manche, Haut fait piquer
  et Bas fait monter (ça s'inverse avec `AVION_HAUT_MONTE` dans `donnees/reglages.gd`).
- Le bouton du dérapage sert de frein. Tirer un pépin et utiliser l'objet marchent comme en kart
  (le jus devient un nuage qui ralentit ceux qui le traversent).
- Si on passe à côté d'un anneau, on est reposé juste devant lui.

### Les obstacles et le défi du jour

Les obstacles sont entourés d'un cercle rouge : un tonneau à la campagne, un oursin dans l'aquarium,
un glaçon dans le frigo... Les toucher fait faire un tête-à-queue. Certains ne bougent pas, d'autres
traversent la route. En avion, ils flottent entre les anneaux.

Chaque jour, le menu propose un défi : un circuit, un mode et une règle spéciale tirés au sort
(le même pour tout le monde ce jour-là). On gagne une étoile en finissant, deux sur le podium,
trois en gagnant. Les étoiles sont gardées sur l'appareil, et le menu compte les jours de suite.

Chaque circuit a aussi trois défis à lui, à réussir quand on veut (onglet « Du circuit ») : battre un
chrono, finir sans toucher d'obstacle, toucher des adversaires avec ses pépins, réussir en avion...

### Les épreuves

Le menu propose cinq façons de jouer :

- **Course** : le premier arrivé gagne.
- **Élimination** : à la fin de chaque tour, le dernier est éliminé. Le dernier en piste gagne.
- **Contre-la-montre** : seul sur la piste, contre son record et le fantôme de sa meilleure course.
- **Chasse aux graines** : deux minutes pour ramasser le plus de graines. Un pépin reçu en fait perdre deux.
- **Patate chaude** : un pilote porte une patate qui va éclater. Il la refile en touchant un autre kart
  ou en le touchant avec un pépin. Celui qui l'a quand elle éclate est éliminé.

La chasse aux graines et la patate chaude se jouent en kart seulement. Les noms et les règles sont dans
`donnees/modes.gd`, les durées dans `donnees/reglages.gd`.

### Le mode Skate

Dans le menu, le mode **Skate** emmène un ou deux joueurs dans le skatepark des fruits. On n'y fait
pas la course : on a deux minutes pour marquer le plus de points en faisant des figures.

- **Toupie** : en l'air, gauche ou droite pour tourner sur soi-même.
- **Salto** : en l'air, haut ou bas.
- **Tonneau** et **Attrapé** : en l'air, avec leurs boutons.
- **Glissade** : retomber sur une barre.
- **Grand saut** : monter très haut, par exemple sur les rampes du tour.

Tout ce qu'on enchaîne sans retoucher le sol forme un combo : les points sont multipliés par le
nombre de figures. Il faut finir ses figures avant de retomber, sinon c'est la chute et le combo est
perdu. Le skatepark (rampes, tremplins, bosses, barres), les figures et leurs points s'écrivent dans
`donnees/skate.gd`.

### Les raccourcis

Sur sept circuits, la route fait un détour et un passage étroit coupe tout droit : un panneau
« RACCOURCI » le signale, et il est en pointillé sur le plan du menu. Il fait gagner du temps, mais un
obstacle va et vient au milieu. Les raccourcis s'écrivent dans `donnees/circuits.gd`.

Il y a aussi des **passages secrets**, sur tous les circuits sauf La Comète. Aucun panneau ne les
montre et ils ne sont pas sur le plan : ils sont cachés derrière une fausse barrière, un tout petit
peu plus foncée que les autres, qu'on traverse. Dedans, une cagette à bonus attend celui qui l'a
trouvé. Ils s'écrivent au même endroit, à la ligne `secrets`.

### Le magasin

On gagne des graines en finissant une course (50 pour le premier, 30 pour le deuxième, 20 pour le
troisième, 10 pour les autres), en réussissant un défi de circuit (100) et en gagnant des étoiles au
défi du jour (30 par étoile). Le bouton « Magasin » du menu ouvre deux rayons, les voitures et les
avions (kart, buggy, bolide, tracteur, cagette, et quatre deux-roues : moto, scooter, moto tout-terrain, moto de course). Au début, on a le kart, la moto et leurs avions ; les autres s'achètent. Les prix sont dans
`donnees/vehicules.gd`, les gains dans `donnees/reglages.gd`.

Si le kart sort de la piste, il y est reposé au bout de deux secondes.

## Modifier le jeu

Six fichiers sont faits pour être changés. Chacun commence par son mode d'emploi.

| Fichier | Ce qu'on y change |
| --- | --- |
| `donnees/skate.gd` | Le mode Skate : la durée, les figures et leurs points, et tout ce qu'on pose dans le skatepark |
| `donnees/circuits.gd` | Les circuits : la liste des points par où passe la route (avec leur hauteur), les turbos, les tremplins, les cagettes à bonus, les obstacles, les raccourcis, les passages secrets, la musique |
| `donnees/pilotes.gd` | Les fruits : nom, forme, motif de la peau, couleurs, vitesse, accélération, maniabilité, modèle 3D |
| `donnees/vehicules.gd` | Les véhicules : nom, forme, et ce qu'ils ajoutent ou enlèvent en vitesse, accélération, maniabilité |
| `donnees/modes.gd` | Les épreuves : leur nom et leur règle |
| `donnees/defis.gd` | Les règles spéciales des défis du jour, et les défis des circuits |
| `donnees/reglages.gd` | Le titre, la gravité, l'adhérence, le turbo, le saut, les bonus, le volume de la musique, le niveau des ordinateurs, le nombre de karts, les nombres de tours proposés, le décor, les couleurs |

Le reste du code est dans `jeu/` :

- `piste.gd` construit la route, les barrières, les cagettes et le décor à partir des points du circuit, et dessine les textures ;
- `kart.gd` gère la conduite (une boule qui roule sur la piste, avec le fruit posé dessus) ;
- `decor.gd` contient les décors (campagne, espace, montagne, grotte, pizza, aquarium, frigo, potager) : leurs couleurs, leur lumière, et les objets posés autour de la route ;
- `avion.gd` gère le vol dans le mode Avions (c'est un kart qui vole : il garde les bonus du kart) ;
- `fruit.gd` dessine le fruit (avec ses bras et ses jambes) et son véhicule ;
- `course.gd` gère le départ, les touches, les bonus, les écrans des joueurs et le classement ;
- `magasin.gd` tient le porte-monnaie et le garage ;
- `defi.gd` tire au sort le défi du jour et garde les étoiles ;
- `main.gd` gère le menu (avec l'aperçu du pilote et le plan du circuit), le classement et la musique.

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

Les musiques sont dans le dossier `musique/` (format `.mp3` ou `.ogg`). Chaque circuit a la sienne. Celle du menu et celle de
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
Ajouter `--avions` juste après `--` pour faire la même chose dans le mode Avions.

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
