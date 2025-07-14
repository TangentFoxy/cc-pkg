#!/usr/bin/env luajit

math.randomseed(os.time())

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "?.lua;" .. package.path
local utility = require "lib.utility"
local sandbox = utility.require("lib.sandbox")
local urlencode = utility.require("lib.urlencode")

if type(jit) ~= "table" then
  error("This script must be run in LuaJIT to prevent malicious code from breaking out of its sandbox.")
end

-- TODO fix the fact that this breaks any usage that would *not* escape..
local clean_path = function(path)
  path = "./root/" .. path
  return path:gsub("%.%.", "") -- remove going up a directory to escape root
end

local environment
environment = {
  fs = {
    exists = function(path)
      path = clean_path(path)
      return utility.is_file(path) -- TODO or should this be path_exists ?
    end,
  },
  io = {
    lines = function(path) -- NOTE not sure if this will work
      path = clean_path(path)
      local contents
      utility.open(path, "r", function(file)
        contents = file:read("*all")
      end)
      return contents:gmatch("[^\r\n]+")
    end,
    open = function(path, mode)
      path = clean_path(path)
      -- ComputerCraft doesn't care about whether the path exists, so we need to make sure not to care either!
      local _path = utility.split_path_components(path)
      os.execute("mkdir -p " .. _path)
      return io.open(path, mode)
    end,
  },
  http = {
    get = function(url, headers)
      local header_table = {}
      for k,v in pairs(headers) do
        header_table[#header_table + 1] = "-H " .. (k .. ": " .. v):enquote()
      end
      local text = utility.curl_read(url, table.concat(header_table, " "))
      -- NOTE faking the response object and functions
      return {
        getResponseCode = function() return 200 end,
        readAll = function() return text end,
        close = function() end,
      }
    end,
  },
  textutils = {
    -- NOTE hack: a carriage return can show up here even though it never does in ComputerCraft, so we silently remove any present
    urlEncode = function(text)
      text = text:gsub("\r", "")
      return urlencode(text)
    end,
  },
  shell = {
    run = function(path, ...)
      path = clean_path(path)
      local arguments = {...}
      utility.open(path, "r", function(file)
        sandbox.run(file:read("*all"), { env = environment }, unpack(arguments))
      end)
    end,
    resolve = function(path) -- TODO fix?
      path = clean_path(path)
      print("WARNING! shell.resolve() not implemented.")
      return nil -- make sure whatever called this knows it failed
    end,
  },
  print = print,
}

-- TODO we need to check the names.list and use it to try to download everything
--   basically, that's how the total archive is updated, pulling everything we can

-- TODO I need to figure out how to identify conflicts so that my archive can be complete despite them
--   if I find any, I have to fix them at the source, not here

-- TODO we need to be able to pull metadata about all pastebin IDs, who made them, what are their titles
--   use dkjson to store that info in a single object??

utility.open("./root/bin/pkg", "r", function(file)
  sandbox.run(file:read("*all"), { env = environment })
end)

-- TODO remove duplicates and sort root/etc/pkg/ids.list
-- TODO rm dupes and sort root/etc/pkg/names.list
