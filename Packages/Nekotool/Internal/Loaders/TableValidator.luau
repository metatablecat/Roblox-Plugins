-- Makes it trivial to validate the type of an another deeply nested table

export type TTable = {
	struct_name: string?,
	optional: boolean?,
	strict: boolean?,
	allow_instead: number?,
	indexer: TType?,
	value: TType?,
	keys: {[any]: TType}?
}

export type TType = number | TTable

local TTypeEnum = {
	[0] = "None",
	[1] = "nil",
	[2] = "boolean",
	[4] = "number",
	[8] = "string",
	[16] = "Instance",
	
	None = 0,
	["nil"] = 1,
	boolean = 2,
	number = 4,
	string = 8,
	Instance = 16
}

local function TTypeToString(t: TType, isNestedTable: boolean?)
	-- isNestedTable stops infinite expansion of table types, instead just returning "table"
	if typeof(t) == "number" then
		local isopt = bit32.band(t, 1) == 1
		local qmark = ""
		if isopt then
			t -= 1
			qmark = "?"
		end
		
		local fptt = TTypeEnum[t]
		if fptt then return `{fptt}{qmark}` end
		
		local sptt = table.create(4)
		for i = 1, 4 do
			local bit = 2^(i)
			if bit32.btest(t, bit) then table.insert(sptt, TTypeEnum[bit]) end
		end
		
		if isopt then return `( {table.concat(sptt, " | ")} )?)` end
		return table.concat(sptt, " | ")
	else
		-- if only keys are present, just return `table` | allow
		
		local allowinstead = if t.allow_instead then TTypeToString(t.allow_instead) else nil
		local typefield
		if not isNestedTable and (t.indexer or t.value) then
			local indexerType = if t.indexer then TTypeToString(t.indexer, true) else "any"
			local valueType = if t.value then TTypeToString(t.value, true) else "any"
			
			if t.indexer == TTypeEnum.number then
				typefield = `\{ {valueType} }`
			else
				typefield = `\{[ {indexerType} ]: {valueType}}`
			end
		else
			typefield = t.struct_name or "table"
		end
		
		-- figure out if we should attach allow_instead and ? based on a few rules
		
		if allowinstead then
			typefield = `{typefield} | {allowinstead}`
			return if t.optional then `( {typefield} )?` else typefield
		end
		
		return if t.optional then `{typefield}?` else typefield
	end
end

local function TypeError(key: string, t1: string, t2: TType)
	error(`TypeError: {key} has unexpected type '{t1}', expected '{TTypeToString(t2)}'.`, -1)	
end

local CheckTType

local function CheckNumericType(key: string, t1: any, t2: number, tabTType: TType?)
	local typof = typeof(t1)
	local ttype = TTypeEnum[typof] or TTypeEnum.None
	if ttype == TTypeEnum.None or not bit32.btest(ttype, t2) then
		TypeError(key, typof, tabTType or t2)
	end
end

local function CheckTableType(key: string, tab: {[any]: any}, ttype: TTable)
	if not tab then
		if ttype.optional then return end
		TypeError(key, "nil", ttype)
	end
	
	if type(tab) ~= "table" then
		if ttype.allow_instead then
			CheckNumericType(key, tab, ttype.allow_instead, ttype)
		end
		
		TypeError(key, typeof(tab), ttype)
	end
	
	local keys = ttype.keys or {}
	
	-- fast path: if strict is false, then we only need to validate strictly defined keys
	if ttype.strict == false then
		if not keys then return end
		for k, v in keys do
			CheckTType(`{key}.{k}`, tab[k], v)
		end
	else
		-- check values and compare against keys table
		-- or check if they match the indexer/value pair
		local indexer = ttype.indexer
		local value = ttype.value
		
		for k, v in tab do
			local keydef = keys[k]
			if keydef then
				CheckTType(`{key}.{k}`, v, keydef)
			elseif indexer or value then
				if indexer then CheckTType(`{key}<Indexer>`, k, indexer) end
				if value then CheckTType(`{key}.{k}`, v, value) end
			else
				error(`TypeError: {key} has invalid member key '{k}'`, -1)
			end
		end
	end
end

function CheckTType(key: string, val: any, ttype: TType)
	if typeof(ttype) == "number" then
		CheckNumericType(key, val, ttype)
	else
		CheckTableType(key, val, ttype)
	end
end

return {
	CheckType = CheckTType,
	TType = TTypeEnum,
	CheckTable = CheckTableType,
	Optional = function(ttype: number): number
		return ttype + 1
	end,
}