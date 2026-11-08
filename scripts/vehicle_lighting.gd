class_name VehicleLighting
extends RefCounted

const SHADER := preload("res://assets/ui/vehicle_showroom.gdshader")

static func apply(canvas: Node2D,model: String,look: Dictionary,quality: int,phase: float) -> void:
	var material := canvas.material as ShaderMaterial
	if material==null or material.shader!=SHADER:
		material=ShaderMaterial.new()
		material.shader=SHADER
		canvas.material=material
	var layers: Dictionary=VehicleAppearance.definition(model).layers
	material.set_shader_parameter("paint_mask",VehicleAppearance.texture(layers.paint_mask))
	material.set_shader_parameter("photoreal_body",int(VehicleAppearance.definition(model).get("art_pipeline_version",0))>=2)
	material.set_shader_parameter("glass_mask",VehicleAppearance.texture(layers.glass))
	material.set_shader_parameter("finish",int(look.finish))
	var is_replacement: bool=int(VehicleAppearance.definition(model).get("art_pipeline_version",0))>=2
	material.set_shader_parameter("tint_strength",VehicleAppearance.TINT_OPACITY[clampi(int(look.get("tint",0)),0,VehicleAppearance.TINT_OPACITY.size()-1)] if is_replacement else 0.0)
	material.set_shader_parameter("quality",quality)
	material.set_shader_parameter("light_phase",phase)
	material.set_shader_parameter("floor_reflection",canvas.scale.y<0)
