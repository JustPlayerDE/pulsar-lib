PulsarLib = PulsarLib or {}
PulsarLib.Modules = PulsarLib.Modules or setmetatable({
	stored = {}
}, {__index = PulsarLib})

local oldInclude = include
local oldAddCS = AddCSLuaFile
local oldFileFind = file.Find

local logging = PulsarLib.Logging
local loggingCol = PulsarLib.Logging.Colours
local highlightCol = loggingCol.Highlights
local textCol = loggingCol.Text

local excludeList = { -- A list of folders that shouldn't be replaced in `include` and `AddCSLuaFile` functions
	["includes"] = true
}

local modules = PulsarLib.Modules
modules.ModulesList = modules.ModulesList or {}

function modules:Scan()
	local files, folders = file.Find("pulsar_lib/modules/*", "LUA")

	for k, v in ipairs(files) do
		local name = string.StripExtension(v)
		if PulsarLib.ModuleTable[name] and PulsarLib.ModuleTable[name].Hook then
			PulsarLib.ModuleTable[name].Loaded = false
		end

		self.ModulesList[name] = {
			name = name,
			path = "pulsar_lib/modules/" .. v,
			type = "file"
		}
	end

	for k, v in ipairs(folders) do
		if PulsarLib.ModuleTable[v] and PulsarLib.ModuleTable[v].Hook then
			PulsarLib.ModuleTable[v].Loaded = false
		end

		self.ModulesList[v] = {
			name = v,
			path = "pulsar_lib/modules/" .. v,
			type = "folder"
		}
	end

	logging.Info("Scanned modules. Found ", highlightCol, #files, textCol, " files and ", highlightCol, #folders, textCol, " folders.")

	return self.ModulesList
end

function modules:Fetch(module)
	module = self.ModulesList[module]

	if not module then
		PulsarLib.Logging.Error("Attempted to fetch module that doesn't exist.")
		return
	end

	return module
end

function modules:FetchAll()
	return self.ModulesList
end


function modules:Load(module)
	module = istable(module) and module or self:Fetch(module)

	oldInclude = oldInclude or include
	oldAddCS = oldAddCS or AddCSLuaFile
	oldFileFind = oldFileFind or file.Find

	logging.Info("Loading module: ", highlightCol, module.name)

	if module.type ~= "folder" then
		PulsarLib:Include(module.path)
	end

	local files, _ = file.Find(module.path .. "/lua/autorun/*", "LUA")

	local moduleLuaPath = module.path .. "/lua/"

	for k, v in pairs(files) do
		local path = module.path .. "/lua/autorun/" .. v

		local function isExcluded(dir)
			for excludePath, _ in pairs(excludeList) do
				if string.find(dir, excludePath) then
					return true
				end
			end
			return false
		end

		local function moduleInclude(dir)
			if not dir then return end
			if isExcluded(dir) then
				return oldInclude(dir)
			end

			local includePath = moduleLuaPath .. dir
			local prefix = dir:match("/?(%w%w)[%w_]*.lua$") or "sh"
			logging:Get("Loader").Debug("Prefix: ", highlightCol,  prefix, textCol, ". Module: '", highlightCol, module.name, textCol, "' Path: '", highlightCol, dir, textCol, "'")

			local currentDirPath = debug.getinfo(2).source:match("@(.*/)")

			if currentDirPath then
				local lookForPath = currentDirPath .. dir
				lookForPath = lookForPath:Right(lookForPath:len() - 22)

				if file.Exists(lookForPath, "LUA") then
					return oldInclude(lookForPath)
				else
					return oldInclude(includePath)
				end
			else
				return oldInclude(includePath)
			end
			return oldInclude(includePath)
		end

		local function moduleAddCS(dir)
			if not dir then
				local lookForPath = debug.getinfo(2).source
				lookForPath = lookForPath:Right(lookForPath:len() - 23)

				if file.Exists(lookForPath, "LUA") then
					return oldAddCS(lookForPath)
				end

				return
			end

			if isExcluded(dir) then
				return oldAddCS(dir)
			end

			local includePath = moduleLuaPath .. dir
			local prefix = includePath:match("/?(%w%w)[%w_]*.lua$") or "sh"
			logging:Get("Loader").Debug("Prefix: ", highlightCol,  prefix, textCol, ". Module: '", highlightCol, module.name, textCol, "' Path: '", highlightCol, dir, textCol, "'")

			local currentDirPath = debug.getinfo(2).source:match("@(.*/)")

			if currentDirPath then
				local lookForPath = currentDirPath .. dir
				lookForPath = lookForPath:Right(lookForPath:len() - 22)

				if file.Exists(lookForPath, "LUA") then
					return oldAddCS(lookForPath)
				else
					return oldAddCS(includePath)
				end
			else
				return oldAddCS(includePath)
			end
			return oldAddCS(includePath)
		end

		local function moduleFileFind(dir, findPath, sorting)
			return oldFileFind(moduleLuaPath .. dir, findPath, sorting or "")
		end

		include = moduleInclude
		AddCSLuaFile = moduleAddCS
		file.Find = moduleFileFind

		oldAddCS(path)
		oldInclude(path)

		include = oldInclude
		AddCSLuaFile = oldAddCS
		file.Find = oldFileFind

		logging:Get("Loader").Debug("Module: '", highlightCol, module.name, textCol, "' Path: '", highlightCol, path, textCol, "'")

	end

	if PulsarLib.ModuleTable[module.name] and PulsarLib.ModuleTable[module.name].Global and _G[PulsarLib.ModuleTable[module.name].Global] then
		logging.Debug("'", highlightCol, module.name, textCol, "' module successfully loaded")
		PulsarLib.ModuleTable[module.name].Loaded = true
		PulsarLib.Dependency.Loaded(module.name)
		return
	end

	if PulsarLib.ModuleTable[module.name] and PulsarLib.ModuleTable[module.name].Hook then
		hook.Add(PulsarLib.ModuleTable[module.name].Hook, "PulsarLib.DependancyLoader", function()
			logging.Debug("'", highlightCol, module.name, textCol, "' module hook received. Module successfully loaded.")
			PulsarLib.ModuleTable[module.name].Loaded = true
			PulsarLib.Dependency.Loaded(module.name)
		end)
	elseif PulsarLib.ModuleTable[module.name] then
		PulsarLib.ModuleTable[module.name].Loaded = true
		PulsarLib.Dependency.Loaded(module.name)
	end
end

function modules:LoadAll()
	PulsarLib.ModulesLoaded = false

	for k, v in pairs(self:FetchAll()) do
		self:Load(k)
	end

	PulsarLib.ModulesLoaded = true
	hook.Add("PulsarLib.ModulesLoaded")
end

PulsarLib.Modules:Scan()
PulsarLib.Modules:LoadAll()

