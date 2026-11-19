"""Comble les manques de Data.lua par l'API d'infobulles de Wowhead (branche Forever).

Lit ../Data.lua, interroge nether.wowhead.com/forever/tooltip seulement pour ce qui manque, et range les réponses
dans wowhead_facts.json (cache : une valeur déjà relevée n'est pas redemandée). generate_data.py fusionne ce
fichier sans écraser les autres sources.

Relevé :
  bossNames[locale][npc]  nom traduit d'un boss absent de Data.lua (gardé seulement s'il diffère de l'anglais)
  bossLevels[npc]         niveau d'un boss sans niveau, quand l'infobulle l'affiche
  questLevels[quest]      niveau d'une quête sans niveau

Les pages www.wowhead.com sont bloquées aux scripts. questFacts[quest] (level, min, xp) a été relevé à la main
depuis ces pages dans un navigateur, et ce script le conserve tel quel. Même chose pour bossFacts[npc] (level,
display, drops {objet: %}, abilities [[sort, icône]]), relevé par navigateur sur les pages PNJ des 107 boss.

Usage : python3 wowhead_fetch.py
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
FACTS = os.path.join(HERE, "wowhead_facts.json")
API = "https://nether.wowhead.com/forever/tooltip/%s/%d?locale=%d"
# Identifiants de langue de Wowhead, relevés sur le PNJ 11520 (Taragaman). itIT absent : Wowhead rend l'anglais.
LOCALES = {"koKR": 1, "frFR": 2, "deDE": 3, "zhCN": 4, "esES": 6, "ruRU": 7, "ptBR": 8, "zhTW": 10}
DELAY = 0.4


def fetch(kind, entity, locale=0):
    request = urllib.request.Request(API % (kind, entity, locale), headers={"User-Agent": "dungeonCodex-data-tool"})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise
    finally:
        time.sleep(DELAY)


def read_data():
    with open(os.path.join(HERE, "..", "Data.lua"), encoding="utf-8") as handle:
        text = handle.read()
    bosses = {}   # npc -> (nom anglais, niveau connu, langues connues)
    for line in text.splitlines():
        match = re.match(r'\s+\{ npc = (\d+), name = "((?:[^"\\]|\\.)*)"', line)
        if match:
            names = re.search(r"names = \{([^}]*)\}", line)
            known = set(re.findall(r"(\w{4}) = ", names.group(1))) if names else set()
            bosses[int(match.group(1))] = (match.group(2), " level = " in line, known)
    quests = [int(q) for q in re.findall(r'\{ id = (\d+), title = "(?:[^"\\]|\\.)*", (?!level)', text)]
    block = text[text.index("NS.BossNames = {"):]
    for locale, body in re.findall(r"\n    (\w{4}) = \{\n(.*?)\n    \},", block, re.S):
        for npc in re.findall(r"\[(\d+)\] = ", body):
            if int(npc) in bosses:
                bosses[int(npc)][2].add(locale)
    return bosses, quests


def main():
    facts = {"bossNames": {}, "bossLevels": {}, "questLevels": {}, "missing": []}
    if os.path.exists(FACTS):
        with open(FACTS, encoding="utf-8") as handle:
            facts.update(json.load(handle))
    asked = set(facts["missing"])   # entités déjà demandées sans réponse utile
    bosses, quests = read_data()
    try:
        for quest in quests:
            key = "quest:%d" % quest
            if str(quest) in facts["questLevels"] or key in asked:
                continue
            found = fetch("quest", quest)
            level = found and re.search(r">Level (\d+)<", found["tooltip"])
            if level:
                facts["questLevels"][str(quest)] = int(level.group(1))
            else:
                asked.add(key)
        for npc, (english, has_level, known) in sorted(bosses.items()):
            if not has_level and str(npc) not in facts["bossLevels"] and "level:%d" % npc not in asked:
                found = fetch("npc", npc)
                # « <td>Level 25 Undead (Elite)</td> » ; plage (« Level 45 - 46 ») écartée.
                level = found and re.search(r"<td>Level (\d+) (?!-)", found["tooltip"])
                if level:
                    facts["bossLevels"][str(npc)] = int(level.group(1))
                else:
                    asked.add("level:%d" % npc)
            for locale, code in LOCALES.items():
                key = "npc:%s:%d" % (locale, npc)
                if locale in known or str(npc) in facts["bossNames"].get(locale, {}) or key in asked:
                    continue
                found = fetch("npc", npc, code)
                # « [Nom] » : traduction absente chez Wowhead, qui rend l'anglais entre crochets.
                name = found["name"] if found and not found["name"].startswith("[") else None
                if name and name.replace("’", "'") != english.replace('\\"', '"').replace("’", "'"):
                    facts["bossNames"].setdefault(locale, {})[str(npc)] = found["name"]
                else:
                    asked.add(key)
    finally:
        facts["missing"] = sorted(asked)
        with open(FACTS, "w", encoding="utf-8") as handle:
            json.dump(facts, handle, ensure_ascii=False, indent=1, sort_keys=True)
            handle.write("\n")
    print("quêtes : %d niveaux ; boss : %d niveaux, %d noms" % (
        len(facts["questLevels"]), len(facts["bossLevels"]),
        sum(len(names) for names in facts["bossNames"].values())), file=sys.stderr)


if __name__ == "__main__":
    main()
