"""
inject_hook.py v3 - Inject lightweight hook + bytecode dump into crack.lua
Tạo crack_deob.lua với:
  1. Hook v11 (lightweight, no metamethod hooks) ở đầu file  
  2. Bytecode dump wrapper quanh hàm se_ (VM executor) ở cuối file
"""

import os

BASE = r"c:\Users\Administrator\Downloads\nguoitinhmuadong"
CRACK = os.path.join(BASE, "crack.lua")
HOOK = os.path.join(BASE, "hook_code.txt")
OUTPUT = os.path.join(BASE, "crack_deob.lua")

# Đọc files
with open(CRACK, "r", encoding="utf-8", errors="replace") as f:
    source = f.read()

with open(HOOK, "r", encoding="utf-8") as f:
    hook_code = f.read()

print(f"[*] crack.lua: {len(source)} bytes")
print(f"[*] hook_code.txt: {len(hook_code)} bytes")

# === INJECTION 1: Thêm hook_code.txt ở ĐẦU file (sau comment block) ===
# Tìm dòng local Sc,Vc... (dòng code thật đầu tiên)
target_start = "local Sc,Vc,Ga,Hd,lb,se_=pairs,type,bit32.bxor,getmetatable"
if target_start in source:
    source = source.replace(target_start, hook_code + "\n" + target_start, 1)
    print("[+] Injection 1: Hook v11 injected at TOP")
else:
    print("[!] WARNING: Could not find start marker for injection 1")

# === INJECTION 2: Wrap hàm se_ (VM executor) để dump bytecode ===
# Thay thế: se_=cc
# Thành: wrapper quanh cc để dump proto trước khi chạy VM
target_vm = "se_=cc"
vm_wrapper = """se_=cc

-- == VM EXECUTOR WRAPPER - DUMP BYTECODE ==
do
    local original_se = se_
    se_ = function(proto, upvals, ...)
        -- Dump proto structure
        pcall(function()
            local _log = {}
            local _ti = table.insert
            local _tc = table.concat
            local _t = type
            local _ts = tostring
            local _sf = string.format
            local _sb = string.byte

            local function safe(v)
                if _t(v) == "string" then
                    local s = v:gsub("[^\\32-\\126]", function(c) return _sf("\\\\x%02x", _sb(c)) end)
                    if #s > 200 then s = s:sub(1, 200) .. "..[" .. _ts(#v) .. "b]" end
                    return '"' .. s .. '"'
                end
                return _ts(v)
            end

            local function dumpTable(t, depth, name)
                depth = depth or 0
                name = name or "root"
                if depth > 4 then return end
                local indent = string.rep("  ", depth)

                if _t(t) ~= "table" then
                    _ti(_log, indent .. name .. " = " .. safe(t))
                    return
                end

                local count = 0
                for _ in pairs(t) do count = count + 1 end
                _ti(_log, indent .. name .. " = table(" .. count .. " entries)")

                local shown = 0
                for k, v in pairs(t) do
                    shown = shown + 1
                    if shown > 30 then
                        _ti(_log, indent .. "  ...truncated")
                        break
                    end

                    local key = "[" .. _ts(k) .. "]"
                    if _t(v) == "table" then
                        local subcount = 0
                        for _ in pairs(v) do subcount = subcount + 1 end
                        if subcount <= 15 then
                            dumpTable(v, depth + 1, key)
                        else
                            _ti(_log, indent .. "  " .. key .. " = table(" .. subcount .. " entries)")
                            -- Dump first few entries of large tables
                            local sc = 0
                            for k2, v2 in pairs(v) do
                                sc = sc + 1
                                if sc > 10 then break end
                                _ti(_log, indent .. "    [" .. _ts(k2) .. "] = " .. safe(v2))
                            end
                        end
                    elseif _t(v) == "string" then
                        _ti(_log, indent .. "  " .. key .. " = " .. safe(v))
                    elseif _t(v) == "function" then
                        _ti(_log, indent .. "  " .. key .. " = <function>")
                    else
                        _ti(_log, indent .. "  " .. key .. " = " .. _ts(v))
                    end
                end
            end

            _ti(_log, "")
            _ti(_log, "========================================")
            _ti(_log, "VM EXECUTOR CALLED - PROTO DUMP")
            _ti(_log, "========================================")
            _ti(_log, "proto type: " .. _t(proto))
            _ti(_log, "upvals type: " .. _t(upvals))

            -- Dump proto
            if _t(proto) == "table" then
                dumpTable(proto, 0, "PROTO")
            elseif _t(proto) == "string" then
                _ti(_log, "proto (string): " .. safe(proto:sub(1, 500)))
            end

            -- Dump upvals
            if _t(upvals) == "table" then
                dumpTable(upvals, 0, "UPVALS")
            end

            _ti(_log, "========================================")

            -- Ghi vào file
            local result = _tc(_log, "\\n")
            pcall(function() writefile("crack_vm_dump.txt", result) end)
            pcall(function()
                -- Append vào crack_dump.txt nếu đã tồn tại
                local existing = ""
                pcall(function() existing = readfile("crack_dump.txt") end)
                writefile("crack_dump.txt", existing .. "\\n" .. result)
            end)
            print("[+] VM PROTO DUMPED to crack_vm_dump.txt")
        end)

        return original_se(proto, upvals, ...)
    end
end
-- == END VM WRAPPER =="""

if target_vm in source:
    source = source.replace(target_vm, vm_wrapper, 1)
    print("[+] Injection 2: VM executor wrapper injected")
else:
    print("[!] WARNING: Could not find 'se_=cc' for injection 2")

# === INJECTION 3: Wrap Qe (Base64 decoder) để dump decoded data ===
target_qe_end = "ke,Je=(string.gsub),(string.char);"
qe_hook = """ke,Je=(string.gsub),(string.char);

-- == QE WRAPPER - LOG BASE64 DECODE ==
do
    local original_Qe_assign = true  -- flag
end
-- == END QE WRAPPER =="""

# Không wrap Qe ở đây vì nó complex, chỉ focus vào VM wrapper

# Ghi output
with open(OUTPUT, "w", encoding="utf-8") as f:
    f.write(source)

orig_size = os.path.getsize(CRACK)
new_size = os.path.getsize(OUTPUT)
print(f"\n[+] Output: {OUTPUT}")
print(f"[+] Original: {orig_size} bytes")
print(f"[+] Modified: {new_size} bytes (+{new_size - orig_size} bytes)")
print(f"[+] Hook v11: No metamethod hooks (won't break game)")
print(f"[+] Dumps: crack_dump.txt + crack_vm_dump.txt in exploit workspace")
