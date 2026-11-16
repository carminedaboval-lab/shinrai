extends RefCounted

# Eligibility snapshot only; no font, bake, house or Dress dependencies.
# Captured before installation from map1_house_dress.gd:71,1150-1155.
# This hash records provenance, not a runtime assertion after installation.
const SOURCE_DRESS_PATH := "res://scripts/map1/map1_house_dress.gd"
const SOURCE_DRESS_SHA256 := "4cfe33a57f8a6777920485f158213fb5e337fda98774589cc816215f97efa475"
const SURNAMES: Array[String] = [
	"田中", "佐藤", "山田", "高橋", "渡辺", "山本", "中村",
	"小林", "加藤", "吉田", "松本", "井上", "清水", "石川",
]
const STONES: Array[Color] = [
	Color(0.86, 0.84, 0.79), Color(0.20, 0.20, 0.21), Color(0.74, 0.70, 0.62),
]

static func metadata_for(surname: String, stone: Color) -> Dictionary:
	var index := SURNAMES.find(surname)
	var palette := STONES.find(stone)
	if index < 0 or palette < 0:
		return {}
	return {"_nameplate": {
		"face": "-z",
		"ticks": Rect2i((index % 7) * 36, floori(float(index) / 7.0) * 72, 36, 72),
		"palette": palette,
	}}
