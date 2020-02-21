GGML.FORCE_SET = "FORCE_SET"

GGML.ATTR_SETTERS = {
	All = {
		ID = function(self, val)
			self.id = val
		end
	},
	Label = {
		DoClick = GGML.FORCE_SET
	}
}

GGML.ATTR_GETTERS = {
	All = {
		ID = function(self)
			return self.id
		end
	}
}