local PluginServices = {
	-- long term goal: deprecate Publish and PostInit
	Forms = require(script.Forms):Publish(),
	StylingService = require(script.StylingService):Publish(),
	ToolbarService = require(script.ToolbarService):Publish(),
	TranslatorService = require(script.TranslatorService):Publish()
}

table.freeze(PluginServices)
return PluginServices