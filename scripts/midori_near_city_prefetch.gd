extends RefCounted
## Textures the near city and its hand-made buildings load while they are being built
## (2.3 s of first-time loads on the main thread, measured standalone). A worker loads
## them at the start of the build so those load() calls find them cached. This is a
## speed hint only: a path missing here is still loaded where it is used, as before,
## and a stale path is skipped. Regenerate the list by building the near city alone and
## listing the textures ResourceLoader.has_cached() reports afterwards that it did not
## before (the city's own wall textures first, as they are needed first).
## Measured against an unbuilt project, 2026-11-08.

const PATHS: Array[String] = [
	"res://assets/shinrai/near_city/textures/rectangular_facade_tiles_diff.jpg",
	"res://assets/shinrai/near_city/textures/concrete_tile_facade_diff.jpg",
	"res://assets/shinrai/near_city/textures/exterior_wall_cladding_diff.jpg",
	"res://assets/shinrai/near_city/textures/precast_concrete_wall_diff.jpg",
	"res://assets/shinrai/near_city/textures/corrugated_iron_02_diff.jpg",
	"res://assets/shinrai/near_city/textures/painted_metal_shutter_diff.jpg",
	"res://assets/shinrai/near_city/textures/long_white_tiles_diff.jpg",
	"res://assets/shinrai/near_city/textures/white_stucco_diff.jpg",
	"res://assets/shinrai/near_city/textures/square_tiled_wall_diff.jpg",
	"res://assets/shinrai/near_city/textures/rectangular_facade_tiles_nor.jpg",
	"res://assets/shinrai/near_city/textures/concrete_tile_facade_nor.jpg",
	"res://assets/shinrai/near_city/textures/exterior_wall_cladding_nor.jpg",
	"res://assets/shinrai/near_city/textures/precast_concrete_wall_nor.jpg",
	"res://assets/shinrai/near_city/textures/corrugated_iron_02_nor.jpg",
	"res://assets/shinrai/near_city/textures/painted_metal_shutter_nor.jpg",
	"res://assets/shinrai/near_city/textures/long_white_tiles_nor.jpg",
	"res://assets/shinrai/near_city/textures/white_stucco_nor.jpg",
	"res://assets/shinrai/near_city/textures/square_tiled_wall_nor.jpg",
	"res://assets/shinrai/drain_hgu150/ProjectShinrai_HGU150_Drain_GameReady_SHINRAI_PrecastPaver_BaseColor_1K.png",
	"res://assets/environment/roads/shinrai_road/textures/SHINRAI_Road_FineAggregate_BaseColor_2K.png",
	"res://assets/environment/roads/shinrai_road/textures/SHINRAI_Road_RealisticDry_NormalGL_2K.png",
	"res://assets/environment/roads/shinrai_road/textures/SHINRAI_Road_RealisticDry_ORM_2K.png",
	"res://assets/shinrai/near_city/textures/japanese_cedar_planks_diff.jpg",
	"res://assets/shinrai/near_city/textures/japanese_cedar_planks_nor.jpg",
	"res://assets/shinrai/near_city/textures/japanese_cedar_planks_rough.jpg",
	"res://assets/shinrai/near_city/textures/plastered_wall_03_diff.jpg",
	"res://assets/shinrai/near_city/textures/plastered_wall_03_nor.jpg",
	"res://assets/shinrai/near_city/textures/plastered_wall_03_rough.jpg",
	"res://assets/shinrai/near_city/textures/rusty_corrugated_iron_diff.jpg",
	"res://assets/shinrai/near_city/textures/rusty_corrugated_iron_nor.jpg",
	"res://assets/shinrai/near_city/textures/rusty_corrugated_iron_rough.jpg",
	"res://assets/shinrai/near_city/textures/rusty_painted_metal_diff.jpg",
	"res://assets/shinrai/near_city/textures/rusty_painted_metal_nor.jpg",
	"res://assets/shinrai/near_city/textures/rusty_painted_metal_rough.jpg",
	"res://assets/shinrai/near_city/textures/worn_corrugated_iron_diff.jpg",
	"res://assets/shinrai/near_city/textures/worn_corrugated_iron_nor.jpg",
	"res://assets/shinrai/near_city/textures/worn_corrugated_iron_rough.jpg",
	"res://assets/shinrai/near_city/arcade_art.png",
	"res://assets/shinrai/near_city/arcade_atlas.png",
	"res://assets/shinrai/near_city/barber_atlas.png",
	"res://assets/shinrai/near_city/books_atlas.png",
	"res://assets/shinrai/near_city/capsule_atlas.png",
	"res://assets/shinrai/near_city/clinic_atlas.png",
	"res://assets/shinrai/near_city/crane_atlas.png",
	"res://assets/shinrai/near_city/cycle_atlas.png",
	"res://assets/shinrai/near_city/drugstore_atlas.png",
	"res://assets/shinrai/near_city/floors_atlas.png",
	"res://assets/shinrai/near_city/floors_photo.png",
	"res://assets/shinrai/near_city/flower_atlas.png",
	"res://assets/shinrai/near_city/fudosan_atlas.png",
	"res://assets/shinrai/near_city/gyoza_atlas.png",
	"res://assets/shinrai/near_city/hotel_atlas.png",
	"res://assets/shinrai/near_city/karaoke_atlas.png",
	"res://assets/shinrai/near_city/koban_atlas.png",
	"res://assets/shinrai/near_city/konbini_atlas.png",
	"res://assets/shinrai/near_city/lane_atlas.png",
	"res://assets/shinrai/near_city/laundry_atlas.png",
	"res://assets/shinrai/near_city/pachinko_atlas.png",
	"res://assets/shinrai/near_city/pencil_atlas.png",
	"res://assets/shinrai/near_city/ramen_atlas.png",
	"res://assets/shinrai/near_city/screen_frames.png",
	"res://assets/shinrai/near_city/sento_atlas.png",
	"res://assets/shinrai/near_city/snack_atlas.png",
	"res://assets/shinrai/near_city/viaduct_atlas.png",
	"res://assets/shinrai/near_city/vr_wall.png",
	"res://assets/shinrai/near_city/wagashi_atlas.png",
	"res://assets/shinrai/near_city/yaoya_atlas.png",
	"res://assets/shinrai/near_city/zakkyo_atlas.png",
	"res://assets/shinrai/near_city/zakkyo_floors.png",
	"res://assets/shinrai/near_city/textures/arcade_boards.jpg",
	"res://assets/shinrai/near_city/textures/arcade_carpet.jpg",
	"res://assets/shinrai/near_city/textures/arcade_carpet_line.png",
	"res://assets/shinrai/near_city/textures/arcade_enamel.png",
	"res://assets/shinrai/near_city/textures/arcade_lattice.png",
	"res://assets/shinrai/near_city/textures/arcade_mosaic.jpg",
	"res://assets/shinrai/near_city/textures/arcade_terrazzo.jpg",
	"res://assets/shinrai/near_city/textures/arcade_tile.jpg",
	"res://assets/shinrai/streets/interior_paintings/mori_morning.png",
	"res://assets/shinrai/streets/midori_frontage_construction/mori_bentwood_chair_smoked_walnut_veneer_diff_2k.jpg",
	"res://assets/shinrai/streets/midori_frontage_construction/mori_bentwood_chair_smoked_walnut_veneer_rough_2k.png",
]

## Worker: loads each path not yet cached, keeping the resources in out (so they stay
## cached until the city lets go of out) until stop[0] is set.
static func run(out: Array, stop: Array) -> void:
	for path: String in PATHS:
		if stop[0]: return
		if ResourceLoader.has_cached(path) or not ResourceLoader.exists(path): continue
		var resource := ResourceLoader.load(path)
		if resource != null: out.append(resource)
