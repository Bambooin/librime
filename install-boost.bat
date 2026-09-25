setlocal EnableDelayedExpansion

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

for /f "tokens=1,* delims==" %%A in ('findstr /b "boost_version=" "%RIME_ROOT%\boost-version"') do if /i "%%A"=="boost_version" if not defined boost_version_from_file set "boost_version_from_file=%%B"
if defined boost_version_from_file for /f %%I in ("%boost_version_from_file%") do set "boost_version_from_file=%%~I"
if not defined boost_version_from_file (
  echo Error: could not read boost_version from %RIME_ROOT%\boost-version.
  exit /b 1
)
for /f "tokens=1,* delims==" %%A in ('findstr /b "boost_sha256=" "%RIME_ROOT%\boost-version"') do if /i "%%A"=="boost_sha256" if not defined boost_sha256_from_file set "boost_sha256_from_file=%%B"
if defined boost_sha256_from_file for /f %%I in ("%boost_sha256_from_file%") do set "boost_sha256_from_file=%%~I"
if not defined boost_sha256_from_file (
  echo Error: could not read boost_sha256 from %RIME_ROOT%\boost-version.
  exit /b 1
)
if not defined boost_version set "boost_version=%boost_version_from_file%"
if defined boost_version for /f %%I in ("%boost_version%") do set "boost_version=%%~I"
if /i not "%boost_version%"=="%boost_version_from_file%" if not defined boost_sha256 (
  echo Error: boost_sha256 must be set when boost_version differs from %RIME_ROOT%\boost-version.
  exit /b 1
)
if not defined boost_sha256 set "boost_sha256=%boost_sha256_from_file%"
if defined boost_sha256 for /f %%I in ("%boost_sha256%") do set "boost_sha256=%%~I"
set "boost_sha256=!boost_sha256:a=A!"
set "boost_sha256=!boost_sha256:b=B!"
set "boost_sha256=!boost_sha256:c=C!"
set "boost_sha256=!boost_sha256:d=D!"
set "boost_sha256=!boost_sha256:e=E!"
set "boost_sha256=!boost_sha256:f=F!"

if not defined boost_tarball set "boost_tarball=boost_%boost_version:.=_%"
if not defined boost_archive set "boost_archive=%boost_tarball%.tar.gz"

if not defined BOOST_ROOT set BOOST_ROOT=%RIME_ROOT%\deps\boost-%boost_version%
set "managed_boost_root=%RIME_ROOT%\deps\boost-%boost_version%"

if exist "%BOOST_ROOT%\libs" goto boost_found
if /i not "%BOOST_ROOT%"=="%managed_boost_root%" if exist "%BOOST_ROOT%" (
  echo Error: could not repair existing external BOOST_ROOT at %BOOST_ROOT%.
  exit /b 1
)
for %%I in ("%BOOST_ROOT%\.") do set src_dir=%%~dpI
rem download boost source
if not exist "%src_dir%%boost_archive%" (
  aria2c https://archives.boost.io/release/%boost_version%/source/%boost_archive% -d "%src_dir%" -o "%boost_archive%"
  if errorlevel 1 exit /b %errorlevel%
)
pushd "%src_dir%"
set "archive_sha256="
for /f "tokens=* delims= " %%I in ('certutil -hashfile "%src_dir%%boost_archive%" SHA256 ^| findstr /r "^[0-9A-Fa-f][0-9A-Fa-f]"') do set "archive_sha256=%%I"
set "archive_sha256=!archive_sha256: =!"
set "archive_sha256=!archive_sha256:a=A!"
set "archive_sha256=!archive_sha256:b=B!"
set "archive_sha256=!archive_sha256:c=C!"
set "archive_sha256=!archive_sha256:d=D!"
set "archive_sha256=!archive_sha256:e=E!"
set "archive_sha256=!archive_sha256:f=F!"
if not defined archive_sha256 (
  echo Error: could not compute SHA-256 for %src_dir%%boost_archive%.
  popd
  exit /b 1
)
if /i not "!archive_sha256!"=="!boost_sha256!" (
  del /f /q "%src_dir%%boost_archive%"
  echo Error: SHA-256 mismatch for %boost_archive%.
  popd
  exit /b 1
)
if exist "%boost_tarball%" rmdir /s /q "%boost_tarball%"
where tar >nul 2>nul || (
  echo Error: tar not found.
  popd
  exit /b 1
)
tar -xzf "%boost_archive%"
if errorlevel 1 (
  popd
  exit /b %errorlevel%
)
if not exist "%boost_tarball%" (
  echo Error: could not extract %boost_tarball% from %boost_archive%.
  popd
  exit /b 1
)
if /i "%BOOST_ROOT%"=="%managed_boost_root%" (
  if exist "boost-%boost_version%" rmdir /s /q "boost-%boost_version%"
  ren "%boost_tarball%" "boost-%boost_version%"
) else (
  for %%I in ("%BOOST_ROOT%\..") do set "boost_root_parent=%%~fI"
  if not exist "!boost_root_parent!" mkdir "!boost_root_parent!"
  move "%boost_tarball%" "%BOOST_ROOT%" >nul
)
cd "%BOOST_ROOT%"
call .\bootstrap.bat
.\b2 headers
popd
:boost_found
