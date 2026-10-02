# AeonDungeonJournal

Journal des donjons pour WoW Forever (1.60.1), sur le modèle du Guide de l'aventurier de retail. Il couvre les 25 donjons Classic à 5 joueurs (ailes de Scarlet, de Dire Maul et de Blackrock Spire comprises), et Ruins of Lordaeron et Hall of Thanes, propres à Forever.

- Accueil en grille de donjons illustrés, avec leur tranche de niveaux Forever. Bordure dorée sur les donjons dont la tranche contient le niveau du personnage.
- Page du donjon : boss avec portrait et niveau, puis quatre onglets : carte, butin, capacités des boss, quêtes.
- Carte de chaque étage, avec un repère numéroté par boss. Clic sur un repère ou sur un nom : butin du boss.
- Butin : icône, nom et qualité fournis par le client, chance de butin, objets nouveaux ou modifiés dans Forever, infobulle, Maj+clic pour le lien dans le chat.
- Filtres du butin : recherche par nom, menus des emplacements et des types présents dans le donjon. Les menus reviennent à « tous » quand on change de donjon ; le texte cherché reste.
- Liste de souhaits : clic droit sur un objet du butin. Une étoile marque l'objet, son boss et son donjon. Quand l'objet tombe (butin ouvert ou jet de groupe), une alerte s'affiche à l'écran et dans le chat, une fois par minute au plus.
- Infobulles d'objet du jeu : donjon, boss et chance de butin de l'objet (3 sources au plus).
- Capacités : rôle visé (tank, soigneur, magie…) et conseil, dans la langue du client (anglais, français, allemand, espagnol, italien, portugais, russe, coréen, chinois simplifié et traditionnel). Le nom d'un sort est celui du client.
- Quêtes du donjon : niveau, faction, donneur et récompenses. Une quête déjà rendue par le personnage est cochée et en vert vif ; une quête du journal de quêtes porte la mention « En cours ». Les quêtes de la faction adverse sont cachées.
- Boss tués pendant le run : coche dans la liste des boss et sur la carte (portrait grisé). Signaux : mort de l'unité, fin de rencontre, butin ouvert sur le boss. Forever n'annonce pas la réinitialisation d'une instance : les coches s'effacent quand un boss d'une autre instance est tué (les ailes d'un même donjon partagent leur instance), quand un boss déjà coché est retué, ou après deux heures sans kill.
- Partage au groupe : dans l'onglet des capacités d'un boss, « Envoyer au groupe » écrit la note et les capacités dans le chat de groupe, en messages de 250 octets au plus.
- Relevé en jeu : un objet vert ou mieux ramassé sur un boss du journal, et absent des données, est ajouté à sa liste avec un `*`.
- Repères déplaçables : Maj + glisser. La nouvelle position est gardée.

## Commandes

