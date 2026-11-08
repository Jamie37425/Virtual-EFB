Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -WindowStyle Hidden -File ""c:\Users\princ\OneDrive\Documents\App\tools\serve.ps1""", 0, False
