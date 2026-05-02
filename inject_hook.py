import re

# Read crack.lua
with open(r"c:\Users\Administrator\Downloads\ccccc\crack.lua", "r", encoding="utf-8") as f:
    content = f.read()

# Hook code - dump bytecode after deserialization
hook = r'''
-- == DEOBFUSCATION HOOK ==
do
    local function dv(v)
        local t = type(v)
        if t == "string" then
            local s = v:gsub("[^\32-\126]", function(c) return string.format("\\x%02x", string.byte(c)) end)
            if #s > 200 then s = s:sub(1,200).."..["..#v.."b]" end
            return '"'..s..'"'
        elseif t == "number" then return tostring(v)
        elseif t == "boolean" then return tostring(v)
        elseif t == "nil" then return "nil"
        else return "<"..t..">" end
    end
    local function dp(p, d)
        local i = string.rep("  ", d)
        print(i.."== Function (params="..tostring(p[44462])..", upvals="..tostring(p[21851])..") ==")
        local k = p[48457]
        if k then
            print(i.."  Constants ("..#k.."):")
            for j=1,#k do print(i.."    ["..j.."] "..dv(k[j])) end
        end
        local ins = p[61320]
        if ins then
            print(i.."  Instructions: "..#ins)
            for j=1,math.min(#ins,999) do
                local g = ins[j]
                if g then
                    print(i..string.format("  %04d: OP=%-3s A=%-4s B=%-4s C=%-4s K=%s jmp=%s",
                        j, tostring(g[54592] or "?"), tostring(g[33813] or "?"),
                        tostring(g[7414] or "?"), tostring(g[1145] or "?"),
                        dv(g[3229]), tostring(g[27267] or "-")))
                end
            end
            if #ins > 999 then print(i.."  ...("..#ins-999 .." more)") end
        end
        local sub = p[51327]
        if type(sub)=="table" then
            for j=1,#sub do
                print(i.."  -- Sub-function "..j.." --")
                dp(sub[j], d+1)
            end
        end
    end
    print("\n========================================")
    print("  BYTECODE DUMP - DEOBFUSCATED OUTPUT")
    print("========================================")
    dp(Ma, 0)
    print("========================================\n")
end
-- == END HOOK ==
'''

# Inject after Ma=Md(Ma)
target = "Ma=Md(Ma)"
if target in content:
    content = content.replace(target, target + "\n" + hook, 1)
    print(f"[+] Hook injected after '{target}'")
else:
    print("[!] Could not find injection point")
    exit(1)

# Save
output_path = r"c:\Users\Administrator\Downloads\ccccc\crack_deob.lua"
with open(output_path, "w", encoding="utf-8") as f:
    f.write(content)

print(f"[+] Saved to {output_path}")
print(f"[+] File size: {len(content)} bytes")
print("[+] Paste crack_deob.lua into your executor to see the bytecode dump!")
