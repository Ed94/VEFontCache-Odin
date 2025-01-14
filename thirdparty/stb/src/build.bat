@echo off

if not exist "..\lib" mkdir ..\lib

cl -nologo -MT -TC -O2 -c stb_image.c stb_truetype.c
lib -nologo stb_truetype.obj -out:..\lib\stb_truetype.lib

del *.obj
