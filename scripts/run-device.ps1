# Membangun dan memasang APK ke HP fisik, dengan alamat backend diisi
# otomatis dari IP LAN komputer ini.
#
# Latar belakang: alamat bawaan aplikasi adalah 10.0.2.2, yang hanya berlaku di
# emulator Android. Di HP fisik alamat itu tidak menuju ke komputer mana pun,
# sehingga layar hasil berhenti di "Menyusun keterangan kondisi daun".
#
# Pemakaian:
#   .\scripts\run-device.ps1                 # deteksi IP, build, pasang, jalankan
#   .\scripts\run-device.ps1 -Port 8080 -SkipInstall
param(
  [int]$Port = 8080,
  [string]$Device,
  [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
$app = Join-Path $root "ecoplant"
$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"

if (-not (Test-Path $adb)) {
  throw "adb tidak ditemukan di $adb. Pasang Android SDK platform-tools dulu."
}

# Pilih antarmuka yang dipakai Wi-Fi. Ethernet ikut dipertimbangkan bila
# perangkat terhubung lewat kabel.
$candidates = Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object {
    $_.IPAddress -notlike "127.*" -and
    $_.IPAddress -notlike "169.254.*" -and
    $_.InterfaceAlias -notlike "*VMware*" -and
    $_.InterfaceAlias -notlike "*VirtualBox*"
  } |
  Sort-Object { if ($_.InterfaceAlias -like "*Wi-Fi*") { 0 } else { 1 } }

if (-not $candidates) {
  throw "Tidak ada alamat IPv4 yang bisa dipakai. Sambungkan Wi-Fi atau kabel dulu."
}

$ip = $candidates[0].IPAddress
$baseUrl = "http://${ip}:${Port}"

Write-Host "Alamat backend: $baseUrl ($($candidates[0].InterfaceAlias))"

# Ingatkan bila backend belum menyala, karena gejalanya sama dengan alamat salah.
$listening = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if (-not $listening) {
  Write-Warning "Tidak ada yang mendengarkan di port $Port. Jalankan backend dulu:"
  Write-Host "  cd backend; ..\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port $Port"
}

Push-Location $app
try {
  if (-not $SkipInstall) {
    & flutter build apk --debug --no-pub "--dart-define=ECOPLANT_API_BASE_URL=$baseUrl"
    if ($LASTEXITCODE -ne 0) { throw "Build APK gagal." }

    $target = @()
    if ($Device) { $target = @("-s", $Device) }
    & $adb @target install -r "build\app\outputs\flutter-apk\app-debug.apk"
    if ($LASTEXITCODE -ne 0) { throw "Pemasangan APK gagal." }
  }

  & $adb @target shell am start -n com.example.ecoplant/.MainActivity | Out-Null
  Write-Host "Aplikasi dijalankan. Alamat yang dipakai: $baseUrl"
} finally {
  Pop-Location
}
