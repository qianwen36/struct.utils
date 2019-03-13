local target = {}
local TAG = '************[struct.utils] '
local function log( ... )
	print(table.concat({TAG, ...}))
end
local function array( rest, ... )
	return {...}, rest
end

--------------------------------------------------------------------------
local endian = '<'
local packSize = {
	c = 1, b = 1,
	h = 2, H = 2,
	i = 4, I = 4,
	l = 4, L = 4,
	f = 4, d = 8,
}
local function sub( array, f, e )
	array = {unpack(array)}
	if f > 0 and f <= #array then
		if e and e > f then
			for i=e+1,#array do
				table.remove(array)
			end
		end
		for i=1,f-1 do
			table.remove(array, 1)
		end
	else
		array = {}
	end
	return array
end
local function product(array)
	local ret = 1
	for i=1,#array do
		ret = ret * array[i]
	end
	return ret
end
local function format_enc( defmt, index )
	local ret, fmt
	if type(defmt) == 'string' then
		fmt = defmt:gsub('A%d*', 'A')
		ret = fmt
	else
		fmt = {unpack(defmt)}
		for i=1,#fmt do
			fmt[i] = fmt[i]:gsub('A%d*', 'A')
		end
		index = index or 1
		ret = fmt[index]
	end
	return ret, fmt
end
local function format( desc, index, enc )
	local ty = type(index)
	enc = enc or (ty ~= 'number' and index)
	index = ty == 'number' and index or nil
	local ret = (not enc and desc.defmt) or desc.fmt

	if type(ret) == 'table' then
		index = index or 1
		ret = ret[index]
	end
	if enc and ret == nil then
		local defmt, fmt = desc.defmt
		if defmt then
			ret, desc.fmt = format_enc(defmt, index)
		end
	end

	if ret == nil then
		if desc.len then
			local a = {endian}
			for i=1, #desc do
				local fdes = desc[i]
				local ty = fdes[2]
				local dims = sub(fdes, 3)
				local c = product(dims)
				if type(ty) == 'table' then
					c = c*ty.len
				elseif c > 1 then
					c = c * packSize[ty]
				end
				if c > 1 then
					ty = 'A'..c
				end
				table.insert(a, ty)
			end
			desc.defmt = table.concat(a)
		else
			index = index or 1
			local field, ty = unpack(desc)
			local dims = sub(desc, 3)
			local c = #dims
			local rep = c > 1 and product(sub(dims, index+1)) or 1

			c = dims[index]
			if c then
				local fmt = desc.defmt
				desc.defmt = fmt or {}
				if type(ty) == 'table' then
					fmt = table.concat{endian, string.rep('A'..(ty.len*rep), c)}
				elseif rep > 1 then
					fmt = table.concat{endian, string.rep('A'..(packSize[ty]*rep), c)}
				else
					if ty == 'c' then
						fmt = table.concat{endian, 'A'..c}
					else
						fmt = table.concat{endian, ty, c}
					end
				end

				desc.defmt[index] = fmt
			else
				desc.defmt = endian..ty
			end
		end
		if enc then
			ret, desc.fmt = format_enc(desc.defmt, index)
		else
			local defmt = desc.defmt
			ret = index and defmt[index] or defmt
		end
	end
	return ret
end
local array_unpack
local array_pack
function array_pack( t, fdes, index )
	local ret
	local c = fdes[index+2]
	if c then
		local fmt = format(fdes, index, true)
		if index+2 < #fdes then
			-- ret  = {unpack(t)}
			ret = {}
			for i=1,c do
				ret[i] = array_pack(t[i], fdes, index+1)
			end
			ret = string.pack(fmt, unpack(ret))
		else
			local ty = fdes[2]
			if type(ty) == 'table' then
				ret = target.pack(t or {}, ty, c)
			else
				if ty == 'c' then
					t = t or ''
					ret = target.fill(t, c, 0)
				else
					t = t or {}
					t = target.fill(t, c, 0)
					ret = string.pack(fmt, unpack(t))
				end
			end
		end
	end
	return ret
