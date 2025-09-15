local Logica = require(script.Parent.Parent.RTK.Logica)
local Nekotool = require(script.Parent.Parent.Nekotool)
local StudioService = game:GetService("StudioService")

local function fixupStudioLocaleID(locale: string): string
	return string.gsub(string.lower(locale), "_", "-")
end

local PAT = "{(%w+)}"
local function getTranslation(tr: {[string]: {[string]: string}}, locale: string, key: string, gsub: {[string]: any}?): string
	local k = (tr[key] and tr[key][locale]) or key
	if k == key or not gsub then return k end

	return string.gsub(k, PAT, gsub)
end

return Nekotool.Service("MCGPluginServices", "TranslatorService", function(service, program)
	local TranslatorService = {}

	local localeID = fixupStudioLocaleID(StudioService.StudioLocaleId)
	local localeSource = Logica.Node(localeID)
	local simpleLogicaDependents: {[string]: Logica.Dependent<any>} = {}

	local tableSource: ModuleScript = service.LocalConfig.Translations
	assert(typeof(tableSource) == "Instance", tableSource:IsA("ModuleScript"), "Translation service needs a valid Translation source")
	local tr = require(tableSource)
	assert(type(tr) == "table", "Translation source must return a table")

	local function setLocaleId()
		localeID = fixupStudioLocaleID(StudioService.StudioLocaleId)
		localeSource:set(localeID)
	end

	function TranslatorService:Translate(key: string, sources: {[string]: any}?): string
		return getTranslation(tr, localeID, key, sources)
	end

	function TranslatorService:DefineLogicaSource(key: string, sources: {[string]: Logica.Any}?): Logica.Dependent<string>
		if sources then
			-- slow path: source dependent, needs some expensive code
			return Logica.Dependent(function()
				local locale = localeSource:get()

				local keys = {}
				for key, state in sources do
					keys[key] = state:get()
				end

				return getTranslation(tr, locale, key, keys)
			end)
		else
			-- fast path: simple dependent, just updates as soon as Locale is consumed
			local dep = simpleLogicaDependents[key]

			if not dep then
				dep = Logica.Dependent(function()
					return getTranslation(tr, localeSource:get(), key)
				end)
				simpleLogicaDependents[key] = dep
			end

			return dep
		end
	end

	StudioService:GetPropertyChangedSignal("StudioLocaleId"):Connect(setLocaleId)

	return Nekotool.Result.Ok(TranslatorService)
end)