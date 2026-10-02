"""Génère Data.lua à partir des sources publiques téléchargées dans un dossier de travail.

Sources attendues dans <dossier> :
  bosses.txt                sortie de atlasloot_export.lua (boss et loot, AtlasLootClassic)
  rt-UiMapXMapArt.csv       DB2 retail (wago.tools/db2/UiMapXMapArt/csv?build=<retail>)
  rt-UiMapArtTile.csv       DB2 retail (tuiles ; fichiers présents dans le client Forever)
  rt-JournalEncounter.csv   DB2 retail (coordonnées des boss sur les cartes)
  mc-JournalEncounter.csv   DB2 MoP Classic 5.5.4 (ancien Blackrock Spire, anciens boss), en second
  npc-<locale>.lua          QuestieDB l10n/Forever/lookupNpcs/<locale>.lua
  foreverNpcDB.lua          QuestieDB data/Forever/foreverNpcDB.lua (npcID des boss ajoutés par le site)

Donjons propres à Forever, absents d'AtlasLoot : tools/forever_dungeons.txt, même format que bosses.txt.
Niveaux, boss en plus, butin (chances, nouveautés), portraits, positions, capacités et quêtes de
Forever : tools/foreverchanges.json (foreverchanges.pro, extrait par foreverchanges_extract.py).
Textes des combats et noms de boss des autres langues : tools/texts/<langue>.json (même extracteur
pour les langues du site, traduction du français pour les autres).

Usage : python generate_data.py <dossier> > ../Data.lua   (écrit aussi ../Tactics/<langue>.lua)
"""
import csv
import json
import os
import re
import sys

from manual_positions import FLOORS, ALIASES, POSITIONS, WINGS, HIDDEN, SITE_SLUGS, SITE_DUNGEONS, MINIMAP_FLOORS

HERE = os.path.dirname(os.path.abspath(__file__))

LOCALES = ["deDE", "esES", "esMX", "frFR", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"]
# Langues des textes de combat (Tactics/<langue>.lua) et clients qui partagent un même fichier.
TEXT_LOCALES = ["enUS", "frFR", "deDE", "esES", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"]
SAME_TEXTS = {"esES": ["esMX"]}


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
        for line in list(handle) + list(extra):
            key, instance, levels, order, npcs, name, items = line.rstrip("\n").split("|")
            dungeon = dungeons.setdefault(key, {"instance": instance, "levels": levels, "bosses": []})
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
    return {name: max(found)[2] for name, found in candidates.items()}


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


def merge_site(dungeons, npc_ids):
    """Complète chaque donjon avec foreverchanges.json ; boss rapprochés par nom anglais. Rend l'état des objets et les textes."""
    with open(os.path.join(HERE, "foreverchanges.json"), encoding="utf-8") as handle:
        site = {page["slug"]: page for page in json.load(handle)}
    texts = load_texts(site)
    for key, (slug, instance) in SITE_DUNGEONS.items():
        dungeons[key] = {"instance": str(instance), "levels": "", "bosses": []}
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
                    if same_floors:
                        ax, bx, ay, by = MINIMAP_FLOORS.get(FLOORS[key][index], {}).get("pins", (1, 0, 1, 0))
                        pins.setdefault(pin["boss"], (FLOORS[key][index], ax * pin["x"] / 100 + bx, ay * pin["y"] / 100 + by))
            for quest in page["quests"]:
                if quest["id"] not in seen:
                    seen.add(quest["id"])
                    quests.append(quest)
        dungeon["quests"] = quests
        by_name = {normalize(boss["name"]): boss for boss in dungeon["bosses"]}
        for page in pages:
            for found in page["bosses"]:
                if found["kind"] not in ("boss", "rare"):
                    continue
                name = re.sub(r"^Ring of Law: ", "", found["english"])
                boss = by_name.get(normalize(name))
                if boss is None:
                    boss = {"order": 999, "npc": npc_ids.get(normalize(name)), "other_npcs": [], "name": name, "items": []}
                    dungeon["bosses"].append(boss)
                    by_name[normalize(name)] = boss
                slug = slugify(found["english"])
                listed = [item["id"] for item in found["items"]]
                names = {locale: pages_of[page["slug"]]["bosses"].get(found["english"])
                         for locale, pages_of in texts.items() if page["slug"] in pages_of and "bosses" in pages_of[page["slug"]]}
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
            fight = texts[locale].get(page, {}).get("fights", {}).get(key)
            if fight is None or len(fight["abilities"]) != len(texts["frFR"][page]["fights"][key]["abilities"]):
                print("combat sans texte %s : %s/%s" % (locale, page, key), file=sys.stderr)
                continue
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


def lua_quest(quest):
    giver = quest.get("giver") or []
    fields = ["id = %d," % quest["id"], "title = %s," % lua_string(quest["title"]),
              "level = %d," % (quest["level"] or 0), "min = %d," % (quest["min"] or 0)]
    if quest.get("side"):
        fields.append("side = %s," % lua_string(quest["side"]))
    if giver:
        fields.append("giver = %s," % lua_string(giver[0]))
        if len(giver) > 1 and giver[1]:
            fields.append("zone = %s," % lua_string(giver[1]))
    fields += ["need = { %s }," % ", ".join(str(i) for i in quest.get("need") or [] if i),
               "rewards = { %s }" % ", ".join(str(i) for i in quest.get("rewards") or [] if i)]
    return "{ %s }" % " ".join(fields)


def main(folder):
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
        out.append("    {")
        out.append("        key = %s, instance = %s, wing = %s, levels = { %s }," % (
            lua_string(key), dungeon["instance"] or WINGS[key][1], lua_string(WINGS[key][0]) if key in WINGS else "nil",
            dungeon["levels"].replace(",", ", ")))
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
            out.append("            %s," % lua_quest(quest))
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
    for line in unplaced:
        print("sans position : " + line, file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1])
