$ErrorActionPreference = 'Stop'
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

$adb = 'C:\Users\kauas\AppData\Local\Android\sdk\platform-tools\adb.exe'
& $adb -s ZF524V3256 reverse tcp:8080 tcp:8080

flutter run `
  -d ZF524V3256 `
  --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/mobile
