# inject_hook.ps1 v5 - Hook v13 ONLY (no VM wrapper)
$basePath = "c:\Users\Administrator\Downloads\nguoitinhmuadong"
$hookCode = [System.IO.File]::ReadAllText("$basePath\hook_code.txt", [System.Text.Encoding]::UTF8)
$source = [System.IO.File]::ReadAllText("$basePath\crack.lua", [System.Text.Encoding]::UTF8)

Write-Host "[*] crack.lua: $($source.Length) bytes"

# === INJECTION: Prepend Hook v35 to TOP ===
$source = $hookCode + "`n" + $source
Write-Host "[+] Hook v35 prepended at TOP"

[System.IO.File]::WriteAllText("$basePath\crack_deob.lua", $source, [System.Text.Encoding]::UTF8)

$origSize = (Get-Item "$basePath\crack.lua").Length
$newSize = (Get-Item "$basePath\crack_deob.lua").Length

Write-Host ""
Write-Host "[+] Output: crack_deob.lua ($newSize bytes, +$($newSize - $origSize))"
Write-Host "[+] Hook v35: Ultimate Payload Dumper"
Write-Host "[+] Intercepts loadstring, HttpGet, request, etc."
Write-Host "[+] Auto-saves cracked scripts to: workspace/CRACKED_*.lua"
Write-Host "[+] Check crack_dump.txt for log traces."
