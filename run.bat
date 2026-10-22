@echo off
setlocal
pushd "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter is not available in PATH.
  popd
  exit /b 1
)
set "SUPABASE_URL=https://oemlhoqptgrgtwaozmgu.supabase.co"
if not defined SUPABASE_PUBLISHABLE_KEY (
  set /p "SUPABASE_PUBLISHABLE_KEY=Enter Supabase publishable key: "
)
if not defined SUPABASE_PUBLISHABLE_KEY (
  echo Supabase publishable key is required.
  popd
  exit /b 1
)
call flutter pub get
if errorlevel 1 (
  popd
  exit /b 1
)
call flutter run -d chrome --web-port=7357 --dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_PUBLISHABLE_KEY=%SUPABASE_PUBLISHABLE_KEY% %*
set "RUN_RESULT=%ERRORLEVEL%"
popd
exit /b %RUN_RESULT%
