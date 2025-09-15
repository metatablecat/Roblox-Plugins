local Result = require(script.Parent.Result)
export type Result<T, E> = Result.Result<T, E> -- TODO: define type here

export type Signal<A...> = ((A...) -> ()) -> () -> ()

export type Event<A...> = {
	Name: string,
	Signal: Signal<A...>,
	Connections: {[() -> ()]: (A...) -> ()},
	Fire: (Event<A...>, A...) -> (),
	DisconnectAll: (Event<A...>) -> (),
	
	OnConnect: (Event<A...>, disconnector: () -> ()) -> ()?,
	OnDisconnect: (Event<A...>, disconnector: () -> ()) -> ()?
}

export type ProgramExports = {
	Name: string,
	RunContext: Enum.RunContext,
	Plugin: Plugin?,
	
	IsRunningLocally: (ProgramExports) -> boolean,
	Init: Signal<ProgramExports>,
	Unloading: Signal<ProgramExports>,
}

export type Program = {
	Name: string,
	Configs: {[string]: any},
	Connections: {[string]: {[() -> ()]: (ProgramExports, ...any) -> ()}},
	Exports: ProgramExports,
	IsProbablyLocal: boolean,
	ProjectRoot: Instance,
	
	InitEvent: Event<ProgramExports>,
	UnloadingEvent: Event<ProgramExports>,

	SourceFolder: Instance
}

export type MicroserviceConfigItem = {
	Enabled: boolean,
	[string]: any	
}

type MicroserviceState = "Idle"|"Spawning"|"Spawned"
export type Microservice<T> = {
	_rtState: {
		initFn: (Microservice<T>, Program: Program) -> Result.Result<T, string>,
		state: MicroserviceState,
		yielding: {thread},
	},
	
	Namespace: string,
	ID: string,
	LocalConfig: MicroserviceConfigItem,
	Enabled: boolean,
	Export: T?,
	Publish: (Microservice<T>) -> T,
	Import: (Microservice<T>) -> T?,
	AwaitIfEnabled: (Microservice<T>) -> Result.Result<T, string>?,
	Spawn: (Microservice<T>, Program: Program) -> (),
	OnPostInit: (Microservice<T>) -> ()?
}

export type ModuleLoaderDependencySearchType = 
|"Children"
|"SurfaceDescendents"
|"AllDescendents"

return nil