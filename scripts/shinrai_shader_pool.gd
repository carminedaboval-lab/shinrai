extends RefCounted
## One Shader object per distinct shader text (memory fix 1, boot memory round).
##
## Every `Shader.new()` with its own code is a separate shader version on the
## renderer: its own compile and its own set of surface / specialization
## pipelines, even when the text is identical to a shader that already exists
## (the Vulkan driver keeps CPU-side memory per pipeline). Builders that made a
## Shader per lantern, per screen, per fern index or per call now ask the pool,
## so identical text is compiled once and all those materials share its
## pipelines. Materials are NOT pooled: each caller keeps its own ShaderMaterial
## with its own parameters, so nothing drawn changes.
##
## Use through preload (no class_name: works without an editor class-cache scan):
##   const ShaderPool := preload("res://scripts/shinrai_shader_pool.gd")
##   material.shader = ShaderPool.shader(CODE)          # instead of Shader.new() + .code =
##   var material := ShaderPool.material(CODE)          # a fresh ShaderMaterial on the pooled shader
##
## The key is the exact code string: two texts that differ only in whitespace
## are two shaders (the world fingerprint hashes each material's shader code, so
## the pool never changes which text a material carries). Pooled shaders live for
## the session (a few hundred small objects at most). Callers must not edit the
## code of a pooled shader; a variant is a new text, so ask the pool for it.

static var _shaders: Dictionary = {}   # code: String -> Shader
static var _lock := Mutex.new()
## Census counters: `misses` is the number of distinct texts compiled, `hits`
## the number of Shader objects the pool saved.
static var hits := 0
static var misses := 0


## The one Shader for this code text (created on first use).
static func shader(code: String) -> Shader:
	_lock.lock()
	var found: Variant = _shaders.get(code)
	if found is Shader:
		hits += 1
		_lock.unlock()
		return found
	var created := Shader.new()
	created.code = code
	_shaders[code] = created
	misses += 1
	_lock.unlock()
	return created


## A new ShaderMaterial on the pooled shader for this code text.
static func material(code: String) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = shader(code)
	return result


static func stats() -> Dictionary:
	_lock.lock()
	var out := {"distinct": _shaders.size(), "hits": hits, "misses": misses}
	_lock.unlock()
	return out
