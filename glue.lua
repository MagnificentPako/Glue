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
    dofile(fs.combine(fs.combine(current,"dep"),v))
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
  handle = fs.open(fsc(dir,".glue/autoload.lua"),"w")
  handle.write(autoload_code)
  handle.close()

elseif(args[1] == "search") then
  local content,code = request("get", "drops/search", {name = args[2]})
  if(code == 200) then
    content = json.parse(content)
  end
  print(textutils.serialize(content))
elseif(args[1] == "install") then

end
