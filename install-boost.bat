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
if not defined boost_sha256 for /f "tokens=1,* delims==" %%A in ('findstr /b "boost_sha256=" "%RIME_ROOT%\boost-version"') do if /i "%%A"=="boost_sha256" if not defined boost_sha256 set "boost_sha256=%%B"
if not defined boost_sha256 (
  echo Error: could not read boost_sha256 from %RIME_ROOT%\boost-version.
  exit /b 1
)

if not defined boost_tarball set "boost_tarball=boost_%boost_version:.=_%"
if not defined boost_archive set "boost_archive=%boost_tarball%.tar.gz"

if not defined BOOST_ROOT set BOOST_ROOT=%RIME_ROOT%\deps\boost-%boost_version%

if exist "%BOOST_ROOT%\libs" goto boost_found
for %%I in ("%BOOST_ROOT%\.") do set src_dir=%%~dpI
rem download boost source
aria2c https://archives.boost.io/release/%boost_version%/source/%boost_archive% -d "%src_dir%"
if errorlevel 1 exit /b %errorlevel%
pushd "%src_dir%"
for /f %%I in ('powershell -NoProfile -Command "(Get-FileHash -Algorithm SHA256 ''%src_dir%%boost_archive%'').Hash.ToLower()"') do set archive_sha256=%%I
if /i not "%archive_sha256%"=="%boost_sha256%" (
  echo Error: SHA-256 mismatch for %boost_archive%.
  exit /b 1
)
if exist "%boost_tarball%" rmdir /s /q "%boost_tarball%"
tar -xzf "%boost_archive%"
if not exist "%boost_tarball%" (
  echo Error: could not extract %boost_tarball% from %boost_archive%.
  exit /b 1
)
if exist "boost-%boost_version%" rmdir /s /q "boost-%boost_version%"
ren "%boost_tarball%" "boost-%boost_version%"
cd "boost-%boost_version%"
call .\bootstrap.bat
.\b2 headers
popd
:boost_found
