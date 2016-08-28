local args = {...}

local fsc = fs.combine
local json = dofile("/usr/bin/json")

local base_url = "https://glue-api.herokuapp.com/api/v1/"

--Add more once I find wrongly formatted ones
local unicode_map = {
  ["u003e"] = ">",
  ["u003c"] = "<"
}

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
  local current = fs.getDir(shell.getRunningProgram())
  for _,v in pairs(fs.list(fs.combine(current, "dep"))) do
    local settings_file = fs.open(fs.combine(current,"dep/"..v.."/settings.lua"),"r")
    local settings = loadstring("return " .. settings_file.readAll())()
    settings_file.close()

    local method = settings.method and settings.method or "os.loadAPI"
    local namespace = settings.namespace and settings.namespace or v

    if(method == "os.loadAPI") then
      fs.copy(fs.combine(current, "dep/"..v.."/main.lua"), fs.combine(current, "dep/"..v.."/"..namespace))
      os.loadAPI(fs.combine(current, "dep/"..v.."/"..namespace))
      fs.delete(fs.combine(current, "dep/"..v.."/"..namespace))
    elseif(method == "dofile") then
        _G[namespace] = dofile(fs.combine(current, "dep/"..v.."/main.lua"))
    elseif(method == "ignore") then
      continue
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
  local dir = args[2] == nil and shell.dir() or shell.resolve(args[2])
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
--Valid methods are: dofile, os.loadAPI and ignore (ignore will only download the drop, but never load it. Useful if you download a binary/program as drop and want to execute it with custom args)
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
  --  name = "H4X0RZ/TestDrop", (or name = "TestDrop",)
  --  version = "1",
  --  method = "dofile",
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

  function env.method(met)
    if(currentDependency == nil) then error() end
    currentDependency.method = met
  end

  function env.namespace(space)
    if(currentDependency == nil) then error() end
    currentDependency.namespace = space
  end

  local handle = fs.open(fsc(shell.dir(), "GlueFile"),"r")
  local gluefile_content = handle.readAll()
  handle.close()

  local meta_env = {__index = function(t,k) if(env.k) then return env.k else error(k.." is undefined",0) end end}
  setmetatable(env, meta_env)

  local gluefile = load(gluefile_content, nil, nil, env)
  gluefile()
  dependencies[#dependencies+1] = currentDependency
  for _,dependency in pairs(dependencies) do
    term.setTextColor(colors.lightGray)
    print("")
    write("Searching for ".. dependency.name .. "... ")
    response,code = request("get", "drops/exists", {name = dependency.name, version = dependency.version})
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
      dcont = drop_content.content
      for k,v in pairs(unicode_map) do
        dcont = dcont:gsub(k,v)
      end
      handle.write(dcont)
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
      res,code = request("get","drops/exists",{name = dependency.name})
      res = json.parse(res)
      if(code == 200) then
        if(res.exists == false) then
            print("Couldn't find drop '" .. dependency.name .. "'")
        else
          print("Couldn't find version '" .. dependency.version .. "' for drop '" .. dependency.name .. "'")
        end
      end
    end
  end
end
