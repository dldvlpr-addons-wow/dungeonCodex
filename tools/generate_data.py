"""Génère Data.lua à partir des sources publiques téléchargées dans un dossier de travail.

Sources attendues dans <dossier> :
  bosses.txt                sortie de atlasloot_export.lua (boss et loot, AtlasLootClassic)
  upcoming_facts.json       faits des donjons à venir recoupés sur 4 addons concurrents (tools/, suivi)
  classic_facts.json        modèles, niveaux et quêtes Classic absents, mêmes sources (tools/, suivi)
  (dans tools/, pas dans <dossier>) wowhead_facts.json : noms traduits et niveaux encore absents, infobulles Wowhead
                            Forever (tools/wowhead_fetch.py)
  atlasloot-droprate.lua    AtlasLootClassic_DungeonsAndRaids/droprate.lua d'AtlasLoot Forever (chances absentes du site)
  rt-UiMapXMapArt.csv       DB2 retail (wago.tools/db2/UiMapXMapArt/csv?build=<retail>)
  rt-UiMapArtTile.csv       DB2 retail (tuiles ; fichiers présents dans le client Forever)
  rt-JournalEncounter.csv   DB2 retail (coordonnées des boss sur les cartes)
  mc-JournalEncounter.csv   DB2 MoP Classic 5.5.4 (ancien Blackrock Spire, anciens boss), en second
  npc-<locale>.lua          QuestieDB l10n/Forever/lookupNpcs/<locale>.lua
  foreverNpcDB.lua          QuestieDB data/Forever/foreverNpcDB.lua (npcID des boss ajoutés par le site)
  foreverQuestDB.lua        QuestieDB data/Forever/foreverQuestDB.lua (titre enUS et prérequis directs des quêtes)
  foreverBaseQuest.lua      QuestieDB src/corrections/Forever/generated/ (titres des quêtes Forever récentes), facultatif
  foreverQuestFixes.lua     QuestieDB src/corrections/Forever/ (prérequis corrigés), facultatif

Statut (`status`) : verified = données d'AtlasLoot (Classic) ; beta = donjon Forever dont les boss viennent du site ;
unconfirmed = donjon à venir (instanceID 0, `upcoming = true`, sans carte ; boss et butin d'AtlasLoot Forever).
Donjons propres à Forever, absents d'AtlasLoot : tools/forever_dungeons.txt, même format que bosses.txt.
Niveaux, boss en plus, butin (chances, nouveautés), portraits, positions, capacités et quêtes de
Forever : tools/foreverchanges.json (foreverchanges.pro, extrait par foreverchanges_extract.py).
Textes des combats et noms de boss des autres langues : tools/texts/<langue>.json (même extracteur
pour les langues du site, traduction du français pour les autres). Combats absents du site : tools/manual_fights.json.

Usage : python generate_data.py <dossier> > ../Data.lua   (écrit aussi ../Tactics/<langue>.lua)
"""
import csv
import json
import os
import re
import sys

from manual_positions import FLOORS, ALIASES, POSITIONS, WINGS, HIDDEN, SITE_SLUGS, SITE_DUNGEONS, MINIMAP_FLOORS, ENTRANCES, SECOND_ENTRANCES, FLOOR_LINKS, DUNGEON_NAMES, MANUAL_NPCS, MANUAL_BOSS_NAMES, MANUAL_NPC_NAMES, ANNEX_NAMES

HERE = os.path.dirname(os.path.abspath(__file__))

