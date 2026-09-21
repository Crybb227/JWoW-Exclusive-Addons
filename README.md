# JWoW Exclusive Addons

Custom addons for the JasonWoW (WotLK 3.3.5a) private server, distributed through the
AAEmu Launcher's "JWoW Exclusives" tab.

| Addon | Description |
|---|---|
| [JasonWoWAdditions](JasonWoWAdditions) | Campaign progression front end for the server's `.progress` system. |
| [NemesisTracker](NemesisTracker) | Companion addon for `mod-nemesis-system`. |
| [DungeonClear](DungeonClear) | Autonomous dungeon-clearing companion for `mod-dungeon-clear`. |
| [Chatter](Chatter) | Companion UI for `mod-llm-chatter` bot traits and tone. |

Each addon is versioned independently via its `.toc` file. The launcher reads
[`exclusive-addons.json`](exclusive-addons.json) to know the current version and download
location for each one.
