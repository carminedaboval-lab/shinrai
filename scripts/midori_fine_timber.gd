extends RefCounted
## Shared scoped timber sampling; source maps/import settings stay unchanged.
const PATH := "res://assets/shinrai/streets/midori_frontage_construction/"
static var _grain: ImageTexture
static var _legacy_mean := Color.BLACK
static var _legacy_ready := false

static func grain() -> ImageTexture:
	if _grain != null: return _grain
	var source := load(PATH+"fine_grained_wood_col_2k.jpg") as Texture2D
	var image := source.get_image()
	if image.is_compressed(): image.decompress()
	image.generate_mipmaps()
	_grain = ImageTexture.create_from_image(image)
	_grain.resource_name = "MidoriFineTimber_LocalMipPyramid"
	return _grain

static func legacy_tint(brightness: float, chroma: float) -> Color:
	# Preserve the established joinery's average colour, rather than inventing
	# a new palette while replacing its oversized walnut texture structure.
	if not _legacy_ready:
		var source := load(PATH+"smoked_walnut_veneer_diff_2k.jpg") as Texture2D
		var image := source.get_image()
		if image.is_compressed(): image.decompress()
		image.resize(1,1,Image.INTERPOLATE_LANCZOS)
		_legacy_mean = image.get_pixel(0,0).srgb_to_linear()
		_legacy_ready = true
	var luma := _legacy_mean.r*.2126+_legacy_mean.g*.7152+_legacy_mean.b*.0722
	var finish := Color(luma,luma,luma).lerp(_legacy_mean,chroma)*brightness
	finish.a = 1.0
	return finish.linear_to_srgb()
