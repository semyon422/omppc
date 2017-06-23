table.print = function(self, i)
	if not i then i = 0 end
	for key, value in pairs(self) do
		io.write(string.rep("  ", i) .. tostring(key) .. ": ")
		if type(value) == "table" and key ~= "__index" then
			io.write("\n")
			table.print(value, i+1)
		else
			print(value)
		end
	end
end

string.trim = function(self)
	return self:match("^%s*(.-)%s*$")
end

string.split = function(self, separator)
   local separator, fields = separator or ":", {}
   local pattern = string.format("([^%s]+)", separator)
   self:gsub(pattern, function(c) fields[#fields + 1] = c end)
   
   return fields
end

string.startsWith = function(self, subString)
	return self:sub(1, #subString) == subString
end

string.endsWith = function(self, subString)
	return self:sub(#self - #subString + 1, -1) == subString
end

string.parse = function(self, startPos, endPos)
	local value = self:trim():sub(startPos or 1, endPos or -1)
	local numValue = tonumber(value)
	
	return numValue or value
end

table.export = function(object)
	local object = object or {}
	local out = {}
	table.insert(out, "{")
	for key, value in pairs(object) do
		local key = key
		if type(key) == "number" then
			key = "[" .. key .. "]"
		end
		if type(value) == "string" then
			table.insert(out, key .. " = " .. string.format("%q", value) .. ", ")
		elseif type(value) == "number" then
			table.insert(out, key .. " = " .. value .. ", ")
		end
	end
	table.insert(out, "}")
	
	return table.concat(out)
end

local search = function(key, parents)
	for i = 1, #parents do
		local value = parents[i][key]
		if value then return value end
	end
end
createClass = function(...)
	local class = {}
	local parents = {...}
	
	setmetatable(class, {
		__index = function(object, key)
			local value = search(key, parents)
			object[key] = value
			return value
		end
	})
	
	class.__index = class
	class.new = function(self, object)
		local object = object or {}
		setmetatable(object, class)
		
		return object
	end
	
	return class
end

belong = function(...)
	local args = {...}
	
	for i = 1, #args / 3 do
		local x, sx, ex = args[3*(i - 1) + 1], args[3*(i - 1) + 2], args[3*(i - 1) + 3]
		if x < sx or x > ex then
			return false
		end
	end
	
	return true
end




