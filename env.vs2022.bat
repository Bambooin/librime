rem Customize your build environment and save the modified copy to env.bat

if not defined RIME_ROOT set RIME_ROOT=%CD%
set BOOST_DATA_FILE=%RIME_ROOT%\boost_data.txt
if not exist "%BOOST_DATA_FILE%" (
  if exist "%~dp0boost_data.txt" for %%I in ("%~dp0.") do set RIME_ROOT=%%~fI
)
set BOOST_DATA_FILE=%RIME_ROOT%\boost_data.txt
if not exist "%BOOST_DATA_FILE%" (
  echo Error: boost_data.txt not found in %RIME_ROOT%.
  exit /b 1
)

rem REQUIRED: path to Boost source directory
if not defined BOOST_ROOT (
  for /f "usebackq tokens=1,* delims==" %%A in (`findstr /r /c:"^version=.*" "%BOOST_DATA_FILE%"`) do if not defined BOOST_VERSION set BOOST_VERSION=%%B
  if defined BOOST_VERSION for /f %%I in ("%BOOST_VERSION%") do set BOOST_VERSION=%%~I
  if not defined BOOST_VERSION (
    echo Error: missing version in %BOOST_DATA_FILE%.
    exit /b 1
  )
  if defined BOOST_VERSION set BOOST_ROOT=%RIME_ROOT%\deps\boost-%BOOST_VERSION%
)

rem architecture, Visual Studio version and platform toolset
set ARCH=Win32
set BJAM_TOOLSET=msvc-14.3
set CMAKE_GENERATOR="Visual Studio 17 2022"
set PLATFORM_TOOLSET=v143

rem OPTIONAL: path to additional build tools
rem set DEVTOOLS_PATH=%ProgramFiles%\Git\cmd;%ProgramFiles%\CMake\bin;C:\Python27;
