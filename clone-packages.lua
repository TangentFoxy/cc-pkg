#!/usr/bin/env luajit

math.randomseed(os.time())

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "?.lua;" .. package.path
local utility = require "lib.utility"
local urlencode = utility.require("lib.urlencode")

local get_type = function(data)
  if data:match("^/[%Z%C\n]+=[^\n]+\n?") then
    return "package"
  elseif data:match("^[%w%-]+=[%w%-]+\n?") then
    return "list"
  else
    return "unknown"
  end
end

local get_id
get_id = function(name_or_id)
  if utility.file_exists("names.list") then
    for line in io.lines("names.list") do
      local first, last = line:find(name_or_id, 1, true)
      local separator = line:find("=")
      if first == 1 and last == (separator - 1) then
        return get_id(line:sub(separator + 1))
      end
    end
  end
  return name_or_id:gsub("\r", "")
end

local file_append = function(path, data)
  utility.open(path, "a")(function(file)
    file:write(data)
    file:write("\n")
  end)
end

local file_save = function(path, data)
  utility.open(path, "w")(function(file)
    file:write(data)
  end)
end

local download_id = function(id)
  local url = "https://pastebin.com/raw/" .. urlencode(id) .. "?cb=" .. ("%x"):format(math.random(0, 2^30))
  local data = utility.curl_read(url, "-A \"ComputerCraft package cloner\"")
  file_append("ids.list", id) -- NOTE it really should be reread and output alphabetically..
  return data
end

local add_names = function(data)
  local names = {}
  if utility.file_exists("names.list") then
    utility.open("names.list", "r")(function(file)
      for line in file:lines() do
        local s = line:find("=")
        names[line:sub(1, s - 1)] = line:sub(s + 1)
      end
    end)
  end

  for line in data:gmatch("([^\n]+)\n?") do
    local s = line:find("=")
    if s then
      names[line:sub(1, s - 1)] = line:sub(s + 1)
    else
      print("Invalid source: " .. line)
    end
  end

  -- NOTE creating a sorted list so that future commit messages won't have semi-random reorganization
  local sorted_list = {}
  for k,v in pairs(names) do
    sorted_list[#sorted_list + 1] = k .. "=" .. v
  end
  table.sort(sorted_list)

  utility.open("names.list", "w")(function(file)
    -- for k,v in pairs(names) do
    --   file:write(k .. "=" .. v .. "\n")
    -- end
    file:write(table.concat(sorted_list, "\n"))
    file:write("\n") -- TODO make sure this is actually needed
  end)
end

local get_data
get_data = function(name_or_id, path)
  local data = download_id(get_id(name_or_id))
  local pkg_type = get_type(data)

  if pkg_type == "package" then
    for line in data:gmatch("([^\n]+)\n?") do
      local s = line:find("=")
      if s then
        local name_or_id = line:sub(s + 1)
        path = line:sub(1, s - 1)
        get_data(name_or_id, path)
      else
        print("Invalid file: " .. line)
      end
    end
    file_save("package-lists/" .. name_or_id, data)

  elseif pkg_type == "list" then
    add_names(data)

  else
    if not path then
      path = "missing-paths/" .. name_or_id
      file_save("broken-packages/" .. name_or_id, path .. "=" .. name_or_id)
    end
    file_save("./" .. path:gsub("/", "--"), data)
  end
end

os.execute("mkdir -p package-lists")
os.execute("mkdir -p missing-paths")
os.execute("mkdir -p broken-packages")
os.execute("mkdir -p root")

if not utility.file_exists("names.list") then
  file_save("ids.list", "9Li3u4Rc\n")
  -- file_save("pkg", "/bin/pkg=9Li3u4Rc") -- I think this should be in package-lists/ ?
  get_data("AH4zw4n0") -- default packages list
end

-- TODO actually do something! :D
get_data(arg[1])
