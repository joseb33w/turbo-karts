class_name TKTex
extends RefCounted
## Runtime-generated textures (no binary assets, so the export .pck stays tiny). Each is
## built once into an ImageTexture with mipmaps when an arena loads. These replace the flat
## single-colour materials that made the old build look "robotic": real asphalt with painted
## lane lines, varied grass / sand, rippling water, and lit office windows.

static func _fnl(seed: int, freq: float, octaves := 3) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.seed = seed
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


static func _finish(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Asphalt with baked lane markings. UVs on the road mesh put u across the width (0=left,
## 1=right) and tile v along the length, so the edge lines and dashed centre line stay put.
static func road(tint := Color(1, 1, 1)) -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var n := _fnl(11, 0.05, 4)
	var n2 := _fnl(7, 0.35, 2)
	var asph := Color(0.205, 0.215, 0.245)
	for y in size:
		var fy := float(y) / size
		for x in size:
			var fx := float(x) / size
			var g: float = n.get_noise_2d(x, y) * 0.5 + 0.5
			var col := asph * (0.78 + g * 0.30)
			if n2.get_noise_2d(x, y) > 0.66:
				col = col.lightened(0.14)
			if (fx > 0.030 and fx < 0.060) or (fx > 0.940 and fx < 0.970):
				col = Color(0.86, 0.87, 0.84)
			elif fx > 0.476 and fx < 0.524 and fy < 0.5:
				col = Color(0.93, 0.83, 0.30)
			col *= tint
			img.set_pixel(x, y, col)
	return _finish(img)


static func grass(base: Color) -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var n := _fnl(21, 0.04, 4)
	var n2 := _fnl(5, 0.22, 2)
	var blade := _fnl(91, 0.9, 1)
	for y in size:
		for x in size:
			var g: float = n.get_noise_2d(x, y) * 0.5 + 0.5
			var b: float = n2.get_noise_2d(x, y) * 0.5 + 0.5
			var col := base.lerp(base.darkened(0.28), g)
			col = col.lerp(base.lightened(0.16), b * 0.45)
			if blade.get_noise_2d(x, y) > 0.5:
				col = col.lightened(0.06)
			img.set_pixel(x, y, col)
	return _finish(img)


static func sand(base: Color) -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var n := _fnl(44, 0.05, 3)
	for y in size:
		for x in size:
			var warp: float = n.get_noise_2d(x, y)
			var rip := 0.5 + 0.5 * sin(float(x) * 0.16 + warp * 5.0)
			var col := base * (0.82 + rip * 0.22)
			img.set_pixel(x, y, col)
	return _finish(img)


static func water(base: Color) -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var n := _fnl(70, 0.03, 4)
	var n2 := _fnl(80, 0.08, 2)
	for y in size:
		for x in size:
			var w: float = n.get_noise_2d(x, y) * 0.5 + 0.5
			var sparkle: float = n2.get_noise_2d(x, y)
			var col := base.lerp(base.lightened(0.30), w)
			if sparkle > 0.72:
				col = col.lightened(0.45)
			img.set_pixel(x, y, col)
	return _finish(img)


## Emission map for night buildings: a grid of windows, some lit in neon, most dark.
static func windows(palette: Array) -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var cell := 16
	var pad := 3
	var cols: int = size / cell
	for gy in cols:
		for gx in cols:
			if rng.randf() < 0.5:
				continue
			var c: Color = palette[rng.randi() % palette.size()]
			c = c * rng.randf_range(0.5, 1.0)
			for yy in range(pad, cell - pad):
				for xx in range(pad, cell - pad):
					img.set_pixel(gx * cell + xx, gy * cell + yy, c)
	return _finish(img)
