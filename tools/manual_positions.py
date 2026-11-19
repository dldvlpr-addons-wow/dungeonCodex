"""Données saisies à la main pour generate_data.py.

FLOORS    : étages (UiMapID retail) de chaque donjon, dans l'ordre d'affichage.
MINIMAP_FLOORS : étages faits de tuiles de minicarte du client, pour les donjons sans carte d'étage.
WINGS     : aile d'une instance partagée (clé de locale, instanceID si AtlasLoot ne le donne pas).
ALIASES   : noms du journal retail pour un boss nommé autrement dans AtlasLoot.
SITE_DUNGEONS : donjons Forever décrits par le site seul (instanceID 0 : à venir, sans carte). DUNGEON_NAMES : leur nom.
ENTRANCES : entrée de chaque donjon (UiMapID de zone, x, y), quand elle est connue.
POSITIONS : npcID -> (UiMapID, x, y) quand le journal retail n'a pas le boss ; placé à vue sur la carte.
HIDDEN    : npcID écartés du journal.
ANNEX_NAMES : noms localisés des listes annexes d'AtlasLoot (trash, livres, plans, tribut), repris de ses fichiers de locale (GPL-2).
"""

FLOORS = {
    "Ragefire": [213],
    "WailingCaverns": [279],
    "TheDeadmines": [291, 292],
    "ShadowfangKeep": [310, 311, 312, 313, 314, 315, 316],
    "BlackfathomDeeps": [221, 222, 223],
    "TheStockade": [225],
    "Gnomeregan": [226, 227, 228, 229],
    "RazorfenKraul": [301],
    "ScarletMonasteryGraveyard": [302],
    "ScarletMonasteryLibrary": [303],
    "ScarletMonasteryArmory": [304],
    "ScarletMonasteryCathedral": [305],
    "RazorfenDowns": [300],
    "Uldaman": [230, 231],
    "Zul'Farrak": [219],
    "Maraudon": [280, 281],
    "TheTempleOfAtal'Hakkar": [220],
    "BlackrockDepths": [242, 243],
    "LowerBlackrockSpire": [250, 251, 252, 253, 254, 255],
    "UpperBlackrockSpire": [250, 251, 252, 253, 254, 255],
    "DireMaulEast": [239, 240],
    "DireMaulWest": [236, 237, 238],
    "DireMaulNorth": [235],
    "Scholomance": [306, 307, 308, 309],
    "Stratholme": [317, 318],
    "RuinsOfLordaeron": [2999],   # donjon Forever : aucune carte d'étage, tuiles de minicarte (MINIMAP_FLOORS)
    "HallOfThanes": [3065],
    "CityOfDalaran": [2959],
    "ExcavationSite": [2998],
}

# Étages faits des tuiles de minicarte du client (512 px), pour les donjons sans carte d'étage.
# Clé : identifiant d'étage (l'instanceID).
#   tiles     : fileID des tuiles, ligne par ligne (WDT de la carte, chunk MAID, champ minimapTexture)
#   cols      : tuiles par ligne
#   scale     : taille d'une tuile, en multiple d'une tuile de carte retail
#   left, top : coin haut gauche de la vue, en tuiles depuis la première
#   pins      : (ax, bx, ay, by), du repère du site (posé sur une carte dessinée) à la vue : ax * x + bx, ay * y + by.
#               Sans `pins`, les repères du site ne sont pas posés (carte non calée) : les boss restent sans position.
# Le journal ne dispose que de 12 textures de carte (Journal.lua) : une fenêtre de 12 tuiles au plus, prise dans
# la grille réelle du WDT (index = ligne * 64 + colonne dans le chunk MAID).
MINIMAP_FLOORS = {
    2998: {   # WDT 7252920, grille réelle lignes 36-42 x colonnes 33-39 ; fenêtre lignes 38-40 x colonnes 34-37 (vue à régler en jeu)
        "tiles": [7287260, 7287262, 7287264, 7473476, 7287266, 7287268, 7287270, 7473482,
                  7287272, 7287274, 7287276, 7473484],
        "cols": 4, "scale": 0.97, "left": 0, "top": 0,
    },
    2959: {   # WDT 6982267, grille réelle lignes 29-33 x colonnes 29-33 ; fenêtre lignes 30-32 x colonnes 30-32, sur la cité
        "tiles": [6982326, 6982322, 6982391, 6982332, 6982328, 6982395, 6982439, 6982441, 6982489],
        "cols": 3, "scale": 1.8, "left": 0.315, "top": 0.875,
    },
    2999: {   # WDT 7255103, grille réelle lignes 27-29 x colonnes 30-32 (9 tuiles, toutes prises)
        "tiles": [7255712, 7255718, 7255724, 7255730, 7255736, 7255742, 7255748, 7255754, 7255760],
        "cols": 3, "scale": 2.33, "left": 0.695, "top": 1.42, "pins": (1.108, -0.070, 1.098, -0.062),
    },
    3065: {   # WDT 7713294, grille réelle lignes 25-33 x colonnes 27-35 (81 tuiles, presque toutes vides) ; fenêtre lignes 30-32 x colonnes 30-33
        "tiles": [7726080, 7726086, 7726092, 7726098, 7726134, 7726140, 7726146, 7726152,
                  7726188, 7726194, 7726200, 7726206],
        "cols": 4, "scale": 1.673, "left": 0.83, "top": 0.745, "pins": (0.690, 0.147, 0.732, 0.253),
    },
}

