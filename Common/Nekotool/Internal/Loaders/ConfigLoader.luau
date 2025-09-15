-- Loads nekotool.config
local Types = require(script.Parent.Parent.Types)
local TableValidator = require(script.Parent.TableValidator)

type ConfigFile = {
	Name: string?,
	SourceFolder: Instance, -- deprecate this being a required setting
	EntryPoint: Instance?,
	CustomServices: Instance | {Instance}?,
	Flags: {[string]: boolean}?,	
	Services: {[string]: {[string]: Types.MicroserviceConfigItem}}?,
}

local ConfigFileAssertions: TableValidator.TTable = {
	keys = {
		Name = TableValidator.Optional(TableValidator.TType.string),
		SourceFolder = TableValidator.TType.Instance,
		EntryPoint = TableValidator.Optional(TableValidator.TType.Instance),

		CustomServices = {
			optional = true,
			allow_instead = TableValidator.TType.Instance,
			indexer = TableValidator.TType.number,
			value = TableValidator.TType.Instance,
		},
		
		Flags = {
			optional = true,
			indexer = TableValidator.TType.string,
			value = TableValidator.TType.boolean,
		},
		
		Services = {
			optional = true,
			indexer = TableValidator.TType.string,
			value = {
				indexer = TableValidator.TType.string,
				value = {
					strict = false,
					keys = {
						Enabled = TableValidator.Optional(TableValidator.TType.boolean),
					}
				}
			}
		}
	}
}

local ConfigLoader = {}

function ConfigLoader.load(config: ConfigFile): ConfigFile
	-- TODO: stricter assertions
	TableValidator.CheckTable("ConfigFile", config, ConfigFileAssertions)
	ConfigLoader.Config = config
	return config
end

function ConfigLoader:GetDebugFlag(flag: string, default: boolean?): boolean
	local flagVal = self.Config.Flags and self.Config.Flags[flag]
	if flagVal == nil then
		if default ~= nil then return default end
		return false
	end
	
	return flagVal
end

return ConfigLoader
