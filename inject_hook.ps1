# inject_hook.ps1 v2 - Inject at TOP of file (before VM captures builtins)
$hookCode = [System.IO.File]::ReadAllText("c:\Users\Administrator\Downloads\ccccc\hook_code.txt")
$source = [System.IO.File]::ReadAllText("c:\Users\Administrator\Downloads\ccccc\crack.lua")

# Inject BEFORE the first line of actual code (after the comment block)
$target = "local Sc,Vc,Ga,Hd,lb,se_=pairs,type,bit32.bxor,getmetatable"
$replacement = $hookCode + "`n" + $target

$newSource = $source.Replace($target, $replacement)

if ($newSource.Length -gt $source.Length) {
    [System.IO.File]::WriteAllText("c:\Users\Administrator\Downloads\ccccc\crack_deob.lua", $newSource)
    Write-Host "[+] Hook injected at TOP of file (before builtins capture)!"
    Write-Host "[+] Original size: $($source.Length) bytes"
    Write-Host "[+] New size: $($newSource.Length) bytes"
    Write-Host "[+] Output: crack_deob.lua"
} else {
    Write-Host "[!] Failed to inject hook"
}