LOCALES = ["deDE", "esES", "esMX", "frFR", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"]
# Langues des textes de combat (Tactics/<langue>.lua) et clients qui partagent un même fichier.
TEXT_LOCALES = ["enUS", "frFR", "deDE", "esES", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"]
SAME_TEXTS = {"esES": ["esMX"]}
# Zone du donneur de quête (texte du site, français ou anglais) vers l'UiMapID Classic de Forever : le client en donne
# le nom dans sa langue. Zone qui est une instance (Hache-tripes) : nom par GetRealZoneText(instance).
ZONE_INSTANCES = {"Hache-tripes": 429}
# Zone Questie (AreaTable) -> UiMapID. Déduit en recoupant les apparitions de foreverNpcDB avec les donneurs placés par
# DungeonMaster (37 zones, aucun désaccord), plus les zones de départ connues sans donneur chez lui.
AREA_MAPS = {1: 1426, 3: 1418, 4: 1419, 8: 1435, 10: 1431, 11: 1437, 12: 1429, 14: 1411, 15: 1445, 16: 1447, 17: 1413,
             28: 1422, 33: 1434, 36: 1416, 38: 1432, 40: 1436, 41: 1430, 44: 1433, 45: 1417, 46: 1428, 47: 1425, 51: 1427,
             85: 1420, 130: 1421, 139: 1423, 141: 1438, 148: 1439, 215: 1412, 267: 1424, 331: 1440, 357: 1444, 361: 1448,
             400: 1441, 405: 1443, 406: 1442, 440: 1446, 490: 1449, 493: 1450, 618: 1452, 1377: 1451, 1497: 1458,
             1519: 1453, 1537: 1455, 1637: 1454, 1638: 1456, 1657: 1457}
ZONE_MAPS = {
    "Mulgore": 1412, "Les Tarides": 1413, "Montagnes d'Alterac": 1416, "Hautes-terres Arathies": 1417,
    "Terres ingrates (Badlands)": 1418, "Terres foudroyées": 1419, "Clairières de Tirisfal": 1420,
    "Forêt des Pins argentés (Silverpine Forest)": 1421, "Maleterres de l’ouest": 1422, "Maleterres de l'est": 1423,
    "Contreforts de Hautebrande": 1424, "Les Hinterlands": 1425, "Dun Morogh": 1426, "Steppes Ardentes": 1428,
    "Bois de la Pénombre": 1431, "Loch Modan": 1432, "Les Carmines": 1433, "Vallée de Strangleronce": 1434,
    "Marais des Chagrins": 1435, "Marche de l’Ouest": 1436, "Les Paluns": 1437, "Sombrivage (Darkshore)": 1439,
    "Orneval": 1440, "Mille pointes": 1441, "Desolace": 1443, "Feralas": 1444, "Marécage d'Âprefange": 1445,
    "Tanaris": 1446, "Berceau-de-l’Hiver": 1452, "Hurlevent": 1453, "Orgrimmar": 1454, "Forgefer": 1455,
    "Thunder Bluff": 1456, "Darnassus": 1457, "Fossoyeuse": 1458,
    # Zones en anglais des quêtes de upcoming_facts.json.
    "Stranglethorn Vale": 1434, "Hillsbrad Foothills": 1424, "Alterac Mountains": 1416, "Dustwallow Marsh": 1445,
    "Stormwind City": 1453, "Azshara": 1447, "Tirisfal Glades": 1420, "Ironforge": 1455, "Undercity": 1458,
    "Blasted Lands": 1419, "Burning Steppes": 1428, "Dun Morogh": 1426, "Durotar": 1411, "Felwood": 1448, "Feralas": 1444,
    "Moonglade": 1450, "Orgrimmar": 1454, "Searing Gorge": 1427, "Stonetalon Mountains": 1442, "Swamp of Sorrows": 1435,
    "Thousand Needles": 1441, "Un'Goro Crater": 1449, "Wetlands": 1437, "Winterspring": 1452,
}


def read_csv(folder, name):
    with open(os.path.join(folder, name), encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def normalize(name):
    return re.sub(r"[^a-z]", "", name.lower())


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "") + '"'


def slugify(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


# Clés des donjons Forever d'AtlasLoot Forever (ContentType « Forever Dungeons ») vers les nôtres.
ATLASLOOT_KEYS = {
    "TheHallOfThanes": "HallOfThanes", "TheRuinsOfLordaeron": "RuinsOfLordaeron",
    "ExcavationSiteWetlands": "ExcavationSite", "TheCityOfDalaran": "CityOfDalaran",
    "TheKrolDokStronghold": "KroldokStronghold", "TheAlcazPrison": "AlcazPrison", "TheBlackmawHold": "BlackmawHold",
}


def load_bosses(folder):
    """forever_dungeons.txt d'abord : ses npcID, son ordre et son instanceID priment ; AtlasLoot y ajoute son butin.
    Donjons Forever d'AtlasLoot : source « forever » imposée par forever_dungeons.txt ou SITE_DUNGEONS (merge_site)."""
    dungeons = {}
    forever = os.path.join(HERE, "forever_dungeons.txt")
    with open(os.path.join(folder, "bosses.txt"), encoding="utf-8") as handle, open(forever, encoding="utf-8") as extra:
        lines = [("forever", line) for line in extra] + [("atlasloot", line) for line in handle]
    for source, line in lines:
        key, instance, levels, order, npcs, name, items = line.rstrip("\n").split("|")
        key = ATLASLOOT_KEYS.get(key, key)
        dungeon = dungeons.setdefault(key, {"instance": instance, "levels": levels, "bosses": [],
                                            "source": source})
        npc_ids = [int(n) for n in npcs.split(",") if n]
        name = name.replace('\\"', '"')
        # Listes annexes : « Trash Mobs » (Deadmines) = « Trash » ; boss invoqués sans le suffixe de leur set.
        name = re.sub(r" - Tier 0\.5 Sets$", "", "Trash" if name == "Trash Mobs" else name)
        item_ids = [int(i) for i in items.split(",") if i]
        known = next((b for b in dungeon["bosses"] if normalize(b["name"]) == normalize(name)), None)
        if known is not None:
            known["items"] += [i for i in item_ids if i not in known["items"]]
            continue
        dungeon["bosses"].append({
            "order": int(order),
            "npc": npc_ids[0] if npc_ids else None,
            "other_npcs": npc_ids[1:],
            "name": name,
            "items": item_ids,
            "names": ANNEX_NAMES.get(name, {}),
        })
    return dungeons


def load_droprates(folder):
    """Chances d'AtlasLoot Forever (droprate.lua, GPL-2) : {npcID: {itemID: pourcentage}}."""
    rates, npc = {}, None
    with open(os.path.join(folder, "atlasloot-droprate.lua"), encoding="utf-8") as handle:
        for line in handle:
            if match := re.match(r"\s*\[(\d+)\] = \{", line):
                npc = int(match.group(1))
            elif match := re.match(r"\s*\[(\d+)\] = ([\d.]+)", line):
                rates.setdefault(npc, {})[int(match.group(1))] = float(match.group(2))
            elif match := re.match(r"\s*DropRateData\[(\d+)\]\[(\d+)\] = ([\d.]+)", line):
                rates.setdefault(int(match.group(1)), {})[int(match.group(2))] = float(match.group(3))
    return rates


def load_tiles(folder):
    art_of_map = {r["UiMapID"]: r["UiMapArtID"] for r in read_csv(folder, "rt-UiMapXMapArt.csv")}
    tiles = {}
    for row in read_csv(folder, "rt-UiMapArtTile.csv"):
        tiles.setdefault(row["UiMapArtID"], []).append(row)
    floors = {}
    for dungeon_floors in FLOORS.values():
        for ui_map in dungeon_floors:
            if ui_map in MINIMAP_FLOORS:
                continue
            rows = sorted(tiles[art_of_map[str(ui_map)]], key=lambda r: (int(r["RowIndex"]), int(r["ColIndex"])))
            assert len(rows) == 12 and all(r["LayerIndex"] == "0" for r in rows), ui_map
            floors[ui_map] = [int(r["FileDataID"]) for r in rows]
    return floors


def load_journal(folder):
    journal = {}
    rows = read_csv(folder, "rt-JournalEncounter.csv") + read_csv(folder, "mc-JournalEncounter.csv")
    for row in rows:
        if row["Map_0"] not in ("0", ""):
            journal.setdefault(normalize(row["Name_lang"]), []).append(
                (int(row["UiMapID"]), float(row["Map_0"]), float(row["Map_1"])))
    return journal


def load_names(folder, npc_ids):
    names = {}
    pattern = re.compile(r'^\[(\d+)\] = \{"((?:[^"\\]|\\.)*)"')
    for locale in LOCALES:
        path = os.path.join(folder, "npc-%s.lua" % locale)
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                match = pattern.match(line)
                if match and int(match.group(1)) in npc_ids:
                    names.setdefault(locale, {})[int(match.group(1))] = match.group(2).replace('\\"', '"')
    return names


def load_npc_names(folder):
    """npcID -> nom anglais (foreverNpcDB.lua)."""
    pattern = re.compile(r"^\[(\d+)\] = \{'((?:[^'\\]|\\.)*)'")
    with open(os.path.join(folder, "foreverNpcDB.lua"), encoding="utf-8") as handle:
        return {int(m.group(1)): m.group(2).replace("\\'", "'") for m in map(pattern.match, handle) if m}


# Quêtes dont DungeonMaster place le donneur ailleurs (autre carte ou plus de 2 points d'écart) : sans position.
with open(os.path.join(HERE, "classic_facts.json"), encoding="utf-8") as _handle:
    GIVER_CONFLICTS = set(json.load(_handle)["giverConflicts"])


def load_npc_spawns(folder):
    """npcID -> (UiMapID, x, y) en 0-1 : apparition unique, ou groupée à moins de 2 points, sur une carte connue."""
    spawns = {}
    # Champ 7 (spawns) : {[zone]={{x,y},...},...} ; parse_lua_value ne garde pas les clés, d'où l'expression régulière.
    pattern = re.compile(r"^\[(\d+)\] = \{'(?:[^'\\]|\\.)*',[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,(\{\[.*?\}\}\})")
    with open(os.path.join(folder, "foreverNpcDB.lua"), encoding="utf-8") as handle:
        for line in handle:
            match = pattern.match(line)
            if not match:
                continue
            points = [(AREA_MAPS[int(area)], float(x), float(y))
                      for area, coords in re.findall(r"\[(\d+)\]=\{(.*?\})\}", match.group(2)) if int(area) in AREA_MAPS
                      for x, y in re.findall(r"\{([\d.]+),([\d.]+)\}", coords)]
            # Plusieurs cartes ou PNJ qui patrouille : pas de point unique, le donneur reste sans position.
            if points and all(p[0] == points[0][0] and abs(p[1] - points[0][1]) < 2 and abs(p[2] - points[0][2]) < 2
                              for p in points):
                spawns[int(match.group(1))] = (points[0][0], points[0][1] / 100, points[0][2] / 100)
    return spawns


def load_npc_ids(folder):
    """Nom anglais normalisé -> npcID ; entre homonymes, le rang puis le niveau le plus haut."""
    candidates = {}
    pattern = re.compile(r"^\[(\d+)\] = \{'((?:[^'\\]|\\.)*)',\d+,\d+,\d+,(\d+),(\d+),")
    with open(os.path.join(folder, "foreverNpcDB.lua"), encoding="utf-8") as handle:
        for line in handle:
            match = pattern.match(line)
            if match:
                name = normalize(match.group(2).replace("\\'", "'"))
                candidates.setdefault(name, []).append((int(match.group(4)), int(match.group(3)), int(match.group(1))))
    ids = {name: max(found)[2] for name, found in candidates.items()}
    for name, npc in MANUAL_NPCS.items():
        ids.setdefault(normalize(name), npc)
    return ids


def load_texts(site):
    """Textes des combats et noms des boss, par langue puis par page : frFR du site, le reste de tools/texts/."""
    texts = {"frFR": {slug: {"fights": page["fights"], "bosses": {b["english"]: b["name"] for b in page["bosses"]}}
                      for slug, page in site.items()}}
    for locale in TEXT_LOCALES:
        path = os.path.join(HERE, "texts", locale + ".json")
        if locale != "frFR" and os.path.exists(path):
            with open(path, encoding="utf-8") as handle:
                texts[locale] = json.load(handle)
    return texts


def add_manual_fights(site, texts):
    """Combats absents du site, écrits à la main dans tools/manual_fights.json (sorts relevés sur wowhead classic,
    textes dans les 10 langues). Un combat du site garde la priorité."""
    with open(os.path.join(HERE, "manual_fights.json"), encoding="utf-8") as handle:
        manual = json.load(handle)
    for slug, fights in manual.items():
        for key, fight in fights.items():
            if key in site[slug]["fights"]:
                continue
            site[slug]["fights"][key] = {"trigger": None, "abilities": [
                {"spell": a.get("spell"), "icon": a["icon"], "flags": a["flags"], "name": a["name"]["frFR"],
                 "text": a["text"]["frFR"]} for a in fight["abilities"]]}
            for locale in texts:
                if locale != "frFR":
                    texts[locale].setdefault(slug, {}).setdefault("fights", {})[key] = {"trigger": None, "abilities": [
                        {"name": a["name"][locale], "text": a["text"][locale]} for a in fight["abilities"]]}


def merge_site(dungeons, npc_ids):
    """Complète chaque donjon avec foreverchanges.json ; boss rapprochés par nom anglais. Rend l'état des objets et les textes."""
    with open(os.path.join(HERE, "foreverchanges.json"), encoding="utf-8") as handle:
        site = {page["slug"]: page for page in json.load(handle)}
    texts = load_texts(site)
    add_manual_fights(site, texts)
    for key, (slug, instance) in SITE_DUNGEONS.items():
        bosses = dungeons.get(key, {}).get("bosses", [])
        for boss in bosses:
            if boss["npc"] is None:
                boss["npc"] = npc_ids.get(normalize(boss["name"]))
        dungeons[key] = {"instance": str(instance), "levels": "", "bosses": bosses, "source": "forever"}
    status = {}
    for key, dungeon in dungeons.items():
        pages = [site[slug] for slug in SITE_SLUGS[key]]
        low, high = pages[0]["levels"].replace("–", "-").split("-")
        dungeon["levels"] = "%s,%s,%s" % (low, low, high)
        same_floors = len(pages) == 1 and len(pages[0]["floors"]) == len(FLOORS.get(key, []))
        fights, fight_page, pins, quests, seen = {}, {}, {}, [], set()
        for page in pages:
            fights.update(page["fights"])
            fight_page.update({fight: page["slug"] for fight in page["fights"]})
            for index, floor in enumerate(page["floors"]):
                for pin in floor["pins"]:
                    view = MINIMAP_FLOORS.get(FLOORS[key][index], {}) if same_floors else None
                    if view is not None and ("pins" in view or FLOORS[key][index] not in MINIMAP_FLOORS):
                        ax, bx, ay, by = view.get("pins", (1, 0, 1, 0))
                        pins.setdefault(pin["boss"], (FLOORS[key][index], ax * pin["x"] / 100 + bx, ay * pin["y"] / 100 + by))
            for quest in page["quests"]:
                if quest["id"] not in seen:
                    seen.add(quest["id"])
                    quests.append(quest)
        dungeon["quests"] = quests
        by_name = {normalize(boss["name"]): boss for boss in dungeon["bosses"]}
        for page in pages:
            for found in page["bosses"]:
                name = re.sub(r"^Ring of Law: ", "", found["english"])
                boss = by_name.get(normalize(name))
                slug = slugify(found["english"])
                if found["kind"] == "quest" and boss is not None and slug in fights:
                    # Boss de quête déjà connu de la base : seulement ses capacités.
                    boss.update({"fight": fights[slug], "fight_ref": (fight_page[slug], slug)})
                if found["kind"] not in ("boss", "rare"):
                    continue
                if boss is None:
                    boss = {"order": 999, "npc": npc_ids.get(normalize(name)), "other_npcs": [], "name": name, "items": []}
                    dungeon["bosses"].append(boss)
                    by_name[normalize(name)] = boss
                listed = [item["id"] for item in found["items"]]
                names = {locale: pages_of[page["slug"]]["bosses"].get(found["english"])
                         for locale, pages_of in texts.items() if page["slug"] in pages_of and "bosses" in pages_of[page["slug"]]}
                for locale, text in MANUAL_BOSS_NAMES.get(boss["npc"], {}).items():
                    if not names.get(locale) or names[locale].replace("’", "'") == boss["name"]:
                        names[locale] = text
                boss.update({
                    "display": found["display"] or None,
                    "level": max(found["level"]) if isinstance(found["level"], list) else found["level"],
                    "rare": found["kind"] == "rare",
                    "names": {locale: text for locale, text in names.items() if text and text.replace("’", "'") != boss["name"]},
                    "pin": pins.get(slug),
                    "items": listed + [i for i in boss["items"] if i not in listed],
                    "drops": {item["id"]: item["chance"] for item in found["items"] if item["chance"]},
                    "fight": fights.get(slug),
                    "fight_ref": (fight_page[slug], slug) if slug in fights else None,
                })
                for item in found["items"]:
                    if item["status"] in ("new", "changed"):
                        status[item["id"]] = item["status"]
        # Boss absents des pages du site (boss invoqués, annexes) : combat de manual_fights.json, rapproché par nom.
        for boss in dungeon["bosses"]:
            slug = slugify(boss["name"])
            if not boss.get("fight") and slug in fights:
                boss.update({"fight": fights[slug], "fight_ref": (fight_page[slug], slug)})
    return status, texts


def merge_competitor_facts(dungeons):
    """Faits recoupés sur les addons DungeonMaster, ForeverDungeonScout, ForeverDungeonJournal et GearFinderClassic,
    valeurs en désaccord à null. upcoming_facts.json : donjons à venir (npcID, modèle, niveau, rareté, chances, quêtes).
    classic_facts.json : modèle et niveau des boss Classic qui n'en ont pas, quêtes absentes, boss, PNJ de combat et
    objets absents d'AtlasLoot."""
    with open(os.path.join(HERE, "classic_facts.json"), encoding="utf-8") as handle:
        classic = json.load(handle)
    for key, extra in classic["extraBosses"].items():
        known = {normalize(boss["name"]) for boss in dungeons[key]["bosses"]}
        dungeons[key]["bosses"] += [{"order": 999, "npc": boss["npc"], "other_npcs": [], "name": boss["name"],
                                     "items": boss["items"], "display": boss["display"],
                                     "drops": {int(item): chance for item, chance in boss["drops"].items()}}
                                    for boss in extra if normalize(boss["name"]) not in known]
    for dungeon in dungeons.values():
        for boss in dungeon["bosses"]:
            # Kill compté sur un PNJ du même combat (Ruuzlu avec Ukorz) ; objet absent d'AtlasLoot (Pimgib's Collar).
            boss["other_npcs"] += [n for n in classic["extraNpcs"].get(str(boss["npc"]), []) if n not in boss["other_npcs"]]
            boss["items"] += [i for i in classic["extraItems"].get(str(boss["npc"]), []) if i not in boss["items"]]
            for field, value in classic["bossFacts"].get(str(boss["npc"]), {}).items():
                if field in ("display", "level") and value and not boss.get(field):
                    boss[field] = value
    with open(os.path.join(HERE, "upcoming_facts.json"), encoding="utf-8") as handle:
        facts = json.load(handle)
    for key, quests in classic["quests"].items():
        # Zone déduite des coordonnées par l'extraction, fausse quand deux cartes se recouvrent : donneur de Questie
        # (startedBy) à la place, via lua_quest.
        facts["quests"].setdefault(key, []).extend(dict(quest, giverName=None) for quest in quests)
    for key, found_bosses in facts["bosses"].items():
        dungeon = dungeons[key]
        by_name = {normalize(boss["name"]): boss for boss in dungeon["bosses"]}
        for found in found_bosses:
            boss = by_name.get(normalize(found["name"]))
            if boss is None:
                boss = {"order": 999, "name": found["name"], "items": []}
                dungeon["bosses"].append(boss)
            boss.update({"npc": found["npc"] or boss.get("npc"), "other_npcs": found["otherNpcs"], "rare": found["rare"]})
            boss.setdefault("names", {})
            for field in ("display", "level"):
                if found[field]:
                    boss[field] = found[field]
            drops = boss.setdefault("drops", {})
            for item, chance in facts["drops"].get(str(found["npc"]), {}).items():
                if int(item) in boss["items"]:
                    drops.setdefault(int(item), chance)
    for key, quests in facts["quests"].items():
        dungeon = dungeons[key]
        # Quêtes du donjon ; les prérequis en monde ouvert (seul FDS les liste, « FDS(pre) ») restent hors du donjon.
        known = {quest["id"] for quest in dungeon.get("quests", [])}
        for quest in quests:
            if quest["id"] in known or quest["sources"] == "FDS(pre)":
                continue
            known.add(quest["id"])
            dungeon.setdefault("quests", []).append({
                "id": quest["id"], "title": quest["title"], "level": quest["level"], "min": quest["min"],
                "side": {"Alliance": "a", "Horde": "h"}.get(quest["side"]),
                "giver": [quest["giverName"], quest["zone"]] if quest["giverName"] else None, "need": [], "rewards": []})
    # Activité de recherche de groupe (table GroupFinderActivity de Blizzard, relevée par GearFinderClassic et
    # ForeverDungeonScout) : ses niveaux l'emportent sur AtlasLoot ; l'addon les relit en jeu par C_LFGList.
    # XP Forever des quêtes : ForeverDungeonJournal, sinon ForeverDungeonScout ; le jeu l'emporte (GetQuestLogRewardXP).
    for key, (activity, low, high) in classic["activities"].items():
        dungeons[key]["activity"] = activity
        dungeons[key]["levels"] = "%d,%d,%d" % (low, low, high)
    for dungeon in dungeons.values():
        for quest in dungeon.get("quests", []):
            quest["xp"] = classic["questXP"].get(str(quest["id"]))


def parse_lua_value(text, pos=0):
    """Valeur littérale Lua (nil, nombre, chaîne, table) ; rend (valeur, position suivante). Tables : listes."""
    while text[pos] in " \t":
        pos += 1
    if text[pos] == "{":
        pos += 1
        items = []
        while True:
            while text[pos] in " \t,":
                pos += 1
            if text[pos] == "}":
                return items, pos + 1
            if text[pos] == "[":   # clé explicite [zoneID] = ... : ignorée, seuls les champs de tête comptent
                pos = text.index("=", pos) + 1
            value, pos = parse_lua_value(text, pos)
            items.append(value)
    if text[pos] in "\"'":
        quote, pos, chars = text[pos], pos + 1, []
        while text[pos] != quote:
            if text[pos] == "\\":
                pos += 1
            chars.append(text[pos])
            pos += 1
        return "".join(chars), pos + 1
    match = re.compile(r"-?[0-9.]+|nil|true|false").match(text, pos)
    word = match.group(0)
    return (None if word in ("nil", "false") else True if word == "true" else float(word) if "." in word else int(word)), match.end()


def load_quest_db(folder):
    """questID -> (titre enUS, prérequis directs [questID], startedBy {npcs, objets, items}).

    Prérequis : preQuestSingle (champ 13) puis preQuestGroup (champ 12). startedBy : champ 2."""
    titles, pre, starts = {}, {}, {}
    pattern = re.compile(r"^\[(\d+)\] = (\{.*\}),$")
    with open(os.path.join(folder, "foreverQuestDB.lua"), encoding="utf-8") as handle:
        for line in handle:
            match = pattern.match(line)
            if match:
                fields = parse_lua_value(match.group(2))[0]
                fields += [None] * (13 - len(fields))
                quest = int(match.group(1))
                titles[quest] = fields[0]
                starts[quest] = fields[1]
                pre[quest] = {"preQuestSingle": fields[12] or [], "preQuestGroup": fields[11] or []}
    # QuestieDB src/corrections/Forever : titres des quêtes absentes de la base (foreverBaseQuest.lua), puis champs
    # preQuest corrigés à la main (foreverQuestFixes.lua). Chaque ligne remplace son seul champ, comme dans Questie.
    head = re.compile(r"^\s*\[(\d+)\] = \{ -- (.+?)(?: : https?://\S+)?\s*$")
    pre_key = re.compile(r"^\s*\[questKeys\.(preQuestSingle|preQuestGroup)\] = \{([\d,\s]*)\}")
    start_key = re.compile(r"^\s*\[questKeys\.startedBy\] = (\{.*\}),\s*$")
    for name in ("foreverBaseQuest.lua", "foreverQuestFixes.lua"):
        path = os.path.join(folder, name)
        if not os.path.exists(path):
            continue
        current = None
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                match = head.match(line)
                if match:
                    current = int(match.group(1))
                    titles.setdefault(current, match.group(2))
                    continue
                match = pre_key.match(line)
                if match and current is not None:
                    pre.setdefault(current, {})[match.group(1)] = [int(q) for q in match.group(2).split(",") if q.strip()]
                match = start_key.match(line)
                if match and current is not None:
                    starts[current] = parse_lua_value(match.group(1))[0]
    return {quest: (title, list(dict.fromkeys(q for q in pre.get(quest, {}).get("preQuestSingle", [])
                                              + pre.get(quest, {}).get("preQuestGroup", []) if q)),
                    starts.get(quest))
            for quest, title in titles.items()}


def write_tactics(tactics, texts):
    """Écrit Tactics/<langue>.lua : note et capacités (nom, texte) de chaque combat numéroté. enUS sert de base."""
    folder = os.path.join(HERE, "..", "Tactics")
    os.makedirs(folder, exist_ok=True)
    for locale in TEXT_LOCALES:
        if locale not in texts:
            print("textes absents : " + locale, file=sys.stderr)
            continue
        clients = [locale] + SAME_TEXTS.get(locale, [])
        out = ["-- Généré par tools/generate_data.py : ne pas éditer à la main."]
        if locale != "enUS":
            out += ["local locale = GetLocale()",
                    "if %s then return end" % " and ".join('locale ~= "%s"' % client for client in clients)]
        out += ["local _, NS = ...", "NS.Tactics = NS.Tactics or {}", "local T = NS.Tactics"]
        for number, (page, key) in enumerate(tactics, 1):
            expected = len(texts["frFR"][page]["fights"][key]["abilities"])
            # Texte absent ou périmé (le site a changé le combat) : repli sur l'anglais, puis sur le français du site.
            for source in (locale, "enUS", "frFR"):
                fight = texts.get(source, {}).get(page, {}).get("fights", {}).get(key)
                if fight is not None and len(fight["abilities"]) == expected:
                    break
            if source != locale:
                print("combat sans texte %s (repli %s) : %s/%s" % (locale, source, page, key), file=sys.stderr)
            parts = ["note = %s" % lua_string(fight["trigger"])] if fight.get("trigger") else []
            parts += ["{ %s, %s }" % (lua_string(a["name"]), lua_string(a.get("text") or "")) for a in fight["abilities"]]
            out.append("T[%d] = { %s }" % (number, ", ".join(parts)))
        with open(os.path.join(folder, locale + ".lua"), "w", encoding="utf-8", newline="\n") as handle:
            handle.write("\n".join(out) + "\n")


def place(boss, floors, journal):
    """Repère du site (relevé sur Forever) d'abord, puis placement à vue, puis journal retail."""
    if boss.get("pin"):
        return boss["pin"]
    if boss["npc"] in POSITIONS:
        return POSITIONS[boss["npc"]]
    for candidate in [boss["name"]] + ALIASES.get(boss["name"], []):
        for ui_map, x, y in journal.get(normalize(candidate), []):
            if ui_map in floors:
                return ui_map, x, y
    return None


def lua_number(value):
    return ("%.2f" % value).rstrip("0").rstrip(".")


def lua_boss_extras(boss):
    parts = []
    if boss.get("display"):
        parts.append("display = %d," % boss["display"])
    if boss.get("level"):
        parts.append("level = %d," % boss["level"])
    if boss.get("rare"):
        parts.append("rare = true,")
    if boss.get("names"):
        parts.append("names = { %s }," % ", ".join(
            "%s = %s" % (locale, lua_string(boss["names"][locale])) for locale in TEXT_LOCALES if locale in boss["names"]))
    if boss.get("drops"):
        parts.append("drops = { %s }," % ", ".join("[%d] = %s" % (i, lua_number(c)) for i, c in boss["drops"].items()))
    fight = boss.get("fight") or {}
    if boss.get("tactic"):
        parts.append("tactic = %d," % boss["tactic"])
    if fight.get("abilities"):
        abilities = []
        for ability in fight["abilities"]:
            fields = ["spell = %d," % ability["spell"]] if ability.get("spell") else []
            fields += ["icon = %s," % lua_string(ability.get("icon") or "inv_misc_questionmark"),
                       "flags = %s" % lua_string(",".join(ability.get("flags") or []))]
            abilities.append("{ %s }" % " ".join(fields))
        parts.append("abilities = { %s }," % ", ".join(abilities))
    return (" " + " ".join(parts)) if parts else ""


def lua_quest(quest, quest_db, npc_names, spawns):
    pre = [{"id": q, "title": quest_db[q][0]} for q in quest_db.get(quest["id"], (None, []))[1] if q in quest_db]
    giver = quest.get("giver") or []
    start = list((quest_db.get(quest["id"]) or (None, [], None))[2] or []) + [None] * 3
    givers = [n for n in start[0] or [] if n in npc_names]
    # Position du donneur : celui de Questie qui porte le nom affiché, ou le seul donneur de Questie.
    named = [n for n in givers if giver and normalize(npc_names[n]) == normalize(giver[0])]
    spot = spawns.get((named or givers)[0]) if named or len(givers) == 1 else None
    fields = ["id = %d," % quest["id"], "title = %s," % lua_string(quest["title"])]
    if quest["level"] and quest["min"]:
        fields.append("level = %d, min = %d," % (quest["level"], quest["min"]))
    elif quest["level"]:
        fields.append("level = %d," % quest["level"])
    if quest.get("xp"):
        fields.append("xp = %d," % quest["xp"])
    if quest.get("side"):
        fields.append("side = %s," % lua_string(quest["side"]))
    if giver:
        fields.append("giver = %s," % lua_string(giver[0]))
        if len(giver) > 1 and giver[1]:
            # Le site range les donneurs de Forgefer sous Dun Morogh : la carte du donneur (Questie) l'emporte.
            if spot and giver[1] in ZONE_MAPS and spot[0] != ZONE_MAPS[giver[1]] \
                    and spot[0] in ZONE_MAPS.values():
                giver = [giver[0], next(name for name, uiMap in ZONE_MAPS.items() if uiMap == spot[0])]
            fields.append("zone = %s," % lua_string(giver[1]))
            if giver[1] in ZONE_MAPS:
                fields.append("zoneMap = %d," % ZONE_MAPS[giver[1]])
            elif giver[1] in ZONE_INSTANCES:
                fields.append("zoneInstance = %d," % ZONE_INSTANCES[giver[1]])
            else:
                print("zone de quête sans carte : %s" % giver[1], file=sys.stderr)
    else:
        # Sans donneur sur le site : celui de Questie (startedBy), sinon l'objet qui lance la quête.
        npc = givers[0] if givers else None
        if npc:
            fields.append("giver = %s," % lua_string(npc_names[npc]))
        elif start[2]:
            fields.append("startItem = %d," % start[2][0])
    if spot and (giver or givers) and quest["id"] not in GIVER_CONFLICTS:
        fields.append("giverMap = %d, gx = %.3f, gy = %.3f," % spot)
    if pre:
        fields.append("pre = { %s }," % ", ".join("{ id = %d, title = %s }" % (q["id"], lua_string(q["title"])) for q in pre))
    fields += ["need = { %s }," % ", ".join(str(i) for i in quest.get("need") or [] if i),
               "rewards = { %s }" % ", ".join(str(i) for i in quest.get("rewards") or [] if i)]
    return "{ %s }" % " ".join(fields)


def dungeon_status(dungeon, upcoming):
    """verified : Classic, données d'AtlasLoot ; beta : donjon Forever, boss du site ; unconfirmed : donjon à venir."""
    if upcoming:
        return "unconfirmed"
    return "verified" if dungeon["source"] == "atlasloot" else "beta"


def main(folder):
    quest_db = load_quest_db(folder)
    npc_names = {**MANUAL_NPC_NAMES, **load_npc_names(folder)}
    spawns = load_npc_spawns(folder)
    dungeons = load_bosses(folder)
    floor_tiles = load_tiles(folder)
    journal = load_journal(folder)
    item_status, texts = merge_site(dungeons, load_npc_ids(folder))
    merge_competitor_facts(dungeons)
    # Niveau absent des autres sources : niveau maximal de Questie, sauf boss dont les concurrents se contredisent
    # (« Nom (npcID) level: … » dans les conflits de classic_facts.json).
    with open(os.path.join(HERE, "classic_facts.json"), encoding="utf-8") as handle:
        disputed = {int(npc) for line in json.load(handle)["conflicts"] for npc in re.findall(r"\((\d+)\) level:", line)}
    level_pattern = re.compile(r"^\[(\d+)\] = \{'(?:[^'\\]|\\.)*',\d+,\d+,\d+,(\d+),")
    with open(os.path.join(folder, "foreverNpcDB.lua"), encoding="utf-8") as handle:
        npc_levels = {int(m.group(1)): int(m.group(2)) for m in map(level_pattern.match, handle) if m}
    for dungeon in dungeons.values():
        for boss in dungeon["bosses"]:
            if not boss.get("level") and boss["npc"] not in disputed and npc_levels.get(boss["npc"]):
                boss["level"] = npc_levels[boss["npc"]]
    npc_ids = {b["npc"] for d in dungeons.values() for b in d["bosses"] if b["npc"]}
    # Chances absentes du site : celles d'AtlasLoot, pour les objets déjà listés sur le boss.
    rates = load_droprates(folder)
    for dungeon in dungeons.values():
        for boss in dungeon["bosses"]:
            known = {}
            for npc in [boss["npc"]] + boss["other_npcs"]:
                known.update(rates.get(npc, {}))
            drops = boss.setdefault("drops", {})
            for item in boss["items"]:
                if item not in drops and item in known:
                    drops[item] = known[item]
    names = load_names(folder, npc_ids)
    # Derniers manques comblés par l'infobulle Wowhead Forever (wowhead_fetch.py) : jamais par-dessus une autre source.
    with open(os.path.join(HERE, "wowhead_facts.json"), encoding="utf-8") as handle:
        wowhead = json.load(handle)
    with open(os.path.join(HERE, "upcoming_facts.json"), encoding="utf-8") as handle:
        conflicts = json.load(handle)["conflicts"]
    disputed_quests = {(int(quest), field) for line in conflicts
                       for quest, field in re.findall(r"^quest (\d+) .*?: (\w+) ", line)}
    # « Nom FDS=… FDJ=… » d'une ligne « display mismatch » : modèle laissé vide exprès, pas comblé.
    disputed_displays = {normalize(name) for line in conflicts if "display mismatch" in line
                         for name in re.findall(r" ?([^:;]+?) FDS=\d+ FDJ=\d+", line.split(":", 1)[1])}
    # « [Nom] » : Wowhead n'a pas la traduction et rend l'anglais entre crochets.
    named = {(boss["npc"], locale) for d in dungeons.values() for boss in d["bosses"] for locale in boss.get("names") or {}}
    for locale, found in wowhead["bossNames"].items():
        for npc, name in found.items():
            if int(npc) in npc_ids and (int(npc), locale) not in named and not name.startswith("["):
                names.setdefault(locale, {}).setdefault(int(npc), name)
    for dungeon in dungeons.values():
        for boss in dungeon["bosses"]:
            if not boss.get("level") and boss["npc"] not in disputed and str(boss["npc"]) in wowhead["bossLevels"]:
                boss["level"] = wowhead["bossLevels"][str(boss["npc"])]
            # Page PNJ Wowhead Forever (relevé par navigateur) : niveau, modèle, chances des objets du boss, sorts.
            found = wowhead["bossFacts"].get(str(boss["npc"]), {})
            if not boss.get("level") and boss["npc"] not in disputed and found.get("level"):
                boss["level"] = found["level"]
            if not boss.get("display") and normalize(boss["name"]) not in disputed_displays and found.get("display"):
                boss["display"] = found["display"]
            drops = boss.setdefault("drops", {})
            for item, chance in found.get("drops", {}).items():
                if int(item) in boss["items"]:
                    drops.setdefault(int(item), chance)
            # Sort d'une capacité sans sort : seulement si une seule capacité Wowhead du boss porte la même icône.
            spells = {}
            for spell, icon in found.get("abilities", []):
                spells.setdefault(icon, []).append(spell)
            for ability in (boss.get("fight") or {}).get("abilities", []):
                if not ability.get("spell") and len(spells.get(ability["icon"], [])) == 1:
                    ability["spell"] = spells[ability["icon"]][0]
        for quest in dungeon.get("quests", []):
            if not quest["level"] and str(quest["id"]) in wowhead["questLevels"]:
                quest["level"] = wowhead["questLevels"][str(quest["id"])]
            # Page de quête Wowhead Forever (relevé par navigateur) : niveau, niveau requis, XP au niveau de la quête.
            # Champ laissé vide sur désaccord des concurrents (« quest N …: min » d'upcoming_facts.json) : pas comblé.
            for field, value in wowhead["questFacts"].get(str(quest["id"]), {}).items():
                if not quest.get(field) and (quest["id"], field) not in disputed_quests:
                    quest[field] = value

    ordered = sorted(dungeons, key=lambda k: [int(v) for v in dungeons[k]["levels"].split(",")] + [k])
    tactics = []   # (page du site, clé du combat) ; le rang + 1 est le numéro du combat dans Data.lua et Tactics/
    for key in ordered:
        for boss in dungeons[key]["bosses"]:
            fight = boss.get("fight") or {}
            if fight.get("trigger") or fight.get("abilities"):
                tactics.append(boss["fight_ref"])
                boss["tactic"] = len(tactics)
    write_tactics(tactics, texts)
    out = ["-- Généré par tools/generate_data.py : ne pas éditer à la main.", "local _, NS = ...", "", "NS.Floors = {"]
    for ui_map in sorted(floor_tiles):
        out.append("    [%d] = { %s }," % (ui_map, ", ".join(str(f) for f in floor_tiles[ui_map])))
    for floor, view in sorted(MINIMAP_FLOORS.items()):
        out.append("    [%d] = { cols = %d, scale = %s, left = %s, top = %s, %s }," % (
            floor, view["cols"], view["scale"], view["left"], view["top"], ", ".join(str(f) for f in view["tiles"])))
    out += ["}", "", "NS.FloorLinks = {"]
    for floor, links in sorted(FLOOR_LINKS.items()):
        out.append("    [%d] = { %s }," % (floor, ", ".join("%s, %s, %d" % link for link in links)))
    out += ["}", "", "NS.Dungeons = {"]
    unplaced = []
    for key in ordered:
        dungeon = dungeons[key]
        floors = FLOORS.get(key, [])
        upcoming = dungeon["instance"] == "0"
        out.append("    {")
        out.append("        key = %s, instance = %s, wing = %s,%s%s status = %s, levels = { %s }," % (
            lua_string(key), dungeon["instance"] or WINGS[key][1], lua_string(WINGS[key][0]) if key in WINGS else "nil",
            " name = %s," % lua_string(DUNGEON_NAMES[key]) if key in DUNGEON_NAMES else "", " upcoming = true," if upcoming else "",
            lua_string(dungeon_status(dungeon, upcoming)), dungeon["levels"].replace(",", ", ")))
        if dungeon.get("activity"):
            out.append("        activity = %d," % dungeon["activity"])
        if key in ENTRANCES:
            out.append("        entrance = { map = %d, x = %s, y = %s }," % (
                ENTRANCES[key][0], lua_number(ENTRANCES[key][1]), lua_number(ENTRANCES[key][2])))
        if key in SECOND_ENTRANCES:
            out.append("        secondEntrance = { map = %d, x = %s, y = %s }," % (
                SECOND_ENTRANCES[key][0], lua_number(SECOND_ENTRANCES[key][1]), lua_number(SECOND_ENTRANCES[key][2])))
        out.append("        floors = { %s }," % ", ".join(str(f) for f in floors))
        out.append("        bosses = {")
        for boss in dungeon["bosses"]:
            if boss["npc"] in HIDDEN:
                continue
            position = place(boss, floors, journal)
            if position is None:
                unplaced.append("%s: %s (%s)" % (key, boss["name"], boss["npc"]))
                where = ""
            else:
                assert position[0] in floors, (key, boss["name"], position)
                where = " floor = %d, x = %.3f, y = %.3f," % position
            others = " otherNpcs = { %s }," % ", ".join(str(n) for n in boss["other_npcs"]) if boss["other_npcs"] else ""
            out.append("            { npc = %s, name = %s,%s%s items = { %s },%s }," % (
                boss["npc"] or "nil", lua_string(boss["name"]), where, others, ", ".join(str(i) for i in boss["items"]),
                lua_boss_extras(boss)))
        out.append("        },")
        out.append("        quests = {")
        for quest in dungeon.get("quests", []):
            out.append("            %s," % lua_quest(quest, quest_db, npc_names, spawns))
        out.append("        },")
        out.append("    },")
    out += ["}", "", "NS.ItemStatus = {"]
    for item in sorted(item_status):
        out.append("    [%d] = %s," % (item, lua_string(item_status[item])))
    out += ["}", "", "NS.BossNames = {"]
    for locale in sorted(names):
        out.append("    %s = {" % locale)
        for npc in sorted(names[locale]):
            out.append("        [%d] = %s," % (npc, lua_string(names[locale][npc])))
        out.append("    },")
    out.append("}")
    sys.stdout.buffer.write(("\n".join(out) + "\n").encode("utf-8"))
    assert set(ENTRANCES) <= set(dungeons), set(ENTRANCES) - set(dungeons)
    all_floors = {f for floors in FLOORS.values() for f in floors}
    assert all(floor in all_floors and target in all_floors for floor, links in FLOOR_LINKS.items() for _, _, target in links)
    assert set(SECOND_ENTRANCES) <= set(ENTRANCES), set(SECOND_ENTRANCES) - set(ENTRANCES)
    for key in ordered:
        for quest in dungeons[key].get("quests", []):
            for pre in quest_db.get(quest["id"], (None, []))[1]:
                if pre not in quest_db:
                    print("prérequis absent de QuestieDB : quête %d, prérequis %d" % (quest["id"], pre), file=sys.stderr)
    for line in unplaced:
        print("sans position : " + line, file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1])
