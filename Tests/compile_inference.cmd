@echo off
set LIB=D:\Program Files (x86)\Embarcadero\Studio\37.0\lib\Win64\release
"D:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe" -B -N".\dcu_out" InferenceTests.dpr -U"D:\ProgramData\delphi\DUnitX\Source;D:\ProgramData\delphi\TONNXRuntime\source;..\Core;..\Features;%LIB%" -E.