WINGS = {
    "ScarletMonasteryGraveyard": ("WING_GRAVEYARD", 189),
    "ScarletMonasteryLibrary": ("WING_LIBRARY", 189),
    "ScarletMonasteryArmory": ("WING_ARMORY", 189),
    "ScarletMonasteryCathedral": ("WING_CATHEDRAL", 189),
    "LowerBlackrockSpire": ("WING_LOWER", 229),
    "UpperBlackrockSpire": ("WING_UPPER", 229),
    "DireMaulEast": ("WING_EAST", 429),
    "DireMaulWest": ("WING_WEST", 429),
    "DireMaulNorth": ("WING_NORTH", 429),
}

SITE_SLUGS = {
    "Ragefire": ["ragefire-chasm"], "WailingCaverns": ["wailing-caverns"], "TheDeadmines": ["the-deadmines"],
    "ShadowfangKeep": ["shadowfang-keep"], "RuinsOfLordaeron": ["ruins-of-lordaeron"],
    "BlackfathomDeeps": ["blackfathom-deeps"], "TheStockade": ["the-stockade"], "Gnomeregan": ["gnomeregan"],
    "ScarletMonasteryGraveyard": ["scarlet-monastery-graveyard"], "ScarletMonasteryLibrary": ["scarlet-monastery-library"],
    "ScarletMonasteryArmory": ["scarlet-monastery-armory"], "ScarletMonasteryCathedral": ["scarlet-monastery-cathedral"],
    "RazorfenKraul": ["razorfen-kraul"], "Maraudon": ["maraudon"], "Uldaman": ["uldaman"],
    "DireMaulEast": ["dire-maul-east"], "DireMaulNorth": ["dire-maul-north"], "DireMaulWest": ["dire-maul-west"],
    "RazorfenDowns": ["razorfen-downs"], "Stratholme": ["stratholme-main-gate", "stratholme-service-gate"],
    "Zul'Farrak": ["zulfarrak"], "BlackrockDepths": ["blackrock-depths"], "TheTempleOfAtal'Hakkar": ["sunken-temple"],
    "Scholomance": ["scholomance"], "LowerBlackrockSpire": ["lower-blackrock-spire"],
    "UpperBlackrockSpire": ["upper-blackrock-spire"], "HallOfThanes": ["hall-of-thanes"],
    "CityOfDalaran": ["city-of-dalaran"], "ExcavationSite": ["excavation-site"], "TheDrownedCity": ["the-drowned-city"],
    "KroldokStronghold": ["kroldok-stronghold"], "AlcazPrison": ["alcaz-prison"], "BlackmawHold": ["blackmaw-hold"],
    "ShapersTerrace": ["shapers-terrace"],
}

