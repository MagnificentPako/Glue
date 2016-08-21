local args = {...}

local fsc = fs.combine
local json = dofile("/usr/bin/json")

local base_url = "https://glue-api.herokuapp.com/api/v1/"

local function parseOptions(options)
  local output = "?"
  for k,v in pairs(options) do output = output..textutils.urlEncode(k).."="..textutils.urlEncode(v).."&" end
  output = output:sub(1,#output-1)
  return output
end

local function request(method, call, options)
  local handle
  if(method == "get") then
    handle = http.get(base_url..call..parseOptions(options))
  elseif(method == "post") then
    handle = http.post(base_url..call, parseOptions(options))
  end

  local code = handle.getResponseCode()
  local content = handle.readAll()
  handle.close()

  return content,code

end

local autoload_code = [[
  local current = fs.getDir(shell.resolve(shell.getRunningProgram()))
  for _,v in pairs(fs.list(fs.combine(current, "dep"))) do
    local settings_file = fs.open(fs.combine(current,"dep/"..v.."/settings.lua"),"r")
    localsettings = loadstring("return " .. settings_file.readAll())()
    settings_file.close()

    local mode = settings.mode and settings.mode or "os.loadAPI"

    if(mode == "os.loadAPI") then
      fs.copy(fs.combine(current, "dep/"..v.."/main.lua"), fs.combine(current, "dep/"..v.."/"..v))
      os.loadAPI(fs.combine(current, "dep/"..v.."/"..v))
      fs.delete(fs.combine(current, "dep/"..v.."/"..v))
    elseif(mode == "dofile") then
        namespace = settings.namespace and settings.namespace or v
        _G[namespace] = dofile(fs.combine(current, "dep/"..v.."/main.lua"))
    end

  end
]]

local function isGlueFolder(folder)
  return fs.exists(fs.combine(folder,"GlueFile"))
end

if(args[1] == "install-glue-internal") then
  --Make gluelist mirror repolist for now
  term.setTextColor(colors.orange)
  print("Welcome to Glue!")
elseif(args[1] == "uninstall-glue-internal") then
elseif(args[1] == "init") then
  local dir = args[2] == nil and shell.dir() or args[2]
  if(not fs.isDir(dir)) then fs.makeDir(dir) end
  local handle = fs.open(fsc(dir,"GlueFile"),"w")
  handle.write([[--Insert dependencies here
--
--Either depend on the latest version
--depend "json"
--
--Or depend on a specific version
--depend "json" version "1"
--
--You can also define how the dependency should be loaded
--Valid methods are: dofile and os.loadAPI
--depend "json" method "dofile"
--
--dofile also has support for the "namepsace" method
--depend "json" method "dofile" namespace "JSON"
--This way you can decide where the loaded dependency should be located
--
--Of course you can use all of these in a combination too:
--depend "json" version "1" method "dofile" namespace "JSON_IS_AWESOME"
--
  ]])
  handle.close()
  fs.makeDir(fsc(dir,".glue"))
  fs.makeDir(fsc(dir,".glue/dep"))
  handle = fs.open(fsc(dir,".glue/autoload.lua"),"w")
  handle.write(autoload_code)
  handle.close()

elseif(args[1] == "search") then
  local content,code = request("get", "drops/search", {name = args[2]})
  if(code == 200) then
    content = json.parse(content)
  end
  print("Search results for '" .. args[2] .. "'")
  for _,drop in pairs(content.drops) do
    term.setTextColor(colors.lightGray)
    write(drop.author)
    term.setTextColor(colors.gray)
    write("/")
    term.setTextColor(colors.orange)
    write(drop.name)
    term.setTextColor(colors.gray)
    write(":")
    term.setTextColor(colors.yellow)
    print(drop.version)
  end
  term.setTextColor(colors.white)
elseif(args[1] == "install") then
  local env = {mode = args[2]} -- so you can define if you want some drops to be only for development/production etc

  local dependencies = {}
  --dependency = {
  --  name = "H4X0RZ/TestDrop",
  --  version = "1",
  --  mode = "dofile",
  --  namespace = "JSON"
  --}

  currentDependency = nil

  function env.depend(what)
    if(currentDependency ~= nil) then
      dependencies[#dependencies+1] = currentDependency
    end
    currentDependency = {name = what}
  end

  function env.version(ver)
    if(currentDependency == nil) then error() end
    currentDependency.version = ver
  end

  function env.method(mode)
    if(currentDependency == nil) then error() end
    currentDependency.mode = mode
  end

  function env.namespace(space)
    if(currentDependency == nil) then error() end
    currentDependency.namespace = space
  end

  local handle = fs.open(fsc(shell.dir(), "GlueFile"),"r")
  local gluefile_content = handle.readAll()
  handle.close()
  local gluefile = load(gluefile_content, nil, nil, env)
  gluefile()
  dependencies[#dependencies+1] = currentDependency
  for _,dependency in pairs(dependencies) do
    term.setTextColor(colors.lightGray)
    print("")
    write("Searching for ".. dependency.name .. "... ")
    response,code = request("get", "drops/exists", {name = dependency.name})
    response = json.parse(response)
    if(code == 200 and response.exists) then
      term.setTextColor(colors.green)
      write("FOUND")
      print("")
      term.setTextColor(colors.lightGray)
      write("Downloading " .. dependency.name .. "... ")

      drop_content,res_code = request("get", "drops/get", {name = dependency.name})
      drop_content = json.parse(drop_content)

      fs.makeDir(fsc(shell.dir(), ".glue/dep/" .. drop_content.name))
      local handle = fs.open(fsc(shell.dir(), ".glue/dep/".. drop_content.name .. "/main.lua"), "w")
      handle.write(drop_content.content)
      handle.close()
      handle = fs.open(fsc(shell.dir(), ".glue/dep/" .. drop_content.name .. "/settings.lua"), "w")
      handle.write(textutils.serialize(dependency))
      handle.close()

      term.setTextColor(colors.green)
      write("DONE")

    else
      term.setTextColor(colors.red)
      write("ERROR")
      print("")
      print("")
      term.setTextColor(colors.white)
      print("Oh no, something went wrong!")
      print("Couldn't find drop '" .. dependency.name .. "'")
    end
  end
end
