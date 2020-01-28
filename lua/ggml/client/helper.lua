helper = {}

-- Pull out basic ops into functions
function helper.add(a, b)
	return a + b
end

function helper.sub(a, b)
	return a - b
end

function helper.mul(a, b)
	return a * b
end

function helper.div(a, b)
	return a / b
end

function helper.rep(x, n)
	if n <= 0 then return nil end
	if n == 1 then return x end
	return x, helper.rep(x, n - 1)
end

function helper.curry(f, ...)
	local args = { ... }
	return function( ... ) return f(unpack(args), ...) end
end

function helper.unCurry(f)
	return function(a, ...) return f(...) end
end

function table.map(tab, f)
	local out = {}
	for k, v in pairs(tab) do
		out[k] = f(v)
	end
	return out
end

-- Runs in O(n^2) unless last arg given, then O(n)
function table.reduce(tab, f, s, seq)
	local total = s

	if seq == nil then
		seq = table.IsSequential(tab) 
	end

	local p = seq and ipairs or pairs
	for k, v in p(tab) do
		total = f(total, v)
	end
	return total
end

function table.sum(tab)
	return table.reduce(tab, helper.add, 0)
end

function table.product(tab)
	return table.reduce(tab, helper.mul, 0)
end

function printA( ... )
	for k, v in ipairs({...}) do
		if istable(v) then
			PrintTable(v)
		else
			print(v)
		end
	end
end