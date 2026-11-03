# Dungeon Codex

## 1.4

### New
- **Forever dungeons**: Excavation Site and City of Dalaran (beta data). Five announced dungeons without data
  (The Drowned City, Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold, The Shaper's Terrace) show as "Upcoming".
  Badges "Beta" and "Unconfirmed" mark the dungeons whose data is not verified.
- **Search all loot**: box at the top of the window, from 2 characters, ignores case and accents.
  Click opens the boss loot, right-click toggles the wishlist.
- **My class** in the loot type menu: only the armor and weapons the character can equip.
- **Waypoint** button on the dungeon page: sets a map waypoint on the dungeon entrance.
- **Quests**: items to bring and prerequisite quests (checked when done) under each quest.
- **Wishlist reminder** in the chat when entering a dungeon where a wished item drops.
- Item tooltips show wished items and the sources seen in game.
- Bosses missing from the data are recorded in 5-player dungeons (successful encounter, then loot from an unknown creature)
  and added to the dungeon. `tools/found_export.lua` exports them for the data generator.
- **Boss abilities** for 136 more bosses (Blackrock Depths, Blackrock Spire, Dire Maul, Maraudon, Razorfen Downs,
  Scholomance, Stratholme, Sunken Temple, The Stockade, Uldaman, Zul'Farrak), in every client language.
- `/codex resetkills` clears the boss checkmarks, `/codex clearwishlist` empties the wishlist.

### Changed
- Boss checkmarks clear on the instance reset system message.
- Only the open tab is refreshed.
- Boss abilities of Razorfen Kraul, Scarlet Monastery, Excavation Site and City of Dalaran translated in every client
  language (they showed in French).
- Quest giver zone shown in the client language.
- Quests without a giver show the item that starts them (or the giver known to Questie).
- Forever boss names in German, Spanish (Mexican too), Portuguese, Russian, Korean and Simplified Chinese clients (and more French ones).
- The wishlist reminder waits for the items to load instead of showing "item:ID".

## 1.3

### New
- **Wishlist button** at the top right of the window: every wished item with its dungeon, boss and drop chance.
  Click opens the boss loot, Shift-click links the item in chat, right-click removes it from the wishlist.
- `/codex wishlist` lists the wishlist in the chat.
- `/aeondungeonjournal` opens the window, like `/codex`.

### Fixed
- Ruins of Lordaeron and Hall of Thanes now have a thumbnail in the dungeon grid: the map of their first floor.
- The gold border on the dungeons that fit the character's level is visible again.

## 1.1

First release on CurseForge.

### New
- **Dungeon grid**: the 25 Classic 5-player dungeons, plus Ruins of Lordaeron and Hall of Thanes, with their
  Forever level range. A gold border marks the dungeons that fit the character's level.
- **Dungeon page**: bosses with portrait and level, and four tabs: map, loot, boss abilities, quests.
- **Floor maps** with a numbered pin per boss. Click a pin or a name to open the boss loot. Shift-drag moves a pin.
- **Loot**: drop chance, items new or changed in Forever, tooltip, Shift-click to link in chat.
  Filters by name, slot and type.
- **Wish list**: right-click a loot item. A star marks the item, its boss and its dungeon, and an alert
  shows when the item drops.
- **Item tooltips**: dungeon, boss and drop chance of the item. `/codex tooltip` hides them.
- **Boss abilities**: targeted role and advice, in the client language (English, French, German, Spanish,
  Italian, Portuguese, Russian, Korean, Simplified and Traditional Chinese). **Send to group** writes them in party chat.
- **Quests**: level, faction, quest giver and rewards. Completed quests are checked, quests in the log are marked.
- **Boss kills** of the current run are checked in the boss list and on the map.
- `/codex` opens the window on the current dungeon. `/codex help` lists the commands.
