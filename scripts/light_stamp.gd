extends Object
class_name LightStamp
## Light-map stamp for the mist preview. Boosted falloff gives

static func stamp(img: Image, c: Vector2i, r: float, w: int, h: int) -> void:
	if r < 0.5:
		return
	var ri := int(ceil(r))
	for dz in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var x := c.x + dx
			var z := c.y + dz
			if x < 0 or x >= w or z < 0 or z >= h:
				continue
			var d := Vector2(dx, dz).length()
			if d > r:
				continue
			var v := clampf((1.0 - d / r) * 1.45, 0.0, 1.0)
			if v > img.get_pixel(x, z).r:
				img.set_pixel(x, z, Color(v, 0, 0))
