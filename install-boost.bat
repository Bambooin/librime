setlocal

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

if not defined boost_version for /f "usebackq tokens=1,* delims==" %%A in (`findstr /b /c:"version=" "%BOOST_DATA_FILE%"`) do if not defined boost_version set boost_version=%%B
if not defined boost_sha256sum for /f "usebackq tokens=1,* delims==" %%A in (`findstr /b /c:"sha256sum=" "%BOOST_DATA_FILE%"`) do if not defined boost_sha256sum set boost_sha256sum=%%B

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
