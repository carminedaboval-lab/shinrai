extends CanvasLayer
signal retry_requested
const ART := "res://assets/shinrai/ui/loading/midori_plaza.jpg"
var shield: Control
var content: Control
var stage_label: Label
var detail_label: Label
var retry_button: Button
var resource_progress := -1.0
var elapsed := 0.0
var active := false
var rendered_frames := 0
var stage_events: Array[Dictionary]=[]

class Indicator extends Control:
	var owner_ui: CanvasLayer
	func _draw() -> void:
		var width:=size.x
		draw_line(Vector2.ZERO,Vector2(width,0),Color("#496362"),2)
		if owner_ui.resource_progress>=0.0:
			draw_line(Vector2.ZERO,Vector2(width*owner_ui.resource_progress,0),Color("#a1ded5"),3)
		else:
			var travel: float=fposmod(owner_ui.elapsed*.26,1.2)-.2
			draw_line(Vector2(maxf(0,travel)*width,0),Vector2(minf(1,travel+.2)*width,0),Color("#a1ded5"),3)
var indicator: Indicator
func _ready() -> void:
	name="ShinraiLoadingScreen";layer=1000;add_to_group("shinrai_loading_ui")
	shield=Control.new();shield.name="InputShield";shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shield.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shield)
	var picture:=TextureRect.new();picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(ART): picture.texture=load(ART)
	shield.add_child(picture)
	var veil:=ColorRect.new();veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new();shader.code="shader_type canvas_item; void fragment(){ float left = 1.0-smoothstep(0.0,0.8,UV.x); float bottom = smoothstep(0.45,1.0,UV.y); COLOR=vec4(0.018,0.034,0.04,clamp(0.18+left*0.64+bottom*0.40,0.0,0.88)); }"
	var material:=ShaderMaterial.new();material.shader=shader;veil.material=material;shield.add_child(veil)
	content=Control.new();content.mouse_filter=Control.MOUSE_FILTER_IGNORE;shield.add_child(content)
	_label("FIELD OPERATIONS  /  01",Vector2(150,106),22,Color("#a1ded5"))
	_label("SHINRAI",Vector2(144,278),100,Color("#f3eee2"))
	_label("THE QUIET EXIT",Vector2(152,398),28,Color("#e9dfbc"))
	_label("MIDORI PARK",Vector2(151,462),20,Color("#b5c6c4"))
	stage_label=_label("Preparing the park",Vector2(152,845),24,Color("#f3eee2"))
	detail_label=_label("",Vector2(152,895),17,Color("#b5c6c4"))
	indicator=Indicator.new();indicator.owner_ui=self;indicator.position=Vector2(154,884);indicator.size=Vector2(680,8);indicator.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(indicator)
	_label("SHINRAI  /  EXTRACTION",Vector2(151,996),16,Color("#9dafae"))
	retry_button=Button.new();retry_button.text="Retry";retry_button.position=Vector2(152,940);retry_button.size=Vector2(180,42);retry_button.pressed.connect(func()->void:retry_requested.emit());content.add_child(retry_button);retry_button.hide()
	get_viewport().size_changed.connect(_fit);_fit();hide();set_process(false)
func _label(text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var item:=Label.new();item.text=text;item.position=at;item.mouse_filter=Control.MOUSE_FILTER_IGNORE;item.add_theme_font_size_override("font_size",font_size);item.add_theme_color_override("font_color",color);content.add_child(item);return item
func _fit() -> void:
	var actual:=get_viewport().get_visible_rect().size
	var factor:=minf(actual.x/1920.0,actual.y/1080.0)
	content.scale=Vector2.ONE*factor;content.position=(actual-Vector2(1920,1080)*factor)*.5
func begin(text: String) -> void:
	active=true;elapsed=0;resource_progress=-1;retry_button.hide();detail_label.text="";set_stage(text);show();set_process(true)
func set_stage(text: String, progress: float=-1.0) -> void:
	if stage_label==null: return
	if stage_label.text!=text: stage_events.append({"stage":text,"engine_ms":Time.get_ticks_msec()})
	stage_label.text=text;resource_progress=progress
	detail_label.text="Resources  /  %d%%" % roundi(progress*100.0) if progress>=0 else ""
func finish() -> void:
	active=false;hide();set_process(false);shield.release_focus()
func fail(message: String) -> void:
	set_stage("Unable to load the park");detail_label.text=message;retry_button.show();retry_button.grab_focus()
func _process(delta: float) -> void:
	elapsed+=delta;rendered_frames+=1;indicator.queue_redraw()
