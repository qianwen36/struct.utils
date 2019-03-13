--[[
    luaide  模板位置位于 Template/FunTemplate/NewFileTemplate.lua 其中 Template 为配置路径 与luaide.luaTemplatesDir
    luaide.luaTemplatesDir 配置 https://www.showdoc.cc/web/#/luaide?page_id=713062580213505
    author:{author}
    time:2019-03-11 11:51:01
]]
local hfile = {'BaseGameStruct.h', 'MJGameStruct.h', 'MyGameStruct.h'}

local fmt = {
	['char']		= 'c',
	['signed char']	= 'c',
	['unsigned char'] = 'b',
	['short']		= 'h',
	['signed short']= 'h',
	['unsigned short'] = 'H',
	['long']		= 'l',
	['signed long']	= 'l',
	['unsigned long'] = 'L',
	['int']			= 'i',
	['signed int']	= 'i',
	['unsigned int']= 'I',
	['float']	= 'f',
	['double']	= 'd',

	['long long'] = 'd',
	BYTE = 'b',
	TCHAR= 'c',
	BOOL = 'i',
	DWORD = 'L',
}

local fmtDesc=[[
----------------------------------------
-- format string for string.pack/unpack
-- 'z'     /* zero-terminated string */
-- 'p'     /* string preceded by length byte */
-- 'P'     /* string preceded by length word */
-- 'a'     /* string preceded by length size_t */
-- 'A'     /* string */
-- 'f'     /* float */
-- 'd'     /* double */
-- 'n'     /* Lua number */
-- 'c'     /* char */
-- 'b'     /* byte = unsigned char */
-- 'h'     /* short */
-- 'H'     /* unsigned short */
-- 'i'     /* int */
-- 'I'     /* unsigned int */
-- 'l'     /* long */
-- 'L'     /* unsigned long */
-- '<'     /* little endian */
-- '>'     /* big endian */
-- '='     /* native endian */
----------------------------------------
]]
function io.readfile(path)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*a")
        io.close(file)
        return content
    end
    return nil
end
function io.writefile(path, content, mode)
    mode = mode or "w+b"
    local file = io.open(path, mode)
    if file then
        if file:write(content) == nil then return false end
        io.close(file)
        return true
    else
        return false
    end
end
local TAG = '************[struct.generate] '
local function log( ... )
	print(table.concat({TAG, ...}))
end

local predefines = {}
local packSize = {
	c = 1, b = 1,
	h = 2, H = 2,
	i = 4, I = 4,
	l = 4, L = 4,
	f = 4, d = 8,
}

local value_check
local arithmetic = {
	['+'] = function ( a, b ) return a + b end;
	['-'] = function ( a, b ) return a - b end;
	['*'] = function ( a, b ) return a * b end;
	['/'] = function ( a, b ) return a / b end;
	['%'] = function ( a, b ) return a % b end;
}
function value_check( var )
	local ret = tonumber(var) or predefines[var]
	if ret == nil then
		local op = var:match('[%+%-%*%%%/]')
		if op ~= nil then
			local a, b = var:match(table.concat({'([_%w]+)%s*%', op, '%s*(%w+.-)'}))
			a = value_check(a)
			b = value_check(b)
			if a ~= nil and b ~= nil then
				ret = arithmetic[op](a, b)
			end
		end
	end
	if ret == nil then log(var, ' can not resolve!') end
	return ret
end
local function rep( dims )
	local ret = 1
	for i=1,#dims do
		ret = ret * value_check(dims[i])
	end
	return ret
end

local function stringify(s)
	return table.concat{"'", s, "'"}
end
local function struct_fields( t, block )
	local len = 0
	for line in block:gmatch('\n%s*(%a+.-);') do
		local dims = {}
		line = line:gsub('(%b[])', function(s)
			table.insert(dims, s:match('%[(.-)%]'))
			return ''
		end)
		local field = line:match('%s*([_%w]+)$')
		local ty = line:sub(1, -field:len()-1):gsub('[ \t]+$', '')
		local fmt2 = fmt[ty]
		fmt2 = fmt2 or ty
		local desc = {stringify(field), stringify(fmt2)}
		for i=1,#dims do
			desc[2+i] = dims[i]
		end
		table.insert(t, table.concat{'\t{', table.concat(desc, ', '), '},'})
		local size = (packSize[fmt2] or 4) * rep(dims)
		len = len + size
	end
	table.insert(t, table.concat{'\tlen = ', len})
	return len
end
local function genDesc( hfile )
	local content = io.readfile(hfile)
	local t = {
	'----------------------------------------',
	'-- description generated from '..hfile, '\n', fmtDesc, '\n',
	}
	for i=1,#predefines do
		table.insert(t, predefines[i])
	end
	table.insert(t,
	'----------------------------------------')
	print('-- Predefine macro from '..hfile)
	for name, value in content:gmatch('#define%s*([_%w]+)%s*([_%w]+)') do
		local def = table.concat{'local ', name, '\t= ', value}
		table.insert(predefines, def)
		table.insert(t, def)
		print('#define', name, value)
		predefines[name] = value_check(value)
	end
	print'----------------------------------------'
	table.insert(t, 'local target = {')
	for struct in content:gmatch('(typedef struct %g-%s*%b{}%s*[_%w]+.-;)') do
		table.insert(t, '--[[')
		table.insert(t, struct)
		table.insert(t, '--]]')
		local block, def = struct:match('(%b{})%s*([_%w]+)')
		table.insert(t, def..' = {')
		packSize[def] = struct_fields(t, block)
		table.insert(t, '},')
	end
	table.insert(t, '}')
	table.insert(t, 'return target')
	content = table.concat(t, '\n')
	return content, hfile:match('^.*%.'):sub(1, -2)
end

for i=1,#hfile do
	local content, name = genDesc(hfile[i])
	local fn = name..'/struct.lua'
	local cmd = table.concat{'if not exist ', name, ' ( ', 'md ', name, ' )'}
	os.execute(cmd)
	io.writefile(fn, content)
end
print '----------------------------------------'
print 'struct.lua generated!'