# Donjons Forever décrits seulement par le site : clé -> (page du site, instanceID de la DB2 Map du client).
# instanceID 0 : donjon à venir (aucune ligne Map dans le build), sans carte ; le générateur pose `upcoming = true`.
SITE_DUNGEONS = {
    "HallOfThanes": ("hall-of-thanes", 3065),
    "CityOfDalaran": ("city-of-dalaran", 2959),
    "ExcavationSite": ("excavation-site", 2998),
    "TheDrownedCity": ("the-drowned-city", 0),
    "KroldokStronghold": ("kroldok-stronghold", 0),
    "AlcazPrison": ("alcaz-prison", 0),
    "BlackmawHold": ("blackmaw-hold", 0),
    "ShapersTerrace": ("shapers-terrace", 0),
}

# Nom (enUS) des donjons Forever absents du client : `name` dans Data.lua (le client n'a pas leur nom de zone).
DUNGEON_NAMES = {
    "CityOfDalaran": "City of Dalaran", "ExcavationSite": "Excavation Site", "TheDrownedCity": "The Drowned City",
    "KroldokStronghold": "Krol'dok Stronghold", "AlcazPrison": "Alcaz Prison", "BlackmawHold": "Blackmaw Hold",
    "ShapersTerrace": "The Shaper's Terrace",
}

# Entrée du donjon : (UiMapID de zone Forever, x, y entre 0 et 1).
# Classic : JournalInstanceEntrance retail 12.1.5.70688 (Position_0/1 en coordonnées monde), converti par la
# UiMapAssignment Forever 1.60.1.70753 (Region_0/1 = minimum, Region_3/4 = maximum) :
#   x = (ymax - y) / (ymax - ymin), y = (xmax - x) / (xmax - xmin).
# Zone : celle de l'AreaTableID de l'entrée ; Razorfen Kraul et Downs : Barrens, à la main (l'aire retail est fausse sur Forever).
# Dire Maul : trois points sans attribution dans les tables, répartis selon la géographie (ouest, nord, est).
# Maraudon : trois points, le premier de la table. Scarlet Monastery : Halls (bibliothèque, armurerie), Monastery (cimetière, cathédrale).
# Arbitrage 2026-11 sur les addons DungeonMaster, ForeverDungeonScout, ForeverDungeonJournal et MapUtils, notre valeur
# comptant pour une voix (écart sous 0.03 = accord) ; non vérifié en jeu, le relevé d'entrée de Run.lua (db.entrances,
# tools/found_export.lua) sert à le valider. Remplacés à la majorité : Deadmines, Blackfathom (Ashenvale), Stockade,
# Gnomeregan, Scarlet armurerie et cathédrale, Uldaman (Badlands), Maraudon, Temple, Blackrock Depths, Stratholme
# (porte principale), Hall of Thanes (Ironforge), Ruins of Lordaeron. Krol'dok : FDJ, FDS et DM contre MU.
# Blackmaw : FDJ, MU et DM contre FDS. Shaper's Terrace : ForeverDungeonScout seul.
ENTRANCES = {
    "Ragefire": (1454, 0.532, 0.487), "WailingCaverns": (1413, 0.477, 0.350), "TheDeadmines": (1436, 0.425, 0.717),
    "ShadowfangKeep": (1421, 0.446, 0.677), "BlackfathomDeeps": (1440, 0.145, 0.142), "TheStockade": (1453, 0.524, 0.700),
    "Gnomeregan": (1426, 0.243, 0.398), "RazorfenKraul": (1413, 0.422, 0.898), "RazorfenDowns": (1413, 0.509, 0.929),
    "ScarletMonasteryGraveyard": (1420, 0.848, 0.303), "ScarletMonasteryCathedral": (1420, 0.826, 0.338),
    "ScarletMonasteryLibrary": (1420, 0.854, 0.323), "ScarletMonasteryArmory": (1420, 0.826, 0.338),
    "Uldaman": (1418, 0.443, 0.120), "Zul'Farrak": (1446, 0.387, 0.199), "Maraudon": (1443, 0.291, 0.625),
    "TheTempleOfAtal'Hakkar": (1435, 0.695, 0.535), "BlackrockDepths": (1427, 0.348, 0.840),
    "LowerBlackrockSpire": (1428, 0.365, 0.254), "UpperBlackrockSpire": (1428, 0.360, 0.227),
    "DireMaulEast": (1444, 0.648, 0.301), "DireMaulNorth": (1444, 0.626, 0.249), "DireMaulWest": (1444, 0.603, 0.314),
    "Scholomance": (1422, 0.690, 0.727), "Stratholme": (1423, 0.307, 0.154),
    "HallOfThanes": (1455, 0.435, 0.520),
    # Relevés web du 2026-11-03, confirmés par l'arbitrage. Excavation : pierre de rencontre. Dalaran : grille d'égout.
    "ExcavationSite": (1437, 0.534, 0.653), "CityOfDalaran": (1416, 0.080, 0.610),
    "RuinsOfLordaeron": (1420, 0.634, 0.674),
    "TheDrownedCity": (1434, 0.213, 0.278), "KroldokStronghold": (2548, 0.375, 0.372), "AlcazPrison": (1445, 0.752, 0.144),
    "BlackmawHold": (1447, 0.386, 0.332), "ShapersTerrace": (1449, 0.481, 0.06),
}

