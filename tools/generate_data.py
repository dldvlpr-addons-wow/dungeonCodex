"""Génère Data.lua à partir des sources publiques téléchargées dans un dossier de travail.

Sources attendues dans <dossier> :
  bosses.txt                sortie de atlasloot_export.lua (boss et loot, AtlasLootClassic)
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
unconfirmed = donjon à venir (instanceID 0, `upcoming = true`, sans boss ni carte).
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

from manual_positions import FLOORS, ALIASES, POSITIONS, WINGS, HIDDEN, SITE_SLUGS, SITE_DUNGEONS, MINIMAP_FLOORS, ENTRANCES, DUNGEON_NAMES, MANUAL_NPCS, MANUAL_BOSS_NAMES, MANUAL_NPC_NAMES

HERE = os.path.dirname(os.path.abspath(__file__))

LOCALES = ["deDE", "esES", "esMX", "frFR", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"]
# Langues des textes de combat (Tactics/<langue>.lua) et clients qui partagent un même fichier.
TEXT_LOCALES = ["enUS", "frFR", "deDE", "esES", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"]
SAME_TEXTS = {"esES": ["esMX"]}
# Zone du donneur de quête (texte du site, français ou anglais) vers l'UiMapID Classic de Forever : le client en donne
# le nom dans sa langue. Zone qui est une instance (Hache-tripes) : nom par GetRealZoneText(instance).
ZONE_INSTANCES = {"Hache-tripes": 429}
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


def load_bosses(folder):
    dungeons = {}
    forever = os.path.join(HERE, "forever_dungeons.txt")
    with open(os.path.join(folder, "bosses.txt"), encoding="utf-8") as handle, open(forever, encoding="utf-8") as extra:
        lines = [("atlasloot", line) for line in handle] + [("forever", line) for line in extra]
    for source, line in lines:
        key, instance, levels, order, npcs, name, items = line.rstrip("\n").split("|")
        dungeon = dungeons.setdefault(key, {"instance": instance, "levels": levels, "bosses": [], "source": source})
        npc_ids = [int(n) for n in npcs.split(",") if n]
        dungeon["bosses"].append({
            "order": int(order),
            "npc": npc_ids[0] if npc_ids else None,
            "other_npcs": npc_ids[1:],
            "name": name.replace('\\"', '"'),
            "items": [int(i) for i in items.split(",") if i],
        })
    return dungeons


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
        dungeons[key] = {"instance": str(instance), "levels": "", "bosses": [], "source": "forever"}
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
    return status, texts


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


def lua_quest(quest, quest_db, npc_names):
    pre = [{"id": q, "title": quest_db[q][0]} for q in quest_db.get(quest["id"], (None, []))[1] if q in quest_db]
    giver = quest.get("giver") or []
    fields = ["id = %d," % quest["id"], "title = %s," % lua_string(quest["title"]),
              "level = %d," % (quest["level"] or 0), "min = %d," % (quest["min"] or 0)]
    if quest.get("side"):
        fields.append("side = %s," % lua_string(quest["side"]))
    if giver:
        fields.append("giver = %s," % lua_string(giver[0]))
        if len(giver) > 1 and giver[1]:
            fields.append("zone = %s," % lua_string(giver[1]))
            if giver[1] in ZONE_MAPS:
                fields.append("zoneMap = %d," % ZONE_MAPS[giver[1]])
            elif giver[1] in ZONE_INSTANCES:
                fields.append("zoneInstance = %d," % ZONE_INSTANCES[giver[1]])
            else:
                print("zone de quête sans carte : %s" % giver[1], file=sys.stderr)
    else:
        # Sans donneur sur le site : celui de Questie (startedBy), sinon l'objet qui lance la quête.
        start = list((quest_db.get(quest["id"]) or (None, [], None))[2] or []) + [None] * 3
        npc = next((n for n in start[0] or [] if n in npc_names), None)
        if npc:
            fields.append("giver = %s," % lua_string(npc_names[npc]))
        elif start[2]:
            fields.append("startItem = %d," % start[2][0])
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
    dungeons = load_bosses(folder)
    floor_tiles = load_tiles(folder)
    journal = load_journal(folder)
    item_status, texts = merge_site(dungeons, load_npc_ids(folder))
    npc_ids = {b["npc"] for d in dungeons.values() for b in d["bosses"] if b["npc"]}
    names = load_names(folder, npc_ids)

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
        if key in ENTRANCES:
            out.append("        entrance = { map = %d, x = %s, y = %s }," % (
                ENTRANCES[key][0], lua_number(ENTRANCES[key][1]), lua_number(ENTRANCES[key][2])))
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
            out.append("            %s," % lua_quest(quest, quest_db, npc_names))
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
    for key in ordered:
        for quest in dungeons[key].get("quests", []):
            for pre in quest_db.get(quest["id"], (None, []))[1]:
                if pre not in quest_db:
                    print("prérequis absent de QuestieDB : quête %d, prérequis %d" % (quest["id"], pre), file=sys.stderr)
    for line in unplaced:
        print("sans position : " + line, file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1])
