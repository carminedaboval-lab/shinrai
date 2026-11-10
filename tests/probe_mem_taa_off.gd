extends "res://tests/probe_shader_warmup.gd"

# Investigation probe: the same park boot as probe_shader_warmup.gd, with temporal anti-aliasing
# (TAA) switched off on the main view, to measure what its motion-vector pipelines cost in memory.
#   godot --path . --script res://tests/probe_mem_taa_off.gd -- --no-warm --no-latch --label=taa_off

func _initialize() -> void:
	root.use_taa = false
	super()
