setlocal

if not defined RIME_ROOT set RIME_ROOT=%CD%
if not exist "%RIME_ROOT%\boost-version" (
  if exist "%~dp0boost-version" for %%I in ("%~dp0.") do set RIME_ROOT=%%~fI
)
if not exist "%RIME_ROOT%\boost-version" (
  echo Error: boost-version not found in %RIME_ROOT%.
  exit /b 1
)

if not defined boost_version for /f "usebackq delims=" %%I in ("%RIME_ROOT%\boost-version") do if not defined boost_version set boost_version=%%I

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
