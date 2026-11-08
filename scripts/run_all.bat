@echo off
setlocal enabledelayedexpansion

rem collect every RTL file
set RTL=
for %%f in (rtl\*.v) do set RTL=!RTL! %%f

set PASSED=0
set FAILED=0

for %%t in (testbench\*_tb.v) do (
    if exist "%TEMP%\cpu_all.vvp" del "%TEMP%\cpu_all.vvp"
    iverilog -s %%~nt -o "%TEMP%\cpu_all.vvp" !RTL! %%t >nul 2>&1
    if errorlevel 1 (
        echo [COMPILE ERROR] %%~nt
        set /a FAILED+=1
    ) else (
        vvp "%TEMP%\cpu_all.vvp" > "%TEMP%\cpu_all.log" 2>&1
        findstr /C:"FAIL" /C:"HAZARD:" "%TEMP%\cpu_all.log" >nul
        if errorlevel 1 (
            echo [PASS] %%~nt
            set /a PASSED+=1
        ) else (
            echo [FAIL] %%~nt
            set /a FAILED+=1
        )
    )
)

echo.
echo Passed: !PASSED!   Failed: !FAILED!