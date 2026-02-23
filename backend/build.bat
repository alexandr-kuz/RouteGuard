@echo off
cd /d %~dp0
set GOPATH=
set GOMODCACHE=%USERPROFILE%\go\pkg\mod
"C:\Program Files\Go\bin\go.exe" build -v -o ../dist/routeguard.exe ./main.go
pause
