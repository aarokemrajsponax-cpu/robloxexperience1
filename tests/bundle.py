#!/usr/bin/env python3
"""Bundles src/shared modules plus tests/run.luau into one Luau chunk for the standalone runtime."""
import os, re, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
shared = os.path.join(root, "src", "shared")
out = []
out.append("local __modules, __loaded = {}, {}\n")
out.append("local function __require(ref) local name = ref.__module; if __loaded[name] == nil then __loaded[name] = __modules[name]() end return __loaded[name] end\n")
out.append("local __script = { Parent = setmetatable({}, { __index = function(_, k) return { __module = k } end }) }\n")
for f in sorted(os.listdir(shared)):
    if not f.endswith(".luau"):
        continue
    name = f[:-5]
    src = open(os.path.join(shared, f)).read()
    src = re.sub(r"^--!\w+\s*\n", "", src)
    out.append(f"__modules[{name!r}] = function()\nlocal script, require = __script, __require\n{src}\nend\n")
test = open(os.path.join(root, "tests", "run.luau")).read()
test = test.replace("--[[LOADER]]", "local function loadModule(name) return __require({ __module = name }) end")
out.append(test)
sys.stdout.write("".join(out))
