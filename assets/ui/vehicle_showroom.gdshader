shader_type canvas_item;
render_mode unshaded;

uniform sampler2D paint_mask : filter_linear, repeat_disable;
uniform sampler2D glass_mask : filter_linear, repeat_disable;
uniform int finish = 0;
uniform float tint_strength = 0.0;
uniform int quality = 2;
uniform float light_phase = 0.0;
uniform bool floor_reflection = false;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 lit = source.rgb;
	ivec2 pixels = textureSize(TEXTURE, 0);
	float aspect = float(pixels.x) / float(max(pixels.y, 1));
	// Body, glass and livery share the authored full-car UVs. Wheel cutouts,
	// shadows and the architectural background retain their own lighting.
	if (aspect > 2.7 && aspect < 2.85 && pixels.x >= 500) {
		float paint = texture(paint_mask, UV).a;
		float glass = texture(glass_mask, UV).a;
		// The replacement PNG contains its own windows. Restrict tint to
		// dark neutral pixels in the upper cabin instead of the old tint layer.
		float chroma = max(source.r, max(source.g, source.b)) - min(source.r, min(source.g, source.b));
		float neutral_dark = 1.0 - smoothstep(0.055, 0.20, chroma);
		float dark = 1.0 - smoothstep(0.14, 0.43, dot(source.rgb, vec3(0.2126,0.7152,0.0722)));
		float window_region = smoothstep(0.13,0.23,UV.y) * (1.0-smoothstep(0.46,0.59,UV.y));
		window_region *= smoothstep(0.13,0.21,UV.x) * (1.0-smoothstep(0.83,0.91,UV.x));
		float glass_eligible = neutral_dark * dark * window_region * source.a;
		float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
		float upper_fill = 1.0 - smoothstep(0.35, 0.90, UV.y);
		float sill_shadow = smoothstep(0.69, 0.91, UV.y);
		vec3 illumination = vec3(0.95, 0.94, 0.92) + upper_fill * vec3(0.09, 0.075, 0.05);
		illumination -= sill_shadow * 0.10;
		lit = mix(lit, source.rgb * illumination, paint);
		if (quality > 0) {
			// The original shading bends the broad light banks over each panel.
			float panel = UV.y + (luminance - 0.5) * 0.10 + (UV.x - 0.5) * 0.025;
			float broad = exp(-pow((panel - 0.57 - light_phase) / 0.13, 2.0));
			float ribbon = exp(-pow((panel - 0.45 - light_phase) / 0.025, 2.0));
			float specular = (finish == 1) ? broad * 0.014 : broad * 0.035 + ribbon * 0.065;
			if (finish == 2) {
				specular = broad * 0.055 + ribbon * 0.04;
				if (quality > 1) {
					float fleck = sin(UV.x * 2101.0 + UV.y * 1351.0) * sin(UV.x * 733.0 - UV.y * 1537.0);
					lit *= 1.0 + fleck * broad * 0.009 * paint;
				}
			}
			// Color the reflected light with the paint, preserving its saturation.
			vec3 reflected = mix(source.rgb, vec3(1.0, 0.94, 0.83), 0.28);
			lit += reflected * specular * paint;
			float glazing = exp(-pow((UV.y + UV.x * 0.06 - 0.34 - light_phase) / 0.065, 2.0));
			lit = mix(lit, source.rgb * vec3(0.94, 0.97, 1.02) + vec3(0.15, 0.18, 0.20) * glazing, glass * (1.0-tint_strength));
		}
		lit = mix(lit, lit * vec3(0.23,0.28,0.34), glass_eligible * tint_strength * 0.88);
	}
	COLOR = vec4(clamp(lit, vec3(0.0), vec3(1.0)), source.a) * vertex_tint;
	if (floor_reflection) {
		COLOR.a *= smoothstep(0.18, 0.97, UV.y);
	}
}
