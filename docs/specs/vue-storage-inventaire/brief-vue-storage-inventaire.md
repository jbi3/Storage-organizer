---
sujet: vue-storage-inventaire
projet: Storage-Organizer
statut: en-cours
created: 2026-11-09
updated: 2026-11-10
---

# Vue du coffre et de l'inventaire

## Problème

Le tri du coffre Xunlai se lance à l'aveugle : le script ne montre ni l'état avant ni l'état après. Pour savoir ce qu'il possède, en quelle quantité et comment c'est rangé, le joueur doit ouvrir le coffre en jeu et parcourir les onglets un par un puis ses 4 sacs, soit environ 5 minutes. Il rate les doublons répartis dans plusieurs onglets et ne connaît jamais ses totaux de matériaux.

## Utilisateurs

| Qui | Fait quoi | Décide / teste |
|---|---|---|
| JB (joueur, auteur du script) | Choisit un perso connecté et consulte coffre, coffre de matériaux et sacs dans la fenêtre du script | Décide et teste, en jeu ⚠️ À confirmer |
| Autres joueurs GwAu3 (dépôt public) | Hors cible pour cette version ⚠️ À confirmer | — |

## Cas d'usage

### CU1 — Voir le contenu du compte comme en jeu
- **Déclencheur** : JB veut savoir ce qu'il possède.
- **Parcours** :
  1. Il choisit le perso dans la liste.
  2. La vue affiche les 14 onglets du coffre (sacs internes 8 à 21 : sac 8 = onglet 1, …, sac 21 = onglet 14), le coffre de matériaux (sac 6, « Matériaux ») et les 4 sacs (sac à dos, bourse de ceinture, sac 1, sac 2), case par case, avec le même rendu qu'en jeu. Le nombre de cases de chaque sac est lu en jeu (`Item_GetBagInfo(..., "Slots")`).
- **Résultat** : il voit ce qu'il a et où, en quelques secondes, sans ouvrir le coffre en jeu.
- **Fréquence** : ⚠️ À confirmer.

### CU2 — Connaître le total d'un item
- **Déclencheur** : JB veut savoir combien il possède d'un item (matériaux, doublons répartis dans plusieurs onglets).
- **Parcours** :
  1. Il regarde la liste des totaux par item, à côté de la grille.
- **Résultat** : le total cumulé coffre + matériaux + sacs du perso affiché, sans compter à la main. Seuls les items empilables sont totalisés, par ModelID et ExtraID (les teintures restent séparées par couleur) ; les items non empilables restent visibles dans la grille, hors totaux.
- **Fréquence** : ⚠️ À confirmer.

### CU3 — Voir le résultat d'un tri
- **Déclencheur** : JB lance Start.
- **Parcours** :
  1. Le tri se termine.
  2. La vue se met à jour, que le tri ait réussi ou non ; en cas d'échec ou d'interruption, elle montre l'état réel avec la mention « tri interrompu ».
- **Résultat** : il voit le rangement obtenu au lieu de trier à l'aveugle.
- **Fréquence** : à chaque tri.

### CU4 — Ouvrir la vue quand le contenu est illisible
- **Déclencheur** : le perso n'est pas connecté, ou il est hors d'un avant-poste, ou le coffre n'est pas encore chargé ⚠️ À confirmer.
- **Parcours** :
  1. JB choisit le perso.
  2. La vue affiche un message clair au lieu d'une grille vide ou fausse ; si une lecture enregistrée existe, elle affiche la dernière lecture datée (CU5).
- **Résultat** : il sait quoi faire (par exemple aller en avant-poste).
- **Fréquence** : ⚠️ À confirmer.

### CU5 — Consulter hors ligne
- **Déclencheur** : le jeu est arrêté.
- **Parcours** :
  1. JB lance le script.
  2. Il choisit un perso dans la liste, qui réunit les persos connectés et ceux qui ont un fichier de lecture.
  3. La vue affiche la dernière lecture, avec sa date et son heure.
- **Résultat** : il consulte son coffre et ses sacs sans le jeu.
- **Fréquence** : ⚠️ À confirmer.

## Avant / Après