end
function target.pack( t, desc, c )
	local ret
	if c then
		local list = {}
		for i=1,c do
			local value = t[i] or {}
			value = target.pack(value, desc)
			table.insert(list, value)
		end
		ret = table.concat(list)
	else
		local list = {}
		for i=1,#desc do
			local fdes = desc[i]
			local field, ty, c, c2 = unpack(fdes)
			local value = t[field]
			if c and c > 1 then
				-- value = array_pack(value, fdes, 1) -- Recursive for multi-dimension array
				if c2 then
					value = array_pack(value, fdes, 1)
				else
					value = value or (ty == 'c' and '' or {})
					if type(ty) == 'table' then
						value = target.pack(t, ty, c)
					elseif ty == 'c' then
						value = target.fill(value or '', c)
					else
						local fmt = format(fdes, 1, true)
						value = target.fill(value or {}, c, 0)
						value = string.pack(fmt, unpack(value))
					end
				end
			elseif type(ty) == 'table' then
				value = target.pack(value or {}, ty)
			end
			table.insert(list, value or 0)
		end
		local fmt = format(desc, true)
		ret = string.pack(fmt, unpack(list))
	end
	return ret
end

function target.packs( ... )
    local array = {...}
    for i=1,#array do
        array[i] = target.pack(unpack(array[i]))
    end
    return table.concat(array)
end

function array_unpack( data, fdes, index )
	local ret
	local c = fdes[index+2]
	if c and data then
		local fmt = format(fdes, index)
		if index+2 < #fdes then
			ret  = array(string.unpack(data, fmt))
			for i=1,c do
				ret[i] = array_unpack(ret[i], fdes, index+1)
			end
		else
			local ty = fdes[2]
			if type(ty) == 'table' then
				ret = array(string.unpack(data, fmt))
				for i=1,c do
					ret[i] = target.unpack(ret[i], ty)
				end
			elseif ty == 'c' then
				ret = data
			else
				ret = array(string.unpack(data, fmt))
			end
		end
	end
	return ret
end
function target.unpack( data, desc, c )
	if data == nil then return nil, 1 end

	local ret, rest = {}
	if c then
		local fmt = endian..string.rep('A'..desc.len, c)
		local value = array(string.unpack(data, fmt))
		for i=1,c do
			value[i] = target.unpack(value[i], ty)
		end
		ret = value
		rest = desc.len +1
	else
		local fmt, list = format(desc)
		list, rest = array(string.unpack(data, fmt))
		local last = #list
		if last < #desc then -- struct is truncated
			local index = last+1
			list[index] = data:sub(rest)
			last = index
			rest = data:len()+1
		end
		for i=1, last do
			local fdes, value = desc[i], list[i]
			local field, ty, c, c2 = unpack(fdes)
			if c then
				-- value = array_unpack(value, fdes, 1) -- Recursive for multi-dimension array
				if c2 then
					value = array_unpack(value, fdes, 1)
				else
					local fmt = format(fdes, 1)
					if type(ty) == 'table' then
						value = array(string.unpack(value, fmt))
						for i=1,c do
							value[i] = target.unpack(value[i], ty)
						end
					else
						if ty ~= 'c' then
							value = array(string.unpack(value, fmt))
						end
					end
				end
			elseif type(ty) == 'table' then
				value = target.unpack(value, ty)
			end
			ret[field] = value
		end
	end
	return ret, rest
end

function target.fill( t, c, ref )
	local ty = type(t)
	if ty == 'table' then
		ref = ref or 0
		for i=#t+1, c do
			table.insert(t, ref)
		end
	elseif ty == 'string' then
		t = string.sub(t, 1, c)
		c = c - string.len(t)
		if (c >0) then
			t = t..string.rep('\0', c)
		end
	end
	return t
end

local function struct_len( tdes )
	local len = tdes.len
	if len == nil then
		len = 0
		for i,fdes in ipairs(tdes) do
			local ty, size = fdes[2]
			if type(ty) == 'table' then
				size = struct_len(ty)
			else
				size = packSize[ty]
			end
			local dims = sub(fdes, 3)
			local rep = product(dims)
			len = len + size * rep
		end
		tdes.len = len
	end
	return len
end

local function reference_check( ty, refs )
	for i,ref in ipairs(refs) do
		ref = ref[ty]
		if ref then return ref end
	end
end
local function desc_dereference( tdes, refs )
	for i,fdes in ipairs(tdes) do
		local ty = fdes[2]
		if ty:len() > 1 then
			-- if no reference type, treat as int for enum
			ty  = reference_check(ty, refs) or 'i'
			fdes[2] = ty
		end
	end
end
function target.resolve( desc, ... )
	local list = {desc, ...}
	for ty, tdes in pairs(desc) do
		desc_dereference(tdes, list)
	end
	-- for ty, tdes in pairs(desc) do
	-- 	struct_len(tdes)
	-- end
	for i = 2, #list do -- merge reference description table
		for ty,tdes in pairs(list[i]) do
			desc[ty] = tdes
		end
	end
	return desc
end

return target