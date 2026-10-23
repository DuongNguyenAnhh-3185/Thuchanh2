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
  set "SUPABASE_PUBLISHABLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lbWxob3FwdGdyZ3R3YW96bWd1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2MDk2MzYsImV4cCI6MjEwODE4NTYzNn0.kH6Z5FlyCvlU1EEuZc2v9_baYxzFSFLJCjZvoCldyIA"
)
call flutter pub get
if errorlevel 1 (
  popd
  exit /b 1
)
call flutter run -d chrome --web-port=7357 --dart-define-from-file=.env.json %*
set "RUN_RESULT=%ERRORLEVEL%"
popd
exit /b %RUN_RESULT%