# Passages d'un étage à l'autre : étage -> [(x, y, étage cible)], sur l'art des cartes retail. Faits relevés dans
# MapUtils (2026-11), non vérifiés en jeu ; ses positions par défaut (0.125, 0.080) et les étages 287-288, absents
# de FLOORS, sont écartés.
FLOOR_LINKS = {
    221: [(0.621, 0.741, 222)],
    222: [(0.477, 0.707, 223), (0.35, 0.29, 221)],
    223: [(0.3, 0.612, 222)],
    226: [(0.345, 0.64, 227), (0.47, 0.87, 227), (0.551, 0.44, 227)],
    227: [(0.245, 0.58, 228), (0.43, 0.83, 226), (0.64, 0.58, 226)],
    228: [(0.488, 0.71, 229), (0.273, 0.308, 229), (0.445, 0.43, 227)],
    229: [(0.481, 0.54, 228), (0.71, 0.773, 228)],
    230: [(0.485, 0.21, 231)],
    231: [(0.645, 0.41, 230)],
    236: [(0.27, 0.19, 237), (0.304, 0.43, 238)],
    237: [(0.415, 0.12, 236)],
    238: [(0.745, 0.4, 236)],
    239: [(0.505, 0.63, 240)],
    240: [(0.633, 0.844, 239)],
    242: [(0.655, 0.294, 243)],
    243: [(0.595, 0.547, 242)],
    280: [(0.145, 0.57, 281)],
    281: [(0.295, 0.04, 280)],
    291: [(0.655, 0.667, 292)],
    292: [(0.123, 0.883, 291)],
    310: [(0.367, 0.392, 311), (0.148, 0.866, 311), (0.355, 0.666, 316)],
    311: [(0.593, 0.121, 310), (0.273, 0.881, 310)],
    312: [(0.516, 0.904, 316), (0.533, 0.6, 313)],
    313: [(0.442, 0.749, 314), (0.526, 0.872, 312)],
    314: [(0.437, 0.743, 315), (0.49, 0.78, 313)],
    315: [(0.42, 0.842, 314)],
    316: [(0.239, 0.745, 310), (0.436, 0.331, 312)],
    317: [(0.9, 0.33, 318)],
    318: [(0.355, 0.39, 317), (0.57, 0.77, 317)],
}

# Seconde entrée, choisie quand le joueur est sur sa carte. Ruins : Undercity, ForeverDungeonScout (70.9, 12.0) et
# MapUtils (72.2, 11.5) concordent (2026-11), moyenne retenue, non vérifiée en jeu. Dalaran : Silverpine, MapUtils seul,
# sans contradiction. Stratholme (porte de service, 1423) écartée : même carte que l'entrée principale, le choix par carte
# ne les départage pas.
# Uldaman : ancienne entrée du Loch Modan. Blackrock Spire : entrée de la montagne côté Searing Gorge (FDJ).
SECOND_ENTRANCES = {"RuinsOfLordaeron": (1458, 0.716, 0.117), "CityOfDalaran": (1421, 0.692, 0.455),
                    "Uldaman": (1432, 0.348, 0.852), "LowerBlackrockSpire": (1427, 0.348, 0.840),
                    "UpperBlackrockSpire": (1427, 0.348, 0.840)}

