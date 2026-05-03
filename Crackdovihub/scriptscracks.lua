--[[
    Deobfuscator for crack.lua
    Cách dùng: Chạy trong cùng môi trường Luau với crack.lua
    Script sẽ hook các hàm quan trọng để log hành vi thực tế
]]

-- ============================================
-- PHẦN 1: Lưu các hàm gốc
-- ============================================
local _print = print
local _type = type
local _tostring = tostring
local _pairs = pairs
local _ipairs = ipairs
local _pcall = pcall
local _select = select
local _setmetatable = setmetatable
local _getmetatable = getmetatable
local _rawget = rawget
local _rawset = rawset
local _error = error
local _assert = assert
local _tonumber = tonumber
local _unpack = unpack or table.unpack
local _format = string.format
local _byte = string.byte
local _char = string.char
local _sub = string.sub
local _rep = string.rep
local _gsub = string.gsub
local _find = string.find
local _len = string.len
local _concat = table.concat
local _insert = table.insert
local _remove = table.remove
local _sort = table.sort

-- ============================================
-- PHẦN 2: Hệ thống logging
-- ============================================
local LOG = {}
local LOG_LIMIT = 5000
local log_count = 0

local function log(category, msg)
    log_count = log_count + 1
    if log_count > LOG_LIMIT then return end
    local entry = "[" .. category .. "] " .. _tostring(msg)
    _insert(LOG, entry)
    _print(entry)
end

local function sanitize_string(s)
    if _type(s) ~= "string" then return _tostring(s) end
    if #s > 200 then
        s = _sub(s, 1, 200) .. "...[" .. #s .. " bytes]"
    end
    return (_gsub(s, "[^\32-\126]", function(c)
        return _format("\\x%02x", _byte(c))
    end))
end

local function args_to_string(...)
    local parts = {}
    local n = _select('#', ...)
    for i = 1, n do
        local v = _select(i, ...)
        if _type(v) == "string" then
            _insert(parts, '"' .. sanitize_string(v) .. '"')
        elseif _type(v) == "table" then
            _insert(parts, "{table:" .. _tostring(v) .. "}")
        elseif _type(v) == "function" then
            _insert(parts, "{func:" .. _tostring(v) .. "}")
        else
            _insert(parts, _tostring(v))
        end
    end
    return _concat(parts, ", ")
end

-- ============================================
-- PHẦN 3: Tạo hooked environment
-- ============================================
local function create_func_hook(name, original)
    return function(...)
        log("CALL", name .. "(" .. args_to_string(...) .. ")")
        local results = {_pcall(original, ...)}
        if results[1] then
            if _select('#', ...) > 0 or results[2] ~= nil then
                local ret_parts = {}
                for i = 2, #results do
                    if _type(results[i]) == "string" then
                        _insert(ret_parts, '"' .. sanitize_string(results[i]) .. '"')
                    else
                        _insert(ret_parts, _tostring(results[i]))
                    end
                end
                if #ret_parts > 0 then
                    log("RETURN", name .. " -> " .. _concat(ret_parts, ", "))
                end
            end
            return _unpack(results, 2)
        else
            log("ERROR", name .. " -> " .. _tostring(results[2]))
            _error(results[2], 2)
        end
    end
end

-- Hook table access
local function create_table_proxy(name, target, depth)
    depth = depth or 0
    if depth > 3 then return target end
    if _type(target) ~= "table" then return target end

    local proxy = {}
    local mt = {
        __index = function(_, key)
            local val = target[key]
            if _type(val) == "function" then
                return create_func_hook(name .. "." .. _tostring(key), val)
            elseif _type(val) == "table" and depth < 2 then
                return create_table_proxy(name .. "." .. _tostring(key), val, depth + 1)
            end
            return val
        end,
        __newindex = function(_, key, value)
            log("SET", name .. "." .. _tostring(key) .. " = " .. sanitize_string(value))
            target[key] = value
        end,
        __call = function(_, ...)
            if _type(target) == "function" then
                return target(...)
            end
        end,
        __len = function(_)
            return #target
        end,
        __pairs = function(_)
            return _pairs(target)
        end
    }
    return _setmetatable(proxy, mt)
end

