return function(size: number)
	assert(size > 0 and size <= 5 * 1024 * 1024, "image must be 5 MB or smaller")
end
