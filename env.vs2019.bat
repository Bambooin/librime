rem Customize your build environment and save the modified copy to env.bat

if not defined RIME_ROOT set RIME_ROOT=%CD%
if not exist "%RIME_ROOT%\boost-version" (
  if exist "%~dp0boost-version" for %%I in ("%~dp0.") do set RIME_ROOT=%%~fI
)
if not exist "%RIME_ROOT%\boost-version" (
  echo Error: boost-version not found in %RIME_ROOT%.
  exit /b 1
)

rem REQUIRED: path to Boost source directory
if not defined BOOST_ROOT (
  for /f "usebackq delims=" %%I in ("%RIME_ROOT%\boost-version") do if not defined BOOST_VERSION set BOOST_VERSION=%%I
  if defined BOOST_VERSION set BOOST_ROOT=%RIME_ROOT%\deps\boost-%BOOST_VERSION%
)

rem architecture, Visual Studio version and platform toolset
set ARCH=Win32
set BJAM_TOOLSET=msvc-14.2
set CMAKE_GENERATOR="Visual Studio 16 2019"
set PLATFORM_TOOLSET=v142

rem OPTIONAL: path to additional build tools
rem set DEVTOOLS_PATH=%ProgramFiles%\Git\cmd;%ProgramFiles%\CMake\bin;C:\Python27;
