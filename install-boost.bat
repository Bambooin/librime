setlocal

if not defined RIME_ROOT set RIME_ROOT=%CD%
for %%I in ("%RIME_ROOT%\.") do set "RIME_ROOT=%%~fI"
set "BOOST_VERSION_ROOT=%RIME_ROOT%"
:find_boost_version
if exist "%BOOST_VERSION_ROOT%\boost-version" goto boost_version_found
for %%I in ("%BOOST_VERSION_ROOT%\..") do set "BOOST_VERSION_PARENT=%%~fI"
if /i "%BOOST_VERSION_PARENT%"=="%BOOST_VERSION_ROOT%" goto try_script_dir
set "BOOST_VERSION_ROOT=%BOOST_VERSION_PARENT%"
goto find_boost_version
:try_script_dir
if exist "%~dp0boost-version" for %%I in ("%~dp0.") do set "BOOST_VERSION_ROOT=%%~fI"
if not exist "%BOOST_VERSION_ROOT%\boost-version" (
  echo Error: boost-version not found in %RIME_ROOT%.
  exit /b 1
)
:boost_version_found
set "RIME_ROOT=%BOOST_VERSION_ROOT%"

if not defined boost_version for /f "tokens=1,* delims==" %%A in ('findstr /b "boost_version=" "%RIME_ROOT%\boost-version"') do if /i "%%A"=="boost_version" if not defined boost_version set "boost_version=%%B"
if not defined boost_version (
  echo Error: could not read boost_version from %RIME_ROOT%\boost-version.
  exit /b 1
)

if not defined boost_tarball set boost_tarball=boost_%boost_version:.=_%

if not defined BOOST_ROOT set BOOST_ROOT=%RIME_ROOT%\deps\boost-%boost_version%

if exist "%BOOST_ROOT%\libs" goto boost_found
for %%I in ("%BOOST_ROOT%\.") do set src_dir=%%~dpI
rem download boost source
aria2c https://archives.boost.io/release/%boost_version%/source/%boost_tarball%.7z -d %src_dir%
pushd %src_dir%
7z x %boost_tarball%.7z
ren %boost_tarball% boost-%boost_version%
cd boost-%boost_version%
call .\bootstrap.bat
.\b2 headers
popd
:boost_found
