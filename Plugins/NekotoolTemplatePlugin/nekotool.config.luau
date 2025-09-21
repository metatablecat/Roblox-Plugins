return {
	Name = "NekotoolTemplate",
	SourceFolder = script.Parent.Src,
	EntryPoint = script.Parent.Src.MainPlugin,
	CustomServices = { script.Parent.Packages.PluginServices }
}