ALIASES = {
    "Nekrum Gutchewer": ["Nekrum & Sezz'ziz"],
    "Shadowpriest Sezz'ziz": ["Nekrum & Sezz'ziz"],
    'Eric "The Swift"': ["The Lost Dwarves"],
    "Baelog": ["The Lost Dwarves"],
    "Olaf": ["The Lost Dwarves"],
    "Overlord Ramtusk": ["Warlord Ramtusk"],
    "Blind Hunter": ["Groyat, the Blind Hunter"],
    "Malor the Zealous": ["Commander Malor"],
    "Cannon Master Willey": ["Willey Hopebreaker"],
    "Archivist Galford": ["Instructor Galford"],
    "Baron Rivendare": ["Lord Aurius Rivendare"],
}

POSITIONS = {
    # Ragefire Chasm
    11520: (213, 0.340, 0.820),   # Taragaman the Hungerer
    11518: (213, 0.300, 0.550),   # Jergosh the Invoker
    # Wailing Caverns
    5912: (279, 0.470, 0.360),    # Deviate Faerie Dragon
    # Deadmines
    3586: (291, 0.300, 0.300),    # Miner Johnson
    642: (291, 0.470, 0.850),     # Sneed's Shredder
    # Shadowfang Keep
    3914: (310, 0.650, 0.700),    # Rethilgore
    3865: (310, 0.470, 0.300),    # Fel Steed / Shadow Charger
    3886: (310, 0.360, 0.320),    # Razorclaw the Butcher
    4279: (316, 0.350, 0.760),    # Odo the Blindwatcher
    3872: (316, 0.600, 0.820),    # Deathsworn Captain
    4627: (312, 0.520, 0.450),    # Arugal's Voidwalker
    4274: (313, 0.545, 0.537),    # Fenrus the Devourer
    3927: (315, 0.560, 0.620),    # Wolf Master Nandos
    4275: (315, 0.685, 0.335),    # Archmage Arugal
    # Blackfathom Deeps
    12876: (221, 0.470, 0.470),   # Baron Aquanis
    # The Stockade
    1666: (225, 0.300, 0.200),    # Kam Deepfury
    1720: (225, 0.780, 0.450),    # Bruegal Ironknuckle
    # Gnomeregan
    6231: (226, 0.620, 0.350),    # Techbot
    6228: (226, 0.470, 0.860),    # Dark Iron Ambassador
    # Razorfen Kraul
    4438: (301, 0.450, 0.450),    # Razorfen Spearhide
    4842: (301, 0.120, 0.400),    # Earthcaller Halmgar
    # Scarlet Monastery
    3983: (302, 0.720, 0.590),    # Interrogator Vishas
    4543: (302, 0.240, 0.560),    # Bloodmage Thalnos
    6490: (302, 0.400, 0.620),    # Azshir the Sleepless
    6488: (302, 0.340, 0.440),    # Fallen Champion
    6489: (302, 0.380, 0.520),    # Ironspine
    3974: (303, 0.290, 0.840),    # Houndmaster Loksey
    6487: (303, 0.830, 0.740),    # Arcanist Doan
    3975: (304, 0.780, 0.110),    # Herod
    4542: (305, 0.490, 0.160),    # High Inquisitor Fairbanks
    3976: (305, 0.490, 0.270),    # Scarlet Commander Mograine
    3977: (305, 0.550, 0.240),    # High Inquisitor Whitemane
    # Razorfen Downs
    7354: (300, 0.720, 0.200),    # Ragglesnout
    7356: (300, 0.400, 0.720),    # Plaguemaw the Rotting
    # Maraudon
    13738: (280, 0.660, 0.720),   # Veng
    13739: (280, 0.250, 0.220),   # Maraudos
    12237: (280, 0.600, 0.620),   # Meshlok the Harvester
    # Zul'Farrak
    10080: (219, 0.550, 0.550),   # Sandarr Dunereaver
    10081: (219, 0.450, 0.600),   # Dustwraith
    7274: (219, 0.470, 0.230),    # Sandfury Executioner
    7604: (219, 0.440, 0.350),    # Sergeant Bly
    10082: (219, 0.550, 0.450),   # Zerillis
    # The Temple of Atal'Hakkar
    5716: (220, 0.400, 0.300),    # Balcony Minibosses
    8580: (220, 0.500, 0.450),    # Atal'alarion
    5708: (220, 0.220, 0.350),    # Spawn of Hakkar
    5711: (220, 0.740, 0.400),    # Ogom the Wretched
    5721: (220, 0.450, 0.850),    # Dreamscythe
    5720: (220, 0.470, 0.880),    # Weaver
    5722: (220, 0.550, 0.870),    # Hazzas
    5719: (220, 0.570, 0.840),    # Morphaz
    # Blackrock Depths
    9027: (243, 0.500, 0.870),    # Gorosh the Dervish
    9028: (243, 0.520, 0.860),    # Grizzle
    9029: (243, 0.540, 0.870),    # Eviscerator
    9030: (243, 0.500, 0.890),    # Ok'thor the Breaker
    9031: (243, 0.520, 0.900),    # Anub'shiah
    9032: (243, 0.540, 0.890),    # Hedrum the Creeper
    9438: (243, 0.620, 0.660),    # Dark Coffer
    9042: (243, 0.610, 0.640),    # Verek
    9476: (243, 0.630, 0.680),    # Watchman Doomgrip
    9537: (243, 0.460, 0.550),    # Guzzler
    8923: (242, 0.580, 0.350),    # Panzor the Invincible
    9034: (243, 0.540, 0.220),    # Chest of The Seven
    8929: (243, 0.900, 0.120),    # Princess Moira Bronzebeard
    # Lower Blackrock Spire
    10263: (250, 0.450, 0.400),   # Burning Felguard
    9219: (252, 0.450, 0.620),    # Spirestone Butcher
    9218: (252, 0.550, 0.550),    # Spirestone Battle Lord
    9217: (252, 0.400, 0.550),    # Spirestone Lord Magus
    9596: (252, 0.400, 0.570),    # Bannok Grimaxe
    10376: (251, 0.600, 0.730),   # Crystal Fang
    9718: (250, 0.480, 0.350),    # Ghok Bashguud
    # Upper Blackrock Spire
    10509: (254, 0.460, 0.300),   # Jed Runewatcher
    10899: (255, 0.400, 0.400),   # Goraluk Anvilcrack
    10339: (254, 0.486, 0.246),   # Gyth
    10429: (254, 0.486, 0.246),   # Warchief Rend Blackhand
    10430: (254, 0.642, 0.320),   # The Beast
    10363: (253, 0.350, 0.498),   # General Drakkisath
    # Dire Maul
    14354: (239, 0.450, 0.550),   # Pusillin
    14338: (235, 0.180, 0.620),   # Knot Thimblejack's Cache
    11467: (236, 0.250, 0.700),   # Tsu'zee
    # Scholomance
    14861: (307, 0.490, 0.200),   # Blood Steward of Kirtonos
    10506: (307, 0.490, 0.100),   # Kirtonos the Herald
    10503: (308, 0.540, 0.140),   # Jandice Barov
    11622: (308, 0.310, 0.640),   # Rattlegore
    14516: (306, 0.720, 0.520),   # Death Knight Darkreaver
    10433: (307, 0.600, 0.780),   # Marduk Blackpool
    10432: (307, 0.620, 0.720),   # Vectus
    10508: (309, 0.400, 0.810),   # Ras Frostwhisper
    10505: (308, 0.720, 0.700),   # Instructor Malicia
    11261: (308, 0.880, 0.450),   # Doctor Theolen Krastinov
    10901: (308, 0.720, 0.220),   # Lorekeeper Polkelt
    10507: (309, 0.670, 0.480),   # The Ravenian
    10504: (309, 0.790, 0.300),   # Lord Alexei Barov
    10502: (309, 0.670, 0.150),   # Lady Illucia Barov
    1853: (308, 0.720, 0.420),    # Darkmaster Gandling
    # Stratholme
    10393: (317, 0.400, 0.250),   # Skul
    11082: (317, 0.700, 0.450),   # Stratholme Courier
    11120: (317, 0.220, 0.580),   # Crimson Hammersmith
    10809: (318, 0.550, 0.620),   # Stonespine
    11121: (318, 0.580, 0.380),   # Black Guard Swordsmith
}

