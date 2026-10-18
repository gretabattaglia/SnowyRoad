shader_type canvas_item;
render_mode unshaded;
// Luci e ombre sui nemici: la fiamma illumina il bordo che la guarda (rim light caldo),
// il lato opposto prende il controluce freddo della nebbia, gli occhi brillano.

uniform vec2 light_px = vec2(0.0);            // posizione della fiamma, in pixel della texture
uniform float light_radius = 900.0;           // raggio d'azione della luce, in pixel della texture
uniform vec3 light_col : source_color = vec3(1.0, 0.58, 0.27);
uniform float light_energy = 1.0;
uniform float band = 18.0;                    // spessore del bordo luminoso (pixel texture)
uniform vec3 back_col : source_color = vec3(0.50, 0.65, 0.82);
uniform float eye_glow = 0.0;                 // 0..1: occhi piu' accesi (quando sparano)
uniform vec3 eye_col : source_color = vec3(0.65, 0.85, 1.0);
uniform float flash = 0.0;                    // lampo bianco quando viene colpito
uniform float fade_bottom = 0.35;             // la parte bassa sfuma nella nebbia

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 ts = TEXTURE_PIXEL_SIZE;
	vec2 px = UV / ts;

	// stima del bordo: quanto "vuoto" c'e' intorno al pixel e da che parte
	float open_amt = 0.0;
	vec2 g = vec2(0.0);
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 0.5235988;
		vec2 d = vec2(cos(a), sin(a));
		float o1 = 1.0 - texture(TEXTURE, UV + d * band * ts).a;
		float o2 = 1.0 - texture(TEXTURE, UV + d * band * 0.45 * ts).a;
		float o = 0.5 * (o1 + o2);
		open_amt += o;
		g += d * o;
	}
	open_amt /= 12.0;
	vec2 n = g / max(length(g), 1e-4);          // normale verso l'esterno

	vec2 L = light_px - px;
	float dist = length(L);
	vec2 ld = L / max(dist, 1e-3);
	float att = clamp(1.0 - dist / light_radius, 0.0, 1.0);
	att = att * att * light_energy;

	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float eyeness = smoothstep(0.34, 0.5, lum) * step(0.5, c.a);   // occhi chiari o arancioni
	float body = 1.0 - eyeness;

	float edge = smoothstep(0.03, 0.30, open_amt);
	float facing = clamp(dot(n, ld), 0.0, 1.0);

	vec3 col = c.rgb;
	// riflesso caldo morbido sul corpo
	col += light_col * att * 0.20 * (0.35 + lum * 2.0) * body;
	// rim light della fiamma
	col = mix(col, light_col * 1.25, clamp(edge * pow(facing, 0.8) * att * 2.4, 0.0, 0.95) * body);
	// controluce freddo sul lato alto-sinistra
	float up = clamp(dot(n, vec2(-0.45, -0.85)), 0.0, 1.0);
	col = mix(col, back_col, edge * up * 0.5 * body);
	// occhi
	col = mix(col, col * 1.1 + eye_col * 0.25, eyeness * eye_glow);
	// ombra/nebbia in basso e lampo di danno
	float fade = 1.0 - fade_bottom * smoothstep(0.82, 1.0, UV.y);
	col = mix(col, vec3(1.0), flash * 0.6);
	COLOR = vec4(col, c.a * fade);
}
