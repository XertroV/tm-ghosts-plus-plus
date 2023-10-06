# Ghost Picker

**Requires MLHook** -- you must also have MLHook installed.

Pick any ghost (or ghosts) from the leaderboards to race against in solo.

- Ghosts around your PB.
- Ghosts around a specific rank.
- Ghosts a bit faster than your PB.
- Ghosts that are 500ms, 1000ms, 1500ms, ... faster than your PB (ghosts that are at regular intervals).

License: Public Domain

Authors: XertroV

Suggestions/feedback: @XertroV on Openplanet discord

Code/issues: [https://github.com/XertroV/tm-ghost-picker](https://github.com/XertroV/tm-ghost-picker)

GL HF



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




------------

campaign medal times in scoreboard:
- `declare netwrite K_Net_GhostData[] Net_TMGame_ScoresTable_GhostsData_V3 for Teams[0];`
- `declare netwrite Text[Text] Net_TMGame_ScoresTable_CustomRanks for Teams[0];`
