--!strict
local Types = require(script.Parent.Types)

local SPCK_MT = {
	__eq = function<T>(lhs: Types.SpecialKey<T>, rhs: Types.SpecialKey<T>): boolean
		return lhs.__RCSpecialKey == rhs.__RCSpecialKey and lhs.prop == rhs.prop
	end,
}
--[=[
	@class SpecialKey
	
	A metakey defining some special logic when mapping props to an Instance.
]=]
--

--[=[
	@prop __RCSpecialKey T
	@within SpecialKey
	@readonly

	The unique identifier of the SpecialKey which tells Recreate how it
	should handle the prop half
]=]
--

--[=[
	@prop prop string
	@within SpecialKey
	@readonly

	The non-unique half of the SpecialKey which represents the name of the
	metakey.
]=]
--

--[=[
	@function IsA
	@within SpecialKey
	@param self SpecialKey
	@param other SpecialKey
	@return boolean

	Compares two special keys to check if both have the same class name
]=]
--

return function(className: string): (string) -> Types.SpecialKey
	return function(propName: string): Types.SpecialKey
		local key = setmetatable({
			__RCSpecialKey = className,
			prop = propName,
			IsA = function(self, other)
				return self.__RCSpecialKey == other
			end,
		}, SPCK_MT)

		table.freeze(key)
		return key
	end
end
