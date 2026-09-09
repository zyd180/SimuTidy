@echo off
setlocal
set "SimuTidy_DIR=%~dp0"
if "%SimuTidy_DIR:~-1%"=="\" set "SimuTidy_DIR=%SimuTidy_DIR:~0,-1%"

where matlab >nul 2>&1
if errorlevel 1 (
    echo [SimuTidy deploy] ERROR: "matlab" not found in system PATH.
    echo              Install MATLAB or add MATLAB\bin to PATH, then retry.
    pause
    exit /b 1
)

echo [SimuTidy deploy] Source: %SimuTidy_DIR%
echo [SimuTidy deploy] Launching MATLAB to run SimuTidy_install (R2019a+, ~30-60s)...
echo.

matlab -batch "addpath('%SimuTidy_DIR%'); addpath(fullfile('%SimuTidy_DIR%','gui')); addpath(fullfile('%SimuTidy_DIR%','core')); addpath(fullfile('%SimuTidy_DIR%','utils')); SimuTidy_install"

if errorlevel 1 (
    echo.
    echo [SimuTidy deploy] MATLAB returned an error, see output above.
    pause
    exit /b 1
)

echo.
echo [SimuTidy deploy] Done! Restart MATLAB, open any Simulink model,
echo              the SimuTidy menu is at the bottom of the Tools menu.
pause
