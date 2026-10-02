"""Données saisies à la main pour generate_data.py.

FLOORS    : étages (UiMapID retail) de chaque donjon, dans l'ordre d'affichage.
MINIMAP_FLOORS : étages faits de tuiles de minicarte du client, pour les donjons sans carte d'étage.
WINGS     : aile d'une instance partagée (clé de locale, instanceID si AtlasLoot ne le donne pas).
ALIASES   : noms du journal retail pour un boss nommé autrement dans AtlasLoot.
POSITIONS : npcID -> (UiMapID, x, y) quand le journal retail n'a pas le boss ; placé à vue sur la carte.
HIDDEN    : npcID écartés du journal.
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
}

# Étages faits des tuiles de minicarte du client (512 px), pour les donjons sans carte d'étage.
# Clé : identifiant d'étage (l'instanceID).
#   tiles     : fileID des tuiles, ligne par ligne (WDT de la carte, chunk MAID, champ minimapTexture)
#   cols      : tuiles par ligne
#   scale     : taille d'une tuile, en multiple d'une tuile de carte retail
#   left, top : coin haut gauche de la vue, en tuiles depuis la première
#   pins      : (ax, bx, ay, by), du repère du site (posé sur une carte dessinée) à la vue : ax * x + bx, ay * y + by
MINIMAP_FLOORS = {
    2999: {   # WDT 7255103, tuiles 30-32 x 28-29
        "tiles": [7255730, 7255736, 7255742, 7255748, 7255754, 7255760],
        "cols": 3, "scale": 2.33, "left": 0.695, "top": 0.42, "pins": (1.108, -0.070, 1.098, -0.062),
    },
    3065: {   # WDT 7713294, tuiles 30-33 x 30-32
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
}

# Donjons Forever décrits seulement par le site : clé -> (page du site, instanceID de la DB2 Map du client).
SITE_DUNGEONS = {
    "HallOfThanes": ("hall-of-thanes", 3065),
}

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
