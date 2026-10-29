extends RefCounted
## Scene-local broad phase only. Final predicates match the park exactly.
const CELL := 4.0
const INDEX_SLACK := 0.001
var _contour: Array[Vector2] = []
var _polygon := PackedVector2Array()
var _lake_buffer := 0.0
var _tiers: Array[Dictionary] = []

func configure(contour: Array[Vector2], lake_buffer: float, routes: Array[Dictionary], corridors: Array) -> void:
	_contour=contour.duplicate()
	_polygon=PackedVector2Array(contour)
	_lake_buffer=lake_buffer
	_tiers.clear()
	for padding_limit:float in [1.0,4.0]:
		var tier:Dictionary={"lake":{},"bridge":{},"path":{}}
		for i in contour.size():
			_index(tier.lake,contour[i],contour[(i+1)%contour.size()],0.0,maxf(padding_limit,lake_buffer))
		for corridor:Array in corridors:
			for i in range(corridor.size()-1):_index(tier.bridge,corridor[i],corridor[i+1],2.2,2.2+padding_limit)
		for spec:Dictionary in routes:
			var points:Array[Vector2]=spec.points
			for i in range(points.size()-1):_index(tier.path,points[i],points[i+1],float(spec.half_width),float(spec.half_width)+padding_limit)
		_tiers.append(tier)

func matches_contour(contour: Array[Vector2]) -> bool:
	# Detect same-size in-place edits too; no collision-prone hash-only invalidation.
	return _contour==contour

func blocked(point: Vector2,padding:float) -> bool:
	assert(point.is_finite() and is_finite(padding) and padding>=0.0 and padding<=4.0)
	var tier:Dictionary=_tiers[0 if padding<=1.0 else 1]
	var key:=Vector2i(floori(point.x/CELL),floori(point.y/CELL))
	if Geometry2D.is_point_in_polygon(point,_polygon):return true
	for segment:Array in tier.lake.get(key,[]):
		if _distance_to_segment(point,segment[0],segment[1])<maxf(padding,_lake_buffer):return true
	for segment:Array in tier.bridge.get(key,[]):
		if _distance_to_segment(point,segment[0],segment[1])<2.2+padding:return true
	for segment:Array in tier.path.get(key,[]):
		if _distance_to_segment(point,segment[0],segment[1])<float(segment[2])+padding:return true
	return false

func _index(cells:Dictionary,a:Vector2,b:Vector2,width:float,reach:float) -> void:
	# The extra millimetre is only for candidate selection, never the final rule.
	var lower:=a.min(b)-Vector2.ONE*(reach+INDEX_SLACK)
	var upper:=a.max(b)+Vector2.ONE*(reach+INDEX_SLACK)
	var segment:Array=[a,b,width]
	for y in range(floori(lower.y/CELL),floori(upper.y/CELL)+1):
		for x in range(floori(lower.x/CELL),floori(upper.x/CELL)+1):
			var key:=Vector2i(x,y)
			if not cells.has(key):cells[key]=[]
			cells[key].append(segment)

func _distance_to_segment(point:Vector2,a:Vector2,b:Vector2) -> float:
	var segment:=b-a
	var length_squared:=segment.length_squared()
	if length_squared<=0.0001:return point.distance_to(a)
	var t:=clampf((point-a).dot(segment)/length_squared,0.0,1.0)
	return point.distance_to(a+segment*t)
