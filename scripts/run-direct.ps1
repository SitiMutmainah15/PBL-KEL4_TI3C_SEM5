# Membangun dan memasang APK yang memanggil Groq langsung dari HP,
# tanpa backend dan tanpa laptop menyala setelah APK terpasang.
#
# Kunci dibaca dari backend/.env lalu disuntikkan lewat --dart-define,
# jadi kunci tidak pernah ditulis di kode sumber atau di-commit.
#
# Pemakaian:
#   .\scripts\run-direct.ps1                # build debug, pasang, jalankan
#   .\scripts\run-direct.ps1 -Release       # build APK release untuk dibagikan
param(
  [string]$Device,
  [switch]$Release
)

$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
$app = Join-Path $root "ecoplant"
$envFile = Join-Path $root "backend\.env"
$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"

if (-not (Test-Path $envFile)) {
  throw "backend\.env tidak ditemukan. Salin dari backend\.env.example lalu isi GROQ_API_KEY."
}

$values = @{}
foreach ($line in Get-Content $envFile) {
  if ($line -match '^\s*([A-Z_]+)\s*=\s*(.*)\s*$') { $values[$Matches[1]] = $Matches[2] }
}

$key = $values["GROQ_API_KEY"]
if (-not $key) { throw "GROQ_API_KEY kosong di backend\.env." }
$model = if ($values["GROQ_MODEL"]) { $values["GROQ_MODEL"] } else { "qwen/qwen3.8-27b" }

Write-Host "Mode: panggil Groq langsung ($model)"

$mode = if ($Release) { "release" } else { "debug" }

Push-Location $app
try {
  & flutter build apk "--$mode" "--dart-define=GROQ_API_KEY=$key" "--dart-define=GROQ_MODEL=$model"
  if ($LASTEXITCODE -ne 0) { throw "Build APK gagal." }

  $apk = "build\app\outputs\flutter-apk\app-$mode.apk"
  Write-Host "APK: $(Join-Path $app $apk)"

  if (Test-Path $adb) {
    $target = @()
    if ($Device) { $target = @("-s", $Device) }
    & $adb @target install -r $apk
    if ($LASTEXITCODE -eq 0) {
      & $adb @target shell am start -n com.example.ecoplant/.MainActivity | Out-Null
      Write-Host "Aplikasi terpasang dan dijalankan."
    } else {
      Write-Warning "Tidak ada HP terhubung. Salin APK di atas ke HP secara manual."
    }
  }
} finally {
  Pop-Location
}
