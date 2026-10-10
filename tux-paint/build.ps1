param(
  [string]$Emsdk = $env:EMSDK,
  [string]$BuildDir = "$PSScriptRoot\build"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$requiredInputs = @(
  "data",
  "starters",
  "templates",
  "stamps",
  "im",
  "osk",
  "data\fonts\default_font.ttf"
)

if (-not (Get-Command emcc -ErrorAction SilentlyContinue)) {
  if (-not $Emsdk) {
    throw "emcc was not found. Install and activate the Emscripten SDK, then rerun this script."
  }
  $emsdkEnv = Join-Path $Emsdk "emsdk_env.ps1"
  if (-not (Test-Path $emsdkEnv)) {
    throw "EMSDK does not point to an Emscripten SDK: $Emsdk"
  }
  . $emsdkEnv
}

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
Push-Location $root
try {
  $gperf = Get-Command gperf -ErrorAction SilentlyContinue
  if (-not $gperf) {
    $gperf = Get-Item "C:\Program Files (x86)\GnuWin32\bin\gperf.exe" -ErrorAction SilentlyContinue
  }
  if (-not $gperf) { throw "gperf is required to generate the command-line parser." }
  foreach ($input in $requiredInputs) {
    $inputPath = Join-Path $root $input
    if (-not (Test-Path $inputPath)) {
      throw "Required web build input is missing: $inputPath"
    }
  }
  $generatedDir = Join-Path $BuildDir "generated"
  New-Item -ItemType Directory -Force -Path $generatedDir | Out-Null
  $gperfPath = if ($gperf.PSObject.Properties["Path"]) { $gperf.Path } else { $gperf.FullName }
  $parseStep1 = Join-Path $generatedDir "parse_step1.c"
  $parseSource = Join-Path $root "src\parse.gperf"
  & $gperfPath $parseSource | Out-File -Encoding ascii $parseStep1
  if ($LASTEXITCODE -ne 0) { throw "gperf source generation failed." }
  $parseFile = Join-Path $generatedDir "parse.c"
  (Get-Content $parseStep1 -Raw) `
    -replace '^const struct', 'static const struct' `
    -replace '_GNU', '_TUX' |
    Set-Content -Encoding ascii $parseFile
  $magicHeader = @(
    "/* Generated from src/tp_magic_api.h.in for the web build. */"
    (Get-Content (Join-Path $root "src\tp_magic_api.h.in") -Raw)
  ) -join "`r`n"
  $magicHeader -replace '__APIVERSION__', '0x0000000B' |
    Set-Content -Encoding ascii (Join-Path $generatedDir "tp_magic_api.h")

  $sources = @(
    "src/tuxpaint.c", "src/i18n.c", "src/im.c", "src/cursor.c",
    "src/pixels.c", "src/rgblinear.c", "src/playsound.c", "src/fonts.c",
    $parseFile, "src/fill.c", "src/progressbar.c", "src/dirwalk.c",
    "src/get_fname.c", "src/onscreen_keyboard.c", "src/gifenc.c",
    "src/sounds.c", "web/compat/web_compat.c", "web/compat/web_print.c"
  )
  $emccArgs = @(
    "-O2", "-g0", "-DNOSVG", "-DTRUE=1", "-DFALSE=0", "-DHAVE_STRCASESTR",
    '-DVER_VERSION=\"0.9.35\"', '-DVER_DATE=\"2025-05-26\"',
    '-DLOCALEDIR=\"/data/locale/\"', '-DDATA_PREFIX=\"/data/\"',
    '-DDOC_PREFIX=\"/data/docs/\"', '-DIMDIR=\"/data/im/\"',
    '-DCONFDIR=\"/data/\"', '-DMAGIC_PREFIX=\"/data/plugins/\"',
    "-I$generatedDir", "-I$root\src", "-I$root\src\mouse", "-I$root\web\compat",
    "-sUSE_SDL=2", "-sUSE_SDL_IMAGE=2", "-sSDL2_IMAGE_FORMATS=['png','jpg','jpeg']",
    "-sUSE_SDL_TTF=2",
    "-sUSE_SDL_MIXER=2", "-sUSE_LIBPNG=1", "-sALLOW_MEMORY_GROWTH=1", "-sINITIAL_MEMORY=256MB",
    "-sFORCE_FILESYSTEM=1", "-sASYNCIFY=1", "-sASYNCIFY_STACK_SIZE=1048576",
    "-sEXPORTED_RUNTIME_METHODS=['FS']",
    "--preload-file", "data@/data",
    "--preload-file", "starters@/data/starters",
    "--preload-file", "templates@/data/templates",
    "--preload-file", "stamps@/data/stamps",
    "--preload-file", "im@/data/im",
    "--preload-file", "osk@/data/osk",
    "-o", "$BuildDir\tuxpaint.js"
  )
  & emcc $emccArgs $sources
  if ($LASTEXITCODE -ne 0) { throw "Emscripten compilation failed." }
  Copy-Item (Join-Path $PSScriptRoot "index.html") (Join-Path $BuildDir "index.html") -Force
  foreach ($artifact in @("index.html", "tuxpaint.js", "tuxpaint.wasm", "tuxpaint.data")) {
    if (-not (Test-Path (Join-Path $BuildDir $artifact))) {
      throw "Web build did not produce the expected artifact: $artifact"
    }
  }
} finally {
  Pop-Location
}