HIDDEN = set()

# npcID des boss Forever absents de foreverNpcDB.lua (QuestieDB), par nom anglais. Source : warcraft.wiki.gg,
# recoupé avec wowhead.com/forever/npc=ID (relevé le 2026-11-03).
MANUAL_NPCS = {
    "Faldrim Anvilmar": 261306, "Magmatus": 261316, "Plunder": 261311, "Durgen Dirgehammer": 261319,
    "Saltspine": 260322, "Shadetooth": 260325, "Highland Horror": 260808, "Relic Guardian": 260326,
    "Atrexis the Grave Knight": 247126, "Lyn the Ignored": 247032, "Arcane Anomaly": 245999,
    "Arcanic Enigma": 246016, "Unstable Sentinel": 246017, "Mana Devourer": 246008, "Fel Ancient": 246003,
    "Shade of the Archmage": 246020,
}

# Noms localisés des boss Forever absents de Questie, relevés sur nether.wowhead.com/forever/tooltip/npc/ID?locale=N.
# Complètent une langue sans traduction (ou traduite à l'identique de l'anglais) ; zhTW et itIT non traduits sur wowhead.
MANUAL_BOSS_NAMES = {
    261306: {"frFR": "Faldrim Courbenclume", "esES": "Faldrim Yunquemar", "ptBR": "Faldrim Sidermar", "ruRU": "Фалдрим Старая Наковальня", "koKR": "팔드림 앤빌마", "zhCN": "法德林·安威玛尔"},  # Faldrim Anvilmar
    261316: {"ruRU": "Магматий", "koKR": "마그마투스", "zhCN": "玛格马图斯"},  # Magmatus
    261311: {"deDE": "Schleppweg", "esES": "Pillaje", "ptBR": "Pilhar", "ruRU": "Крад", "koKR": "약탈골렘", "zhCN": "劫掠者"},  # Plunder
    261319: {"frFR": "Durgen Mornemartel", "esES": "Durgen Martillo Funesto", "ptBR": "Durgen Martelúgubre", "ruRU": "Дурген Горемолот", "koKR": "드루겐 더지해머", "zhCN": "杜根·挽锤"},  # Durgen Dirgehammer
    250483: {"frFR": "Croc-Flétri", "deDE": "Welkzahn", "esES": "Colmimarchito", "ptBR": "Sugapresa", "ruRU": "Сухожвал", "koKR": "쇠퇴송곳니", "zhCN": "枯牙"},  # Witherfang
    250631: {"frFR": "L'Abandonné", "deDE": "Der Verlassene", "esES": "El Abandonado", "ptBR": "O Abandonado", "ruRU": "Покинутый", "koKR": "버려진 자", "zhCN": "被遗弃者"},  # The Abandoned
    250660: {"frFR": "Le baron", "deDE": "Der Baron", "esES": "El barón", "ptBR": "O Barão", "ruRU": "Барон", "koKR": "남작", "zhCN": "男爵"},  # The Baron
    250657: {"ruRU": "Рат'маэль", "koKR": "라스마엘", "zhCN": "拉斯玛尔"},  # Rath'mael
    255699: {"frFR": "Capitaine de Lordaeron", "deDE": "Hauptmann von Lordaeron", "esES": "Capitán de Lordaeron", "ptBR": "Capitão de Lordaeron", "ruRU": "Лордеронский капитан"},  # Lordaeron Captain
    256035: {"frFR": "Viktor le Vil", "deDE": "Viktor der Üble", "esES": "Viktor el Abyecto", "ptBR": "Viktor, o Vil", "ruRU": "Виктор Вероломный", "koKR": "비열한 빅토르", "zhCN": "邪恶的维克多"},  # Viktor the Vile
    256097: {"ruRU": "Бьорк", "koKR": "비요크", "zhCN": "比约克"},  # Bjork
    260322: {"frFR": "Seléchine", "deDE": "Salzrücken", "esES": "Espinasal", "ptBR": "Salespino", "ruRU": "Солеспин", "zhCN": "盐脊"},  # Saltspine
    260325: {"frFR": "Dent-Sombre", "deDE": "Schemenzahn", "esES": "Sombradiente", "ptBR": "Caninumbra", "ruRU": "Тенезуб", "zhCN": "暗齿"},  # Shadetooth
    260808: {"frFR": "Horreur des hautes-terres", "deDE": "Hochlandschrecken", "esES": "Horror de las Tierras Altas", "ptBR": "Horror do Planalto", "ruRU": "Ужас нагорья"},  # Highland Horror
    260326: {"frFR": "Gardien des reliques", "deDE": "Reliktwächter", "esES": "Guardián de reliquias", "ruRU": "Страж реликвий", "zhCN": "遗迹守卫者"},  # Relic Guardian
    247126: {"frFR": "Atrexis le Chevalier de la tombe", "deDE": "Atrexis der Grabritter", "esES": "Atrexis el Caballero de la Tumba", "ptBR": "Atrexis, o Cavaleiro da Sepultura", "ruRU": "Атрексий Могильный Рыцарь", "koKR": "무덤 기사 아트렉시스"},  # Atrexis the Grave Knight
    247032: {"frFR": "Lyn l'Ignoré", "deDE": "Lyn der Ignorierte", "esES": "Lyn el Ignorado", "ptBR": "Lyn, o Ignorado", "ruRU": "Лин Забытый"},  # Lyn the Ignored
    245999: {"frFR": "Anomalie arcanique", "deDE": "Arkananomalie", "esES": "Anomalía Arcana", "ruRU": "Волшебная аномалия"},  # Arcane Anomaly
    246016: {"deDE": "Arkanes Mysterium", "esES": "Enigma Arcano"},  # Arcanic Enigma
    246017: {"frFR": "Sentinelle instable", "deDE": "Instabile Schildwache", "esES": "Centinela inestable", "ruRU": "Нестабильный часовой"},  # Unstable Sentinel
    246008: {"frFR": "Dévoreur de mana", "deDE": "Manaschlinger", "esES": "Devorador de maná", "ruRU": "Пожиратель маны"},  # Mana Devourer
    246003: {"frFR": "Ancien gangrené", "deDE": "Teufelsurtum", "esES": "Anciano vil", "ruRU": "Древень Скверны"},  # Fel Ancient
    246020: {"frFR": "Ombre de l'archimage", "deDE": "Schemen des Erzmagiers", "esES": "Sombra del archimago", "ruRU": "Тень верховного мага"},  # Shade of the Archmage
}

