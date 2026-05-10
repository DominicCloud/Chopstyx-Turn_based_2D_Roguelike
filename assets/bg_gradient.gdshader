shader_type canvas_item;

void fragment() {
	// Vertical gradient: dark indigo at top to near-black at bottom
	vec3 top_color = vec3(0.08, 0.06, 0.18);
	vec3 bottom_color = vec3(0.02, 0.02, 0.04);
	vec3 grad = mix(top_color, bottom_color, UV.y);

	// Subtle procedural noise for depth
	float noise = fract(sin(dot(UV * 800.0, vec2(12.9898, 78.233))) * 43758.5453);
	grad += (noise - 0.5) * 0.015;

	COLOR = vec4(grad, 1.0);
}