| Situation | Avant | Après | Bénéfice | Comment on le voit |
|---|---|---|---|---|
| Savoir ce que j'ai et où | Ouvrir le coffre en jeu, onglet par onglet, puis les 4 sacs : environ 5 min (estimation de JB) | Choisir le perso, la vue s'affiche | Quelques secondes au lieu d'environ 5 min | Chronométrer une consultation ⚠️ seuil à confirmer |
| Total d'un item | Inconnu, ou compté à la main | Lu dans la liste des totaux | Plus de doublons ratés | Le total affiché correspond au compte fait en jeu sur 3 items témoins |
| Après un tri | Résultat invisible depuis le script | Vue mise à jour à la fin du tri | Fin du tri à l'aveugle | Capture de la vue avant et après Start |
| Jeu arrêté | Impossible de savoir ce que j'ai | Dernière lecture affichée, datée | Consultation sans lancer le jeu | Jeu fermé, la vue montre la même grille qu'à la dernière lecture |

## Scénarios

### S1 — Première consultation (CU1)
- **Given** un perso connecté, en avant-poste, avec des items dans le coffre, le coffre de matériaux et les sacs
- **When** JB le choisit dans la liste
- **Then** chaque onglet, le coffre de matériaux et les 4 sacs s'affichent case par case, à la même position qu'en jeu, avec la quantité sur les piles

### S2 — Total d'un item réparti (CU2)
- **Given** 250 Bones dans l'onglet 1, 40 dans l'onglet 3 et 10 dans le sac 1
- **When** la vue est affichée
- **Then** la liste des totaux indique « Bones : 300 »

### S3 — Mise à jour après tri (CU3)
- **Given** la vue affichée avant tri
- **When** JB clique Start et le tri se termine sans erreur
- **Then** la vue montre le nouveau rangement, et le tri lui-même n'a pas changé de comportement

### S4 — Contenu illisible (CU4)
- **Given** un perso en zone explorable, ou dont le coffre n'est pas chargé
- **When** JB le choisit
- **Then** un message dit pourquoi la lecture en direct est impossible et quoi faire, sans grille partielle ; si une lecture enregistrée existe, elle s'affiche avec sa date

### S5 — Lecture seule (CU1)
- **Given** la vue affichée
- **When** JB clique sur une case ou la fait glisser
- **Then** aucun item ne bouge en jeu

### S6 — Hors ligne (CU5)
- **Given** une lecture enregistrée pour le perso X, puis le jeu fermé
- **When** JB lance le script et choisit X
- **Then** la grille et les totaux de la dernière lecture s'affichent, avec « Lecture du 09/11 à 23:40 »

### S7 — Première fois hors ligne (CU5)
- **Given** aucune lecture enregistrée (ou un fichier illisible) et le jeu fermé
- **When** JB lance le script
- **Then** un message indique qu'il faut une première lecture, jeu lancé

### S8 — Tri interrompu (CU3)
- **Given** la vue affichée et un tri qui échoue (validation, restack ou déplacement)
- **When** le tri s'arrête
- **Then** la vue montre l'état réel du coffre avec la mention « tri interrompu »

### S9 — Case illisible (CU1)
- **Given** une case dont le pointeur est invalide ou dont le nom n'est pas décodé
- **When** la vue est affichée
- **Then** la case apparaît grisée avec « ? », les autres cases s'affichent normalement

## Tâches

T1 à T6 forment un seul lot, livré dans l'ordre, sans échéance. T7 attend la réponse sur la source des icônes.

