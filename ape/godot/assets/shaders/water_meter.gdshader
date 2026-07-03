shader_type canvas_item;

uniform float wave_speed = 3.0;
uniform float wave_freq = 1.2;
uniform float wave_height = 2.0;

void vertex() {
	float edge = smoothstep(4.0, 0.0, VERTEX.y);
	VERTEX.y += sin(VERTEX.x * wave_freq + TIME * wave_speed) * wave_height * edge;
}

void fragment() {
	float shimmer = 0.85 + 0.15 * sin(UV.x * 30.0 + TIME * 2.5);
	COLOR.rgb *= shimmer;
}
