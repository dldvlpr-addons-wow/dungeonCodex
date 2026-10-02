-- Généré par tools/generate_data.py : ne pas éditer à la main.
local _, NS = ...
NS.Tactics = NS.Tactics or {}
local T = NS.Tactics
T[1] = { { "Curses and Diseases", "Being able to remove a curse or cure a disease helps. Otherwise an easy fight: clear the room before engaging." } }
T[2] = { { "The Summoner", "Kill the summoner first: he brings in reinforcements. Then the elemental." }, { "Fire Everywhere", "Area damage on the group, worse when the group fights a lot in melee." } }
T[3] = { { "Sent Across the Room", "He sends players flying across the room. Clear the nearest groups and tank him near the tunnel, so nobody lands in another group." } }
T[4] = { { "Fear When Weakened", "As his health drops, he terrifies the whole group. Bring something to break it, or clear the room beforehand so nobody runs into other enemies." }, { "The Locked Vaults", "After the fight, open the vaults in the room: about 24 Dwarven Heirlooms for Important Heirlooms, and the tablet for The Treaty of Understanding." } }
T[5] = { { "Fire Nova", "Fire damage to everyone near him, several times per fight. Healers, keep the melee topped up." }, { "Uppercut", "A heavy blow that knocks the tank back." } }
T[6] = { { "Immolate", "Burns a player, then Fire damage every few seconds for 21 seconds. Interrupt the spell or dispel the burn." }, { "Curse of Weakness", "Reduces a player's physical damage for 30 seconds. A mage or druid can remove it." } }
T[7] = { { "Cleave", "Hits his target and the player nearest to it." } }
T[8] = { { "Poison", "His hits poison: Nature damage over time. Cure the poison if you can." }, { "Sinister Strike", "Extra damage on the tank every 5 to 15 seconds." } }
T[9] = { { "The Courtyard Spiders", "Nothing special on the boss himself. Clear the other spiders in the courtyard first, or they join the fight." } }
T[10] = { note = "Clear the courtyard, click the statue and hold on through the waves: she arrives afterward.", { "Frost Nova", "Frost damage on the whole group. If you heal, save mana for all the waves." } }
T[11] = { { "Thrown Into the Air", "Throws the tank into the air and stuns them for 5 seconds. Watch your threat as damage dealer: the tank only holds him for about half the fight." }, { "A Patrol", "Clear his room before engaging: a patrol passes through. His head can be picked up for the quests Abominable Creatures and Unending Torment." } }
T[12] = { { "Flame Shock", "His main spell. It can be interrupted and stunned: coordinate interrupts and stuns with the group." }, { "Lots of Health", "The longest fight in the dungeon. Keep interrupting until the end." } }
T[13] = { note = "Clear the house and the statue, click the fireplace and hold on through the waves. He arrives after the last flesh golem.", { "Poison", "Poisons his target. Watch the health bars." }, { "Mighty Blows", "He hits hard: keep the tank alive. Bring mana potions for the waves before him." } }
T[14] = { { "Knockback", "He knocks back: clear the groups around him first, or you land in one of them." }, { "Anti-Magic Shield", "Protects himself against spells for a while." }, { "Mighty Blows", "He hits hard: keep the tank topped up." } }
T[15] = { { "Lightning Bolt", "He keeps his distance to cast it. Interrupt him." }, { "Healing Touch", "Heals himself or an ally (3-second cast). Interrupt him." }, { "Cobrahn's Serpent Form", "At 30% health, he turns into a snake: slower but heavier hits, and he starts putting players to sleep." } }
T[16] = { { "Healing Touch", "Heals herself or an ally. Interrupt her." }, { "Sleep", "Puts a player to sleep for up to 20 seconds. Damage wakes them, and a Dispel Magic removes it." }, { "Thorns", "Nature damage to anyone who hits her in melee." } }
T[17] = { { "Shell Shield", "For 12 seconds, he takes 60% less damage and attacks slower but harder." } }
T[18] = { { "Thunderclap", "Nature damage to everyone near him, then attacks and movement slowed for 10 seconds." }, { "Healing Touch", "Heals himself or an ally. Interrupt him." }, { "Sleep", "Puts a player to sleep for up to 20 seconds." } }
T[19] = { { "Chained Bolt", "A bolt that bounces to a second player. Interrupt him." } }
T[20] = { { "Healing Touch", "A slow heal (3.5 seconds) on himself or an ally. Interrupt him." }, { "Sleep", "Puts a player to sleep for up to 20 seconds." }, { "Lightning Bolt", "He keeps his distance to cast it. Interrupt him." } }
T[21] = { { "Grasping Vines", "When his target is close, he knocks down and roots everyone near him for 10 seconds. At range, keep your distance." } }
T[22] = { note = "Kill Lady Anacondra, Lord Cobrahn, Lord Pythas and Lord Serpentis, then talk to the Disciple of Naralex at the entrance and escort him to Naralex. Protect him during the ritual: Mutanus arrives at the end.", { "Thunderclap", "Nature damage to everyone near him and a 2.5-second stun." }, { "Naralex's Nightmare", "Puts a player to sleep for up to 15 seconds." }, { "Terrify", "Makes a player flee in fear for 4 seconds." } }
T[23] = { { "Rhahk'Zor Slam", "Hits the tank hard and stuns them for 3 seconds." } }
T[24] = { { "Pierce Armor", "Reduces the tank's armor by 75% for 20 seconds." }, { "Runs for Help", "At 15% health, he runs off to get help. Finish him before he gets away." } }
T[25] = { note = "He pilots Sneed's Shredder and climbs out when it is destroyed.", { "Disarm", "Disarms the tank for 6 seconds." } }
T[26] = { { "Terrify", "Makes a player flee in fear for 4 seconds." }, { "Overwhelming Pain", "Slows a player's casting by 35% for 15 seconds." } }
T[27] = { { "Molten Metal", "Fire damage every 3 seconds for 15 seconds, with attacks and movement slowed. Interrupt the 2-second cast." } }
T[28] = { { "Smite Slam", "At 66% then 33% health, he stuns everyone around him, then goes to his chest to swap weapons." }, { "Thrash", "With his two axes, from 66% health: extra attacks on the tank." }, { "Smite's Mighty Blow", "With his hammer, below 33% health: a heavy blow that stuns the tank for 3 seconds." } }
T[29] = { { "Poisoned Harpoon", "A 2-second cast: a hit, then Nature damage for one minute. Cure the poison." }, { "Cleave", "Hits his target and the player nearest to it." } }
T[30] = { { "Thrash", "Now and then, two extra attacks: heavy hits on the tank." }, { "VanCleef's Allies", "At half health, he calls two Defias Blackguards." } }
T[31] = { { "Acid Splash", "Nature damage every 5 seconds for 30 seconds to everyone near him." }, { "Cookie's Cooking", "Below half health, he heals himself (2-second cast). Interrupt him." }, { "Runs for Help", "At 15% health, he runs off to get help. Finish him before he gets away." } }
T[32] = { { "Soul Drain", "Roots a player for 10 seconds and drains their health to heal himself. Interrupt the 2-second cast or dispel it." } }
T[33] = { { "Crooked Blow", "The Fel Steed stuns everyone near it for 3 seconds, and they take more physical damage. The Shadow Charger has no special abilities." } }
T[34] = { { "Butcher Drain", "Drains 350 mana from his target in melee: a tank with mana will feel it." } }
T[35] = { { "Veil of Shadow", "Curses a player: healing they receive is reduced by 75% for 15 seconds. Remove it, especially on the tank." } }
T[36] = { { "Holy Light", "Heals himself or an ally (2.5-second cast). Interrupt him." }, { "Divine Shield", "Makes him immune to all damage and spells for 10 seconds." }, { "Hammer of Justice", "Stuns a player for 4 seconds." } }
T[37] = { { "Call for Help", "When you engage him, he calls creatures within 30 yards. Clear around him first." }, { "Howling Rage", "At 60%, 40% and 20% health, his hits get stronger." } }
T[38] = { { "Cleave", "Hits his target and the player nearest to it." }, { "Hamstring", "Slows his target's movement for 10 seconds." } }
T[39] = { note = "They arrive as a group of four after Fenrus the Devourer dies: Arugal appears briefly and summons them.", { "Dark Offering", "Heals another Voidwalker. Kill them one at a time." } }
T[40] = { { "Toxic Saliva", "Nature damage every 6 seconds and drained mana, for 2 minutes. Cure the poison." } }
T[41] = { { "Worg Reinforcements", "The longer the fight lasts, the more worgs he has with him: a Bleak Worg after 30 to 45 seconds, then a Slavering Worg, then a Lupine Horror." } }
T[42] = { { "Void Bolt", "A 3-second Shadow bolt on the tank, over and over. Interrupt him." }, { "Arugal's Curse", "Turns a player other than the tank into a Shadowfang Glutton that fights for him for 10 seconds. Remove the curse." }, { "Shadow Port", "He teleports between his ledge, the upper ledge and the stairs." }, { "Thunderclap", "When the tank reaches him: Nature damage and a 5-second stun around him." } }
T[43] = { { "Trample", "Hits everyone standing near him." } }
T[44] = { { "Forked Lightning", "Nature damage in a cone in front of her (2-second cast). Stay out of the cone." }, { "Frost Nova", "Freezes everyone near her in place for up to 8 seconds." }, { "Slow", "Slows a player's movement and attacks for 10 seconds." } }
T[45] = { { "Net", "Roots a player in place for 10 seconds." } }
T[46] = { note = "Click the Fathom Stone in the water: he rises from it.", { "Frostbolt", "He keeps his distance to cast it: Frost damage and a slow." }, { "Frost Nova", "Roots everyone near him for up to 8 seconds." } }
T[47] = { { "Sleep", "Puts everyone near him to sleep for up to 10 seconds. Damage wakes a sleeper." }, { "Mind Blast", "Shadow damage on a player (1.5-second cast)." } }
T[48] = { note = "He waits in an underwater cave beneath Twilight Lord Kelris's temple, and many groups miss him. Swim under the temple to reach him." }
T[49] = { note = "Once Twilight Lord Kelris is dead, light the four Aku'Mai fires in his room, one after the other. Each one brings a wave of creatures. When they are all dead, Aku'Mai's door opens.", { "Poison Cloud", "Nature damage every 5 seconds for 45 seconds to everyone nearby." }, { "Frenzied Rage", "Below 30% health: bursts of attacks 75% faster, over and over." } }
T[50] = { { "Lightning Shield", "Lightning strikes anyone who touches him. A priest or shaman can remove it." }, { "Lightning Bolt", "He keeps his distance to cast it. Interrupt him." } }
T[51] = { { "Shield Bash", "Hits the tank and stuns them for 2 seconds." }, { "Runs for Help", "At 15% health, he runs off to get help. Finish him before he gets away." } }
T[52] = { { "Runs for Help", "At 15% health, he runs off to get help. Finish him before he gets away." } }
T[53] = { { "Thrash", "Now and then, two extra attacks: heavy hits on the tank." }, { "Enrage", "At 30% health, he attacks 30% faster until the end of the fight." } }
T[54] = { { "Chain Lightning", "A bolt that bounces from player to player (2-second cast). Interrupt him." }, { "Bloodlust", "Speeds up his attacks or an ally's by 30% for 30 seconds. A priest or shaman can remove it." } }
T[55] = { { "Smoke Bomb", "Stuns everyone near him for 4 seconds." }, { "Battle Shout", "More attack power for him and his allies for 2 minutes." }, { "Runs for Help", "At 15% health, he runs off to get help. Finish him before he gets away." } }
T[56] = { { "Net", "Roots everyone near him for 10 seconds." }, { "Slow", "Slows a player's attacks and movement for 10 seconds, and can stun them." }, { "Summon Mechanical Roach", "Calls mechanical roaches. His Update kills them and heals him." } }
T[57] = { note = "Talk to Blastmaster Emi Shortfuse and protect her while she blows up the two cave entrances. Troggs come in waves, then Grubbis arrives with Chomper." }
T[58] = { { "Megavolt", "Nature damage in a cone in front of him (2-second cast). Only the tank stands in front." }, { "Chain Lightning", "A bolt that bounces between nearby players (2.5-second cast). Interrupt him." } }
T[59] = { { "Crowd Pummel", "Hits everyone near him and interrupts their spells. Casters and healers, keep your distance." }, { "Arcing Smash", "Hits everyone in a cone in front of him." }, { "Trample", "Hits everyone standing near him." } }
T[60] = { { "Summon Fiery Servant", "Calls two fiery servants at the start of the fight." }, { "Fireball", "He keeps his distance to cast it. Interrupt him." }, { "Fire Shield II", "Fire damage to everyone near him for one minute. A priest or shaman can remove it." } }
T[61] = { { "Walking Bombs", "He lights the gnome heads around the room one by one, and each one drops walking bombs that explode when they reach a player. The button next to a head turns it off. Below half health, he lights them faster." }, { "Knock Away", "Knocks the tank back. Below half health, it hits everyone around him." } }
