NemesisTracker + TomTom + Affix UI, no target/hover inspect
=============================================================

THIS ZIP IS A DROP-IN UPDATE, NOT A STANDALONE ADDON.

1. Install the complete original addon first from:
   mod-nemesis-system/ClientAddon/NemesisTracker

2. Your client must have this path:
   World of Warcraft\Interface\AddOns\NemesisTracker\NemesisTracker.toc

3. Copy every file from this ZIP into that existing NemesisTracker folder.
   Replace files when Windows asks.

4. TomTom is optional, but required for Crazy Arrow waypoint integration.
   HandyNotes is optional, but required for the normal world-map overlay.

5. Completely restart WoW after changing addon files.

What this variant adds
----------------------
- TomTom waypoint button in /ntrack and /nt
- Double-click a Nemesis row to create a TomTom waypoint
- Right-click a tracker map marker to create a TomTom waypoint
- Clickable Nemesis coordinate links in chat when a cached/map location is known
- HandyNotes world-map markers with affix-effect tooltips
- Nemesis affix icons in the /ntrack detail panel
- Nemesis rank/affix badges above Blizzard nameplates using live affix-marker
  aura matches or explicitly enabled name fallback
- Interface > AddOns > NemesisTracker options for nameplate badges, badge
  tooltips, normal unit tooltip lines, live aura matching, name fallback,
  current-zone map defaults, and badge size
- Hover tooltips on affix icons
- Affix effect lines on /ntrack row and tracker map-marker tooltips
- Nemesis rank/affix lines on normal unit hover tooltips when the hovered unit
  has live affix-marker auras or explicitly enabled name fallback
- Static fallback effect descriptions for current upstream affixes
- Optional V2 affix metadata support so the server can provide its actual
  configured effect descriptions

Server compatibility
--------------------
This version is built for servers that advertise:

  bootstrap|report|rank5|affixmeta|affixaura|finallocation

It does NOT require:

  targetidentify
  hoverinspect

The addon does not send:

  .nemesis addon target <requestId>
  .nemesis addon inspect <requestId> <high> <entry> <counter>

Because those commands are not required, this version avoids command-usage chat
spam on servers that have affix metadata but do not have target/mouseover
inspection.

Important limitation
--------------------
Without targetidentify or hoverinspect, a 3.3.5a addon cannot ask the server to
identify arbitrary same-name units, and UnitGUID does not contain the server's
persistent creature spawn id. To avoid false affix/rank displays, this variant
only adds Nemesis lines to the normal WoW unit tooltip when the hovered unit has
live affix-marker auras, unless risky name fallback is explicitly enabled.

WotLK's vanilla nameplates do not expose a unit GUID to addons, so nameplate
badges use live marker auras from inspectable units when possible. Optional
fallback modes can use the freshest current-zone cached Nemesis record with the
visible mob name, but those modes can mark normal same-name mobs.

Affix effects are shown where the addon already has a trusted cached Nemesis
record from the server:

- /ntrack or /nt detail panel icons
- /ntrack or /nt nemesis row tooltips
- /ntrack or /nt tracker map marker tooltips
- HandyNotes world-map marker tooltips
- Normal unit hover tooltips for live server-configured affix aura matches or
  explicitly enabled name fallback

Affix metadata protocol
-----------------------
This client understands these backwards-compatible server messages:

  V2:AFFIX_CATALOG_BEGIN:<count>
  V2:AFFIX_META:<bit>:<name>:<shortDescription>:<longDescription>[:<auraSpell>]
  V2:AFFIX_CATALOG_END

When present, these server descriptions override the built-in fallback text.
The optional auraSpell field lets the addon identify target/mouseover affixes
from live UnitAura data instead of broad same-name matching.
