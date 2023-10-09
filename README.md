# Ghosts++

**Requires MLHook** -- you must also have MLHook installed.

## Features

- A better scrubber experience -- stutterless pausing, slowmo playback, cam control, and more.
- Save others' ghosts and load them later (even if their record improves).
- See ghost inputs without hiding PB ghost.
- Integration with in-game records UI.
- Load AT / CM medal ghosts.
- More features planned.

## Bugs

Please report unexpected game crashes if you suspect G++ might be involved.

Note: if you need to unload a ghost and can't do it through the records UI, open the main window (under current ghosts) and unload it there.

# Manual

## Scrubber

Main Toolbar:

* Open/close main window
* Exit replay / return to race
* Restart ghosts
* Skip back / step back
* Main scrubber (right click to play/pause)
* Skip fwd / step fwd
* Playback speed control (right click to cycle backwards)
* Play / pause
* Toggle advanced options

Advanced:

* Cycle camera types: player cam, cinematic cam, and free cam (note: might need to press a camera change input to get free cam to respond properly)
* Cycle player camera overrides: none, cam1, cam2, cam3
* Set ghost offset: set an offset for when ghosts start their run -- can be used to 'skip ahead' in a ghost run if the run is long. **Warning:** it seems you cannot go backwards with offsets, so you can skip ahead, but then the beginning of the run is lost and you need to reload the map. This is an area of research and contributions are welcome.

## Main Window

Current Ghosts:

* Lists currently visible ghosts
* Spectate any ghost (does not restart run)
* Save a ghost for later (note: technically saves the current record of that user, but precise ghost saving is possible too)
* Unload a ghost

Load Ghosts

* Find the ghost of a favorited player
* Load the ghost of a player (that you've loaded the ghost of before), or favorite them
* Load ghosts you've saved in the past (for that map)
* Load ghosts for medals: CM, AT, Gold, Silver, Bronze
* Load ghosts from the the leaderboard
* Load a ghost from a URL


License: Public Domain

Authors: XertroV

Suggestions/feedback: @XertroV on Openplanet discord

Code/issues: [https://github.com/XertroV/tm-ghosts-plus-plus](https://github.com/XertroV/tm-ghosts-plus-plus)

GL HF

---------

todo:
- ~~ free cam / cinematic
- ~~ scrubber everywhere
- searcher for particular record times / ghosts
- ~~ favorites
- ~~ GHOST INPUTS
- g_PBTab.Draw();
- g_NearTimeTab.Draw();
- g_AroundRankTab.Draw();
- g_IntervalsTab.Draw();
- ~~ (didnt work) ghost clips offset in MT? for skipping ahead when > pg time
- ?? more speed options
- ~~ leaderboard
- DB compaction (for favs particularly)
- name filters async
- force / customize char skins + helmet color (possible?)
- ~~ load ghost from URL
- force remove skidmarks from vehicles?

------------

campaign medal times in scoreboard:
- `declare netwrite K_Net_GhostData[] Net_TMGame_ScoresTable_GhostsData_V3 for Teams[0];`
- `declare netwrite Text[Text] Net_TMGame_ScoresTable_CustomRanks for Teams[0];`
