local CONTEXT = {}

GGML.ContextBase = CONTEXT

function CONTEXT:FindElementById(id, root)
	if not self.inflated then return nil end
	root = root or self.xmlRoot
	if root.element.id == id then
		return root.element
	end
	for k, v in ipairs(root) do
		local find = self:FindElementById(id, v)
		if find ~= nil then return find end
	end
	return nil
end

function CONTEXT:AddChangeListener(k, f)
	if not self.changeListeners[k] then
		self.changeListeners[k] = {}
	end
	table.insert(self.changeListeners[k], f)
end

