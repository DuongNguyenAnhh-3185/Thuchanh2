@echo off
setlocal
pushd "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter is not available in PATH.
  popd
  exit /b 1
)
if not defined SUPABASE_URL set "SUPABASE_URL=https://oemlhoqptgrgtwaozmgu.supabase.co"
set "CLOUD_ARGS=--dart-define=SUPABASE_URL=%SUPABASE_URL%"
if defined SUPABASE_PUBLISHABLE_KEY (
  set "CLOUD_ARGS=%CLOUD_ARGS% --dart-define=SUPABASE_PUBLISHABLE_KEY=%SUPABASE_PUBLISHABLE_KEY%"
) else (
  echo Using the project publishable key configured in SupabaseConfig.
)
if defined FCM_WEB_VAPID_KEY set "CLOUD_ARGS=%CLOUD_ARGS% --dart-define=FCM_WEB_VAPID_KEY=%FCM_WEB_VAPID_KEY%"
call flutter pub get
if errorlevel 1 (
  popd
  exit /b 1
)
call flutter run -d chrome --web-port=7357 %CLOUD_ARGS% %*
set "RUN_RESULT=%ERRORLEVEL%"
popd
exit /b %RUN_RESULT%
