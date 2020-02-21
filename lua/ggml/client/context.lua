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

CONTEXT.FindElementByID = CONTEXT.FindElementById
CONTEXT.GetElementById = CONTEXT.FindElementById
CONTEXT.GetElementByID = CONTEXT.FindElementByID

function CONTEXT:AddChangeListener(k, f)
	k = string.Replace(k, "/", ".")
	local valid = setupMeta(self, k)
	if valid then
		if not self.changeListeners[k] then
			self.changeListeners[k] = {}
		end
		table.insert(self.changeListeners[k], f)
		return true
	else
		return false
	end
end

function CONTEXT:MakeGetter(k, f)
	k = string.Replace(k, "/", ".")
	local valid = setupMeta(self, k)
	if valid and not self.mtGetters[k] then
		self.mtGetters[k] = f
		return true
	else
		return false, valid and "Cannot bind a property to multiple fields" or "Invalid index"
	end
end

local function setupMeta(self, k)
	local val, poses = helper.index(self, k)
	if poses then
		local tab = poses[#poses]

		if not tab._GGMLHasListener then
			if #poses > 1 then
				local sLast = string.match(k, "^.+%.(.+)%.[^%.]+$") or string.match(k, "^(.+)%.[^%.]+$") -- yikes lol
				poses[#poses-1][sLast] = helper.getProxy(poses[#poses])
				poses[#poses] = poses[#poses-1][sLast]
				tab = poses[#poses]
			end
			local preLast = string.match(k, "^.+%.") or ""

			tab._GGMLHasListener = true

			local mt = debug.getmetatable(tab) or {}
	        local this = self
	        local mtCopy = table.Copy(mt)
	        local oldNewIndex = mt.__newindex or rawset
	        mtCopy.__newindex = function(t, k, v)
	            oldNewIndex(t, k, v)
	            if this.changeListeners and this.changeListeners[preLast .. k] then
	                for i, f in pairs(this.changeListeners[preLast .. k]) do
	                    f(v)
	                end
	            end
	        end
	        local oldIndex = mt.__index or rawget
	        mtCopy.__index = function(t, k)
	        	if this.mtGetters and this.mtGetters[preLast .. k] then
	        		return this.mtGetters[preLast .. k](t)
	        	else
	        		return oldIndex(t, k)
	        	end
	       	end
	        debug.setmetatable(tab, mtCopy) -- Debug cuz "tab" is a userdata, and setmetatable no like userdata
	    end
	    return true
	else
		return false
	end
end