- [x] T1 — Lire le contenu du compte : une fonction renvoie, pour les onglets 8 à 21, le coffre de matériaux et les 4 sacs, chaque case remplie (sac, case, ModelID, nom, quantité, rareté), sans aucun déplacement ; tester en jeu la lisibilité hors avant-poste et sans coffre ouvert, et mesurer la durée de lecture d'un coffre plein · couvre CU1, CU2 · fini quand : le dump dans le log correspond case par case à 3 onglets et 1 sac vérifiés en jeu, et la durée mesurée est notée dans le brief · ✅ 2026-11-09 : dump conforme au jeu, 332 items en 9,8 s (voir « Mesures T1 »)
- [x] T2 — Afficher la grille : onglets, coffre de matériaux et sacs en cases positionnées comme en jeu, colorées par rareté, nom au survol, quantité affichée, case illisible grisée avec « ? », nombre de colonnes relevé sur une capture en jeu, en AutoIt natif · couvre CU1, CU2 · fini quand : une capture de la vue et une capture en jeu du même onglet montrent les mêmes items aux mêmes positions · ✅ 2026-11-10 : validée en jeu par JB (onglet I, Materials, Inventory), voir « Mesures T2 »
- [ ] T3 — Liste des totaux par item : cumul coffre + matériaux + sacs du perso affiché, items empilables seulement, par ModelID et ExtraID · couvre CU2 · fini quand : 3 items témoins répartis sur plusieurs onglets affichent le total compté en jeu
- [ ] T4 — États « illisible » : message au lieu de la grille quand le perso n'est pas connecté, est hors avant-poste ou que son coffre n'est pas chargé, avec les mêmes conditions que `ValidateSortingConditions` ; le critère « coffre non chargé » est fixé d'après les tests de T1 · couvre CU4 · fini quand : chacun des 3 cas, provoqué en jeu, affiche son message sans grille partielle
- [ ] T5 — Mise à jour après tri : la vue se relit à la fin de Start, en succès comme en échec (mention « tri interrompu ») · couvre CU3 · fini quand : captures avant et après un tri différentes comme attendu, S8 provoqué en jeu, et log du tri identique à celui d'avant le chantier sur un coffre identique (mêmes lignes, horodatages exclus)
- [ ] T6 — Enregistrer et relire la dernière lecture : après chaque lecture réussie, écrire un fichier INI par perso dans un dossier `Snapshots\` à côté du script, ajouté au `.gitignore` ; hors ligne, la liste des persos inclut ceux qui ont un fichier, et la vue le relit ; un fichier illisible est traité comme absent · couvre CU5, CU4 · fini quand : jeu fermé, la vue affiche la même grille et les mêmes totaux qu'à la dernière lecture en ligne, avec sa date
- [ ] T7 — Icônes comme en jeu : remplacer les cases colorées par les icônes des items, bloquée par la question ouverte sur la source des icônes · couvre CU1 · fini quand : une capture de la vue est visuellement comparable à la capture en jeu sur 1 onglet

## Hors périmètre

- Déplacer des items depuis la vue (clic, glisser-déposer) : la vue est en lecture seule.
- Modifier le comportement du tri existant (restack, catégories, placement).
- Choisir l'ordre du tri : sujet séparé.
- Toute dépendance nouvelle : AutoIt natif uniquement.
- Objets équipés sur le perso.
- Total sur tous les persos du compte.
- Vue « avant » et vue « après » côte à côte : les captures suffisent pour la recette.
- Recherche, filtre et export de la liste des totaux.

## Questions ouvertes

- ❓ JB décide et teste seul, en jeu ? (JB)
- ❓ Les autres joueurs du dépôt public sont-ils dans la cible de cette version ? (JB)
- ❓ Fréquence de consultation attendue (CU1, CU2, CU4) ? (JB)
- ❓ « Quelques secondes » : quel seuil chiffré pour l'affichage complet ? (JB)
- ❓ Source des icônes d'items et droits de les embarquer dans le dépôt (bloque T7) ? (JB, recherche)
- ✅ Mise en page : seconde fenêtre « Account view », ouverte par Read (JB, 2026-11-10).
- ✅ Conditions de lecture : le coffre se lit en zone explorable et sans avoir ouvert le coffre Xunlai depuis la connexion (T1, 2026-11-09).
- ❓ Fichier de lecture : un fichier par perso qui garde aussi le coffre lu ce jour-là (proposé), ou un fichier coffre par compte plus un fichier sacs par perso ? Le coffre Xunlai est partagé par le compte, les sacs sont propres à chaque perso. (JB)
- ❓ Sac d'équipement et objets non réclamés : inclus dans la vue ? (JB)
- ✅ Durée de lecture : 332 items en 9,8 s, stable sur 3 lectures (environ 29 ms par item, décodage des noms compris) (T1, 2026-11-09).
- ❓ 9,8 s en direct : acceptable, ou faut-il afficher la grille au fur et à mesure ? (JB, au moment de T2)

## Cadrage : réponses de l'interview

**2026-11-09**

- **Q1 Problème** : « Le tri est à l'aveugle, et je n'ai pas d'idée de ce que j'ai et dans quelle quantité et comment sont rangées les choses sans tout parcourir. »
- **Q2 Pour qui** : « Moi d'abord. »
- **Q3 Aujourd'hui** : « J'ouvre le coffre en jeu et je passe les onglets un par un, puis mes 4 sacs. Environ 5 minutes. Je rate des doublons rangés dans des onglets différents et je ne connais jamais mes totaux de matériaux. »
- **Q4 Demain** : « Je choisis mon perso et je vois le coffre et les sacs comme en jeu, avec un total par item. Je vois en quelques secondes ce que j'ai et où, sans ouvrir le jeu. L'ordre du tri est un autre sujet. Une vue complète dans l'UI avec le même style visuel qu'en jeu. » Précision : la lecture en direct exige le jeu lancé (GwAu3 lit la mémoire du client) ; « sans ouvrir le jeu » est couvert par la consultation hors ligne (CU5).
- **Q5 Hors périmètre et contraintes** : « Pas de clic ni de glisser-déposer pour déplacer les items depuis la vue : lecture seule. Ne pas casser le tri existant. AutoIt natif, sans dépendance nouvelle. Le coffre de matériaux est inclus. »
- **Ajout** : « Je veux pouvoir conserver la dernière liste hors ligne pour consulter l'inventaire et storage une fois le jeu arrêté. »

**2026-11-09, challenge (spec-challenger)** : JB retient toutes les propositions.
1. Persos hors ligne : la liste réunit les persos connectés et ceux qui ont un fichier de lecture ; sans l'un ni l'autre, message S7.
2. Sacs : sac à dos, bourse de ceinture, sac 1, sac 2 ; objets équipés hors périmètre.
3. Onglets : sac 8 = onglet 1, …, sac 21 = onglet 14 ; sac 6 = « Matériaux » ; cases lues en jeu, colonnes relevées sur capture pendant T2.
4. Totaux : items empilables seulement, par ModelID et ExtraID.
5. Totaux du perso affiché ; total multi-persos hors périmètre.
6. Tri en échec : relecture et mention « tri interrompu » ; vue avant/après côte à côte hors périmètre.
7. T4 reprend `ValidateSortingConditions` ; critère « coffre non chargé » fixé après T1.
8. Fichier : `Snapshots\` à côté du script, gitignoré, INI par perso, fichier illisible = absent.
9. « Environ 5 min » est une estimation de JB ; la durée de lecture est mesurée pendant T1.
10. Case illisible grisée avec « ? » ; T1 à T6 en un lot, dans l'ordre, sans échéance ; « log identique » = mêmes lignes, horodatages exclus.

**2026-11-09, mesures T1** (perso Heal Arcadium, bouton Read, 3 lectures : avant-poste, zone explorable, après reconnexion sans ouvrir le coffre) :
- Dump conforme au jeu sur 3 onglets et 1 sac (vérifié par JB).
- 332 items en 9 784 à 9 849 ms ; contenu identique dans les 3 situations.
- Cases : 25 par onglet, 42 pour le coffre de matériaux (positions fixes, avec des trous : cases 8, 19, 29, 32…), 20 pour le sac à dos, 10 pour la bourse de ceinture, 15 pour les sacs 1 et 2.
- `Name` donne le nom sans la quantité. Certains noms portent des balises de couleur du jeu (`<c=#00FF00>Green Rock Candy</c>`, `<c=@ItemRare>Gold Zaishen Coin</c>`) à retirer à l'affichage (T2). Les inscriptions model 19123 sortent « Unknown ».
- Rareté : 2621 blanc, 2623 bleu, 2624 or, 2627 vert (constantes `$GC_I_RARITY_*`) ; les inscriptions renvoient 33025, valeur hors constantes : couleur par défaut à prévoir (T2).

