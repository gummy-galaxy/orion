local geometry = require("@root/geometry")

return function(size: number)
	assert(size > 0 and size <= geometry.IMAGE_MAX_BYTES, "image must be 5 MB or smaller")
end
