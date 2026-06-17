param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$flutterRoot = 'C:\Users\0219\flutter'
$dart = Join-Path $flutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
$packageConfig = Join-Path $flutterRoot 'packages\flutter_tools\.dart_tool\package_config.json'
$snapshot = Join-Path $flutterRoot 'bin\cache\flutter_tools.snapshot'
$lockPaths = @(
  (Join-Path $flutterRoot 'bin\cache\lockfile'),
  (Join-Path $flutterRoot 'bin\cache\flutter.bat.lock')
)

if (-not (Test-Path $dart)) {
  throw "找不到 Dart SDK: $dart"
}

if (-not (Test-Path $packageConfig)) {
  throw "找不到 package_config.json: $packageConfig"
}

if (-not (Test-Path $snapshot)) {
  throw "找不到 flutter_tools.snapshot: $snapshot"
}

# flutter.bat 在這個環境偶爾會留下 stale lock；若沒有活躍的 Flutter/Dart 行程就先清掉。
$activeFlutterProcesses = Get-Process -ErrorAction SilentlyContinue |
  Where-Object {
    $_.ProcessName -in @('dart', 'dartvm', 'flutter') -and
    $_.Path -like "$flutterRoot*"
  }

if (-not $activeFlutterProcesses) {
  foreach ($lockPath in $lockPaths) {
    if (Test-Path $lockPath) {
      Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
    }
  }
}

& $dart "--packages=$packageConfig" $snapshot @FlutterArgs
exit $LASTEXITCODE