**2026-11-10, disposition en jeu et mesures T2** (captures de JB, en jeu puis de la vue) :
- Onglets du coffre : 5 colonnes × 5 lignes, remplies ligne par ligne ; libellés I à XIII, puis une icône de coffre pour le 14e et un marteau pour les matériaux.
- Coffre de matériaux : 3 colonnes × 12 lignes, 36 matériaux « quantité + icône », les absents affichés à 0 ; les cases internes 8, 29 et 39 à 42 ne sont pas affichées (déduit de l'alignement capture / dump, confirmé par la vue : les deux 0 tombent aux mêmes places qu'en jeu).
- Sacs (fenêtre F9) : une grille de 5 colonnes, chaque sac commence une nouvelle ligne (sac à dos lignes 1-4, bourse 5-6, sac 1 7-9, sac 2 10-12).
- Vue validée : mêmes items aux mêmes positions sur l'onglet I, Materials et Inventory. Premier rendu peu lisible (items blancs fondus dans le fond clair, 16 onglets tronqués) : corrigé par un fond sombre et des onglets sur deux lignes.
- Limite connue jusqu'à T7 : sans icônes, deux piles blanches de même quantité ne se distinguent qu'au survol.

**2026-11-08** (note d'origine, session Item-spammer) : vue du storage et de l'inventaire identique à la vue en jeu, pour mieux voir le tri ; choix de l'ordre du tri et du placement final dans les stockages.