# Donneurs de quête absents de foreverNpcDB.lua (Questie les cite dans startedBy) : npcID -> nom anglais (wowhead forever).
MANUAL_NPC_NAMES = {
    269127: "Image of Archmage Modera",  # 92457, 92458, 96984
}

# Listes annexes d'AtlasLoot (sans PNJ) : noms localisés repris d'AtlasLootClassic*/Locales/constants.*.lua (GPL-2).
ANNEX_NAMES = {
    "Trash": {"frFR": "Ennemis communs", "esES": "Bichos", "ptBR": "Lixo", "ruRU": "Треш", "koKR": "일반몹", "zhCN": "小怪", "zhTW": "小怪"},
    "Books": {"frFR": "Livres", "deDE": "Bücher", "esES": "Libros", "ruRU": "Книги", "koKR": "도서", "zhCN": "书籍", "zhTW": "書籍"},
    "Plans": {"deDE": "Pläne", "esES": "Diseños", "ptBR": "Instruções", "ruRU": "Чертежи", "koKR": "도면", "zhCN": "计划", "zhTW": "計劃"},
    "Tribute": {"deDE": "Tribut", "esES": "Tributo a Gordok", "ptBR": "Homenagem a Gordok", "ruRU": "Приношения Гордока", "koKR": "공물", "zhCN": "戈多克贡品", "zhTW": "戈多克貢品"},
}
