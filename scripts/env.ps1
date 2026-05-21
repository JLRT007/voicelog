$ProjectRoot = Split-Path -Parent $PSScriptRoot
$FlutterBin = Join-Path $ProjectRoot ".toolchain\flutter\bin"
$AndroidSdk = "C:\Users\86198\AppData\Local\Android\Sdk"

$env:Path = "$FlutterBin;$AndroidSdk\platform-tools;$AndroidSdk\cmdline-tools\latest\bin;$env:Path"
$env:PUB_CACHE = Join-Path $ProjectRoot ".pub-cache"
$env:GRADLE_USER_HOME = Join-Path $ProjectRoot ".gradle"
$env:npm_config_cache = Join-Path $ProjectRoot ".npm-cache"
$env:ANDROID_HOME = $AndroidSdk
$env:ANDROID_SDK_ROOT = $AndroidSdk

$LocalEnv = Join-Path $ProjectRoot ".env.local"
if (Test-Path $LocalEnv) {
  Get-Content $LocalEnv | ForEach-Object {
    if ($_ -match "^\s*#" -or $_ -notmatch "=") { return }
    $name, $value = $_ -split "=", 2
    [Environment]::SetEnvironmentVariable($name.Trim(), $value.Trim(), "Process")
  }
}

function Invoke-VoiceLogFlutter {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Args
  )

  Push-Location (Join-Path $ProjectRoot "app")
  try {
    if ($Args.Count -gt 0 -and $Args[0] -in @("run", "test", "build")) {
      $command = $Args[0]
      $rest = @()
      if ($Args.Count -gt 1) {
        $rest = $Args[1..($Args.Count - 1)]
      }
      $dartDefines = @()
      if ($env:DEEPSEEK_API_KEY) {
        $dartDefines += "--dart-define=DEEPSEEK_API_KEY=$env:DEEPSEEK_API_KEY"
      }
      if ($env:DEEPSEEK_BASE_URL) {
        $dartDefines += "--dart-define=DEEPSEEK_BASE_URL=$env:DEEPSEEK_BASE_URL"
      }
      if ($command -eq "build" -and $rest.Count -gt 0) {
        $target = $rest[0]
        $targetRest = @()
        if ($rest.Count -gt 1) {
          $targetRest = $rest[1..($rest.Count - 1)]
        }
        flutter --no-version-check $command $target @dartDefines @targetRest
      } else {
        flutter --no-version-check $command @dartDefines @rest
      }
    } else {
      flutter --no-version-check @Args
    }
  } finally {
    Pop-Location
  }
}

Write-Host "VoiceLog environment loaded."
Write-Host "Use: Invoke-VoiceLogFlutter run"
