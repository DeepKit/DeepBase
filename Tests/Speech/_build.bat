@echo off
set BDS=D:\Program Files (x86)\Embarcadero\Studio\37.0
call "%BDS%\bin\rsvars.bat"
"%BDS%\bin\dcc64.exe" --no-config -Q -ED:\_Progs\02Business\DeepBase\Tests\Speech\bin -ND:\_Progs\02Business\DeepBase\Tests\Speech\dcu -UD:\_Progs\02Business\DeepBase\Features;D:\_Progs\02Business\DeepBase\Core;D:\_Progs\02Business\DeepBase\Persistence;"%BDS%\lib\Win64\release" -ID:\_Progs\02Business\DeepBase\Features;D:\_Progs\02Business\DeepBase\Core;"%BDS%\lib\Win64\release" -NSWinapi;System;System.Win;Data;FireDAC.Comp;FireDAC.Stan D:\_Progs\02Business\DeepBase\Tests\Speech\TestSpeechHeadless.dpr
