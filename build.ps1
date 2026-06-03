# Bundles the modular DexUI source tree into single-file artifacts the executor
# can loadstring. Requires darklua (see rokit.toml) on PATH.
#
#   ./build.ps1            # build library + demo
#   ./build.ps1 -Minify    # also minify the output
#   ./build.ps1 -Stage     # also copy bundles into the Volt executor workspace
param(
	[switch]$Minify,
	[switch]$Stage,
	[string]$StageDir = "$env:LOCALAPPDATA\Volt\workspace\DexUI"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
Push-Location $root

if (-not (Get-Command darklua -ErrorAction SilentlyContinue)) {
	$cargoBin = Join-Path $env:USERPROFILE ".cargo\bin"
	if (Test-Path (Join-Path $cargoBin "darklua.exe")) {
		$env:Path += ";$cargoBin"
	} else {
		throw "darklua not found. Install it with 'rokit install' or 'cargo install darklua'."
	}
}

New-Item -ItemType Directory -Force -Path "dist" | Out-Null

Write-Host "Bundling dist/dexui.lua ..."
darklua process src/init.luau dist/dexui.lua

Write-Host "Bundling dist/demo.lua ..."
darklua process src/demo.luau dist/demo.lua

Write-Host "Bundling dist/hub.lua ..."
darklua process src/hub-main.luau dist/hub.lua

if ($Minify) {
	Write-Host "Minifying ..."
	darklua minify dist/dexui.lua dist/dexui.min.lua
	darklua minify dist/demo.lua dist/demo.min.lua
}

if ($Stage) {
	Write-Host "Staging bundles into $StageDir ..."
	New-Item -ItemType Directory -Force -Path $StageDir | Out-Null
	Copy-Item dist/dexui.lua (Join-Path $StageDir "dexui.lua") -Force
	Copy-Item dist/demo.lua (Join-Path $StageDir "demo.lua") -Force
	Copy-Item dist/hub.lua (Join-Path $StageDir "hub.lua") -Force
	if (Test-Path "scripts") {
		$scriptsDest = Join-Path $StageDir "scripts"
		New-Item -ItemType Directory -Force -Path $scriptsDest | Out-Null
		Copy-Item scripts\* $scriptsDest -Recurse -Force
	}
	if (Test-Path "scripts/tools") {
		$toolsDest = Join-Path $StageDir "scripts/tools"
		New-Item -ItemType Directory -Force -Path $toolsDest | Out-Null
		Copy-Item scripts/tools\* $toolsDest -Recurse -Force
	}
	if (Test-Path "assets") {
		$assetsDest = Join-Path $StageDir "assets"
		New-Item -ItemType Directory -Force -Path $assetsDest | Out-Null
		Copy-Item assets\* $assetsDest -Recurse -Force
	}
}

Write-Host "Done."
Pop-Location
