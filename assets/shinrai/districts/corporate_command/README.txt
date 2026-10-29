SHINRAI CORPORATE COMMAND DISTRICT

Production derivative of the approved standalone corporate_cantilever_20261025
revision 5. Main-world assembly: scripts/midori_corporate_district.gd, referenced
by scenes/shinrai_extraction.tscn, loaded through the normal Shinrai bootstrap.

Placement is in world metres, origin (220,0,330), rotation zero, scale (1,1,1).
Tower is centred on that origin. Police is 83m west; garage is 83m east. The
district is southeast of Midori Park and east of the existing residential area.
The old shopping street continues east from its side junction at (35.5,186.5)
to (168.5,186.5), then south into the new district's western north-south road.

The original standalone geometry and editable Blender source remain in the
source package. UPSTREAM_PROVENANCE.json is the unchanged historical standalone
manifest, including original Meshy source records; its file references are
relative to that source package, and its standalone-only status describes that
historical revision. Production integration receipts live alongside the source
package in integration/installation.json and integration/REPORT.json.

Included: original tower visual shell, traversable floors, two full-height
stairs, eight-stop lift, rear emergency ladder, police public lobby, three-deck
corporate garage, twelve surrounding exteriors and district streets.
Vehicles are stationary props; upper police offices and surrounding buildings
remain exterior shells. NPC navigation and vehicle driving are not expanded.

Player interactions use the actual Shinrai player through shinrai_interactions.gd.
E calls/opens the lift panel or takes the ladder; W/S climb. Native pause,
inventory, player health, weapon, save and day/night systems remain authoritative.