- `/codex` ou `/aeondungeonjournal` : ouvrir ou fermer la fenêtre (elle s'ouvre sur le donjon en cours).
- `/codex resetpins` : remettre les repères à leur place d'origine.
- `/codex wipe` : oublier le butin relevé en jeu.
- `/codex tooltip` : masquer ou réafficher la source du butin dans les infobulles d'objet.
- `/codex help` : rappel des commandes.

## D'où viennent les données

Le client Forever n'a aucune carte d'étage de donjon : sa table `UiMap` compte 60 lignes, toutes des zones extérieures, et `C_Map.GetMapInfo(291)` renvoie `nil`. En revanche, les fichiers des tuiles de carte retail sont dans le client (624 tuiles vérifiées sur le build 1.60.1.70009). `Data.lua` les pose donc par fileID, en grille de 4 × 3 tuiles de 256 px, sur une zone utile de 1002 × 668.

| Donnée | Source |
|---|---|
| Tuiles des étages | DB2 retail `UiMapXMapArt` + `UiMapArtTile` (wago.tools). Scholomance : cartes « Legacy of Scholomance » 306-309, qui ont l'ancien plan. Scarlet : anciennes ailes 302-305. |
| Boss et butin | AtlasLootClassic, `AtlasLootClassic_DungeonsAndRaids/data.lua` (données Classic, GPL-2.0) |
| Positions des boss | DB2 `JournalEncounter` retail, puis celui de MoP Classic 5.5.4. Les 103 boss absents de ces journaux sont placés à vue dans `tools/manual_positions.py`. |
| Noms des boss traduits | QuestieDB, `l10n/Forever/lookupNpcs/<locale>.lua` (pas d'italien : repli sur l'anglais) |
| Noms des donjons | Client (`GetRealZoneText(instanceID)`) |
| Niveaux Forever, boss en plus, chances de butin, objets nouveaux ou modifiés, portraits (displayID), repères, capacités, quêtes | [foreverchanges.pro](https://foreverchanges.pro/fr/dungeons) : `tools/foreverchanges.json`, extrait des pages par `tools/foreverchanges_extract.py` |
| Conseils de combat par langue | Français : foreverchanges.pro. Autres langues : `tools/texts/<langue>.json`, traduits du français (mêmes pages, mêmes combats, même nombre de capacités). Le générateur en tire `Tactics/<langue>.lua` ; `Tactics/enUS.lua` sert de base aux clients sans fichier. |
| Images des donjons | DB2 retail `JournalInstance` (`ButtonFileDataID`, `LoreFileDataID`) |
| Donjons propres à Forever | `tools/forever_dungeons.txt`, saisi à la main : npcID et objets du guide Wowhead Forever (Ruins of Lordaeron), répartition du butin par boss de foreverchanges.pro. |
| Cartes de Ruins of Lordaeron et de Hall of Thanes | Aucune carte d'étage dans le client ni sur retail : tuiles de minicarte du client, posées par fileID et agrandies sur le donjon. Les fileID viennent du WDT de la carte (chunk `MAID`, champ `minimapTexture`), lu sur wago.tools (`/api/casc/<fileID du WDT>?version=1.60.1.70124`). Étages déclarés dans `MINIMAP_FLOORS` (`tools/manual_positions.py`). Repères : ceux de foreverchanges.pro, posés là-bas sur une carte dessinée, ramenés sur la minicarte par une transformation affine réglée à vue. |

## Régénérer `Data.lua` et `Tactics/`

Dans un dossier de travail `W` :

```sh
B=12.1.0.69933   # build retail
for t in UiMapXMapArt UiMapArtTile JournalEncounter; do curl -sSL "https://wago.tools/db2/$t/csv?build=$B" -o "$W/rt-$t.csv"; done
curl -sSL "https://wago.tools/db2/JournalEncounter/csv?build=5.5.4.69934" -o "$W/mc-JournalEncounter.csv"
curl -sSL -o "$W/atlasloot-data.lua" https://raw.githubusercontent.com/Hoizame/AtlasLootClassic/master/AtlasLootClassic_DungeonsAndRaids/data.lua
for l in deDE esES esMX frFR koKR ptBR ruRU zhCN zhTW; do curl -sSL -o "$W/npc-$l.lua" "https://raw.githubusercontent.com/Questie/QuestieDB/HEAD/l10n/Forever/lookupNpcs/$l.lua"; done
curl -sSL -o "$W/foreverNpcDB.lua" https://raw.githubusercontent.com/Questie/QuestieDB/HEAD/data/Forever/foreverNpcDB.lua
lua tools/atlasloot_export.lua "$W/atlasloot-data.lua" > "$W/bosses.txt"
python tools/generate_data.py "$W" > Data.lua
```

Pour rafraîchir les données du site : télécharger `https://foreverchanges.pro/fr/dungeons` et chaque `https://foreverchanges.pro/fr/dungeons/<page>` dans un dossier avec `slugs.txt` (une page par ligne), y lancer `python tools/foreverchanges_extract.py`, puis copier `foreverchanges.json` dans `tools/`. L'extracteur écrit aussi `texts.json` (textes seuls) : pour reprendre les textes du site dans une autre langue (`/dungeons/<page>` en anglais, `/de/`, `/zh-cn/`, `/zh-tw/`), lancer l'extracteur sur ces pages et copier `texts.json` vers `tools/texts/<langue>.json`.

Le générateur écrit `Tactics/<langue>.lua` à côté de `Data.lua`, et signale sur la sortie d'erreur une langue sans fichier ou un combat dont le nombre de capacités diffère du français.

Le générateur liste sur la sortie d'erreur les boss restés sans position. Pour placer ou corriger un repère, modifier `tools/manual_positions.py` (npcID vers UiMapID, x, y entre 0 et 1), puis régénérer.

## Vérification

- Hors jeu : `lua tests/smoke.lua`. Le test charge l'addon sur un mock, ouvre le journal, passe sur les 27 donjons, les 239 boss et les quatre onglets, relève un butin, et vérifie les textes de combat de chaque langue, les filtres du butin, la liste de souhaits et l'infobulle d'objet.
- En jeu : copier le dossier sans `tests/` ni `tools/` dans `Interface/AddOns/AeonDungeonJournal/`, puis `/reload` et `/codex`.

## Licence

GPL-2.0 (texte complet dans `LICENSE`), car les listes de butin reprennent des données d'AtlasLootClassic, publiées sous GPL-2.0.