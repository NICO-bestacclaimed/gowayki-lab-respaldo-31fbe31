param([switch]$SeedOnly, [switch]$IncludeAuth)
$ErrorActionPreference = 'Stop'
$firebaseRepo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$firebaseTools = Join-Path (Split-Path $firebaseRepo -Parent) '.tools'
. (Join-Path (Split-Path $firebaseRepo -Parent) 'Entorno.ps1')
$env:XDG_CONFIG_HOME = Join-Path $firebaseTools 'firebase-config'
$env:XDG_CACHE_HOME = Join-Path $firebaseTools 'firebase-cache'
$env:FIREBASE_EMULATORS_PATH = Join-Path $firebaseTools 'firebase-emulators'
$env:npm_config_cache = Join-Path $firebaseTools 'npm-cache'
$env:NO_UPDATE_NOTIFIER = '1'
$firebaseCli = Join-Path $firebaseRepo 'tool/firebase/node_modules/firebase-tools/lib/bin/firebase.js'
if (!(Test-Path -LiteralPath $firebaseCli)) { throw 'Instala tool/firebase con npm ci antes de probar.' }
$firebaseTask = if ($SeedOnly) { 'node tool/firebase/seed.mjs' } elseif ($IncludeAuth) { 'node --test --test-concurrency=1 tool/firebase/auth.test.mjs tool/firebase/rules.test.mjs' } else { 'node --test --test-concurrency=1 tool/firebase/rules.test.mjs' }
$firebaseServices = if ($IncludeAuth) { 'firestore,auth' } else { 'firestore' }
Push-Location $firebaseRepo
try {
  & node.exe $firebaseCli emulators:exec --config firebase.json --project demo-gowayki-lab --only $firebaseServices --non-interactive $firebaseTask
  if ($LASTEXITCODE -ne 0) { throw "Fallaron pruebas Firebase locales: $LASTEXITCODE" }
} finally { Pop-Location }