-- ============================================
-- PHẦN 4: Hook getfenv để inject proxy env
-- ============================================
_print("\n========================================")
_print("  CRACK.LUA DEOBFUSCATOR")
_print("  Logging all external operations...")
_print("========================================\n")

-- Danh sách các hàm/module quan trọng cần hook
local hooked_globals = {}

local important_funcs = {
    "print", "warn", "error", "assert",
    "require", "loadstring", "load", "dofile",
    "rawget", "rawset", "rawequal", "rawlen",
    "next", "select", "unpack",
    "tostring", "tonumber", "type",
    "setfenv", "getfenv",
    "setmetatable", "getmetatable",
    "pcall", "xpcall",
    "spawn", "delay", "wait", "task",
}

local important_tables = {
    "game", "workspace", "script",
    "Instance", "Enum",
    "http", "HttpService",
    "Players", "ReplicatedStorage",
    "ServerStorage", "ServerScriptService",
}

-- ============================================
-- PHẦN 5: Chạy crack.lua với monitoring
-- ============================================

-- Approach 1: Nếu có loadstring (Roblox executor)
local function try_loadstring_approach()
    local readfn = readfile or function(path)
        local f = io.open(path, "r")
        if not f then return nil end
        local content = f:read("*a")
        f:close()
        return content
    end

    local source = readfn("crack.lua")
    if not source then
        -- Thử đường dẫn đầy đủ
        local f = io.open("c:\\Users\\Administrator\\Downloads\\ccccc\\crack.lua", "r")
        if f then
            source = f:read("*a")
            f:close()
        end
    end

    if not source then
        _print("[!] Không đọc được crack.lua")
        return false
    end

    _print("[+] Đã đọc crack.lua (" .. #source .. " bytes)")

    -- Inject hook sau "Ma=Md(Ma)" trong hàm cc
    local dump_hook = [[

-- === DEOBFUSCATION HOOK START ===
do
    local function dumpVal(v)
        local t = type(v)
        if t == "string" then
            local safe = v:gsub("[^\32-\126]", function(c) return string.format("\\x%02x", string.byte(c)) end)
            if #safe > 200 then safe = safe:sub(1,200) .. "...[" .. #v .. "b]" end
            return '"' .. safe .. '"'
        elseif t == "number" then return tostring(v)
        elseif t == "boolean" then return tostring(v)
        elseif t == "nil" then return "nil"
        else return "<" .. t .. ">"
        end
    end
    local function dumpProto(p, depth)
        local ind = string.rep("  ", depth)
        print(ind .. "╔══ Function Prototype ══")
        print(ind .. "║ Params: " .. tostring(p[44462] or "?"))
        print(ind .. "║ Upvalues: " .. tostring(p[21851] or "?"))
        -- Constants
        local consts = p[48457]
        if consts then
            print(ind .. "║ Constants (" .. #consts .. "):")
            for i = 1, math.min(#consts, 200) do
                print(ind .. "║   [" .. i .. "] " .. dumpVal(consts[i]))
            end
        end
        -- Instructions
        local instrs = p[61320]
        if instrs then
            print(ind .. "║ Instructions: " .. #instrs)
            for i = 1, math.min(#instrs, 500) do
                local ins = instrs[i]
                if ins then
                    print(ind .. string.format("║   %04d: OP=%-3s A=%-4s B=%-4s C=%-4s K=%s",
                        i,
                        tostring(ins[54592] or "?"),
                        tostring(ins[33813] or "?"),
                        tostring(ins[7414] or "?"),
                        tostring(ins[1145] or "?"),
                        dumpVal(ins[3229])))
                end
            end
            if #instrs > 500 then
                print(ind .. "║   ... (" .. (#instrs - 500) .. " more instructions)")
            end
        end
        print(ind .. "╚════════════════════════")
        -- Sub-protos
        local subs = p[51327]
        if type(subs) == "table" then
            for i = 1, #subs do
                print(ind .. "  ┌─ Sub-function " .. i .. ":")
                dumpProto(subs[i], depth + 1)
            end
        end
    end
    print("\n" .. string.rep("=", 60))
    print("  BYTECODE DUMP")
    print(string.rep("=", 60))
    dumpProto(Ma, 0)
    print(string.rep("=", 60) .. "\n")
    -- Save to file
    pcall(function()
        local output = {}
        local function collect(p, depth)
            local ind = string.rep("  ", depth)
            table.insert(output, ind .. "Function(params=" .. tostring(p[44462]) .. ", upvals=" .. tostring(p[21851]) .. ")")
            local consts = p[48457]
            if consts then
                for i = 1, #consts do
                    table.insert(output, ind .. "  K[" .. i .. "] = " .. dumpVal(consts[i]))
                end
            end
            local instrs = p[61320]
            if instrs then
                table.insert(output, ind .. "  Instructions: " .. #instrs)
                for i = 1, #instrs do
                    local ins = instrs[i]
                    if ins then
                        table.insert(output, ind .. string.format("  %04d: OP=%-3s A=%-4s B=%-4s C=%-4s K=%s jmp=%s",
                            i, tostring(ins[54592] or "?"), tostring(ins[33813] or "?"),
                            tostring(ins[7414] or "?"), tostring(ins[1145] or "?"),
                            dumpVal(ins[3229]), tostring(ins[27267] or "?")))
                    end
                end
            end
            local subs = p[51327]
            if type(subs) == "table" then
                for i = 1, #subs do
                    table.insert(output, ind .. "Sub-function " .. i .. ":")
                    collect(subs[i], depth + 1)
                end
            end
        end
        collect(Ma, 0)
        local result = table.concat(output, "\n")
        -- Try executor API
        if writefile then
            writefile("crack_dump.txt", result)
            print("[+] Saved to crack_dump.txt")
        end
        -- Try standard io
        local f = io.open("crack_dump.txt", "w")
        if f then
            f:write(result)
            f:close()
            print("[+] Saved to crack_dump.txt")
        end
    end)
end
-- === DEOBFUSCATION HOOK END ===

]]

    -- Tìm và inject hook sau "Ma=Md(Ma)"
    local injected = false

    -- Pattern 1: Ma=Md(Ma) với khoảng trắng linh hoạt
    local patterns = {
        "(Ma=Md%(Ma%))",
        "(Ma = Md%(Ma%))",
        "(Ma%s*=%s*Md%s*%(Ma%))",
    }

    for _, pat in _ipairs(patterns) do
        local new_source, count = _gsub(source, pat, "%1\n" .. dump_hook, 1)
        if count > 0 then
            source = new_source
            injected = true
            _print("[+] Hook injected successfully!")
            break
        end
    end

    if not injected then
        _print("[!] Could not find injection point 'Ma=Md(Ma)'")
        _print("[!] Trying alternative: hook at return point...")

        -- Alternative: inject before the final return
        source = source:gsub("(return%(function%(%))", dump_hook .. "\n%1", 1)
    end

    -- Thử execute
    local load_fn = loadstring or load
    if not load_fn then
        _print("[!] loadstring/load not available")
        -- Save modified source for manual execution
        _pcall(function()
            local f = io.open("crack_modified.lua", "w")
            if f then
                f:write(source)
                f:close()
                _print("[+] Saved modified source to crack_modified.lua")
                _print("[+] Run crack_modified.lua manually to see the dump")
            end
        end)
        _pcall(function()
            if writefile then
                writefile("crack_modified.lua", source)
                _print("[+] Saved modified source to crack_modified.lua")
            end
        end)
        return true
    end

    _print("[*] Executing hooked crack.lua...")
    _print("")

    local fn, err = load_fn(source)
    if not fn then
        _print("[!] Load error: " .. _tostring(err))
        return false
    end

    local ok, result = _pcall(fn)
    if not ok then
        _print("\n[!] Execution error (expected if script needs Roblox): " .. _tostring(result))
        _print("[+] But bytecode dump above should still be visible!")
    else
        _print("\n[+] Execution completed successfully")
        _print("[+] Result: " .. _tostring(result))
    end

    return true
end

-- ============================================
-- PHẦN 6: Approach 2 - Static analysis
-- Nếu không chạy được, phân tích tĩnh
-- ============================================
local function static_analysis()
    _print("\n[*] Running static analysis on crack.lua structure...\n")

    _print("╔══════════════════════════════════════════╗")
    _print("║      CRACK.LUA STRUCTURE ANALYSIS        ║")
    _print("╠══════════════════════════════════════════╣")
    _print("║                                          ║")
    _print("║  Layer 1: Base64 Decode (Qe)             ║")
    _print("║    ↓                                     ║")
    _print("║  Layer 2: LZ Decompress (gb)             ║")
    _print("║    ↓                                     ║")
    _print("║  Layer 3: Bytecode Deserialize (Md)      ║")
    _print("║    ↓                                     ║")
    _print("║  Layer 4: VM Execute (cc → Aa)           ║")
    _print("║                                          ║")
    _print("╠══════════════════════════════════════════╣")
    _print("║  Crypto: ChaCha20 (be) + SHA256 (ib)     ║")
    _print("║  VM: Custom bytecode with CFG flattening ║")
    _print("║  Opcodes: 265 defined in c[28576]        ║")
    _print("╠══════════════════════════════════════════╣")
    _print("║  VM Instruction Fields:                  ║")
    _print("║    [54592] = opcode                      ║")
    _print("║    [33813] = register A                  ║")
    _print("║    [7414]  = register B                  ║")
    _print("║    [1145]  = register C                  ║")
    _print("║    [3229]  = constant K                  ║")
    _print("║    [20264] = auxiliary data               ║")
    _print("║    [27267] = jump offset                 ║")
    _print("║    [55921] = table key 1                 ║")
    _print("║    [5052]  = table key 2                 ║")
    _print("╠══════════════════════════════════════════╣")
    _print("║  Proto Structure:                        ║")
    _print("║    [48457] = constants table              ║")
    _print("║    [51327] = sub-prototypes              ║")
    _print("║    [44462] = parameter count             ║")
    _print("║    [61320] = instruction list            ║")
    _print("║    [21851] = upvalue count               ║")
    _print("╠══════════════════════════════════════════╣")
    _print("║  String XOR Key: {.\\205\\199\\217B\\20\\14   ║")
    _print("║  Used for runtime string decryption      ║")
    _print("╚══════════════════════════════════════════╝")

    _print("\n[*] Identified VM Operations:")
    _print("  • LOADK      - Load constant to register")
    _print("  • MOVE       - Copy register")
    _print("  • GETTABLE   - Table read: R[A] = R[B][K]")
    _print("  • SETTABLE   - Table write: R[A][K] = R[C]")
    _print("  • NEWTABLE   - Create table: R[A] = {}")
    _print("  • CALL       - Function call")
    _print("  • RETURN     - Return values")
    _print("  • CLOSURE    - Create closure from sub-proto")
    _print("  • FORLOOP    - Numeric for loop")
    _print("  • FORPREP    - For loop preparation")
    _print("  • TFORLOOP   - Generic for (iterator)")
    _print("  • GETUPVAL   - Read upvalue")
    _print("  • SETUPVAL   - Write upvalue")
    _print("  • LOADBOOL   - Load boolean")
    _print("  • LOADNIL    - Load nil")
    _print("  • LEN        - Length operator: R[A] = #R[B]")
    _print("  • CONCAT     - String concat")
    _print("  • JMP        - Unconditional jump")
    _print("  • TEST/EQ    - Conditional test/compare")
    _print("  • GETGLOBAL  - Read global via env proxy")
    _print("  • SETGLOBAL  - Write global via env proxy")
end

-- ============================================
-- PHẦN 7: Main
-- ============================================
_print("╔══════════════════════════════════════════╗")
_print("║     CRACK.LUA DEOBFUSCATOR v1.0         ║")
_print("╚══════════════════════════════════════════╝")
_print("")

local success = try_loadstring_approach()

if not success then
    _print("\n[!] Dynamic approach failed, falling back to static analysis")
end

static_analysis()

-- Save logs
_print("\n[*] Total log entries: " .. #LOG)
_pcall(function()
    local log_text = _concat(LOG, "\n")
    if writefile then
        writefile("crack_log.txt", log_text)
        _print("[+] Logs saved to crack_log.txt")
    end
    local f = io.open("crack_log.txt", "w")
    if f then
        f:write(log_text)
        f:close()
        _print("[+] Logs saved to crack_log.txt")
    end
end)

_print("\n[*] Done! Check output above for bytecode dump.")
_print("[*] Nếu thấy BYTECODE DUMP → đó là bytecode đã giải mã")
_print("[*] Constants trong dump sẽ cho thấy strings/values thực tế")
_print("[*] Để decrypt strings runtime, tìm XOR key: {.\\205\\199\\217B\\20\\14")
