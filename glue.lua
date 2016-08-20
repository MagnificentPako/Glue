local args = {...}

local fsc = fs.combine

local autoload_code = [[
  local current = fs.getDir(shell.resolve(shell.getRunningProgram()))
  for _,v in pairs(fs.list(fs.combine(current, "dep"))) do
    dofile(fs.combine(fs.combine(current,"dep"),v))
  end
]]

if(args[1] == "install-glue-internal") then
  --Make gluelist mirror repolist for now
  fs.copy("/etc/repolist", "/etc/gluelist")
elseif(args[1] == "uninstall-glue-internal") then
  fs.remove("/etc/gluelist")
elseif(args[1] == "init") then
  local dir = args[2] == nil and fs.getDir(shell.resolve(shell.getRunningProgram())) or args[2]
  if(not fs.isDir(dir)) then fs.makeDir(dir) end
  local handle = fs.open(fsc(dir,"GlueFile"),"w")
  handle.write("--Insert dependencies here")
  handle.close()
  fs.makeDir(fsc(dir,".glue"))
  handle = fs.open(fsc(dir,".glue/autoload.lua"),"w")
  handle.write(autoload_code)
  handle.close()
elseif(args[1] == "install") then
  print("not yet implemented")
end
