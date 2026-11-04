param(
    [string]$GodotPath = 'C:\Godot\godot.exe',
    [string]$PythonPath = 'python',
    [switch]$HeadlessOnly
)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not (Test-Path -LiteralPath $GodotPath)) { throw "Godot executable not found: $GodotPath" }
$oldAppData = $env:APPDATA
$oldTemp = $env:TEMP
$oldTmp = $env:TMP
$oldLocalAppData = $env:LOCALAPPDATA
$results = @()
function Invoke-GodotCheck([string]$Name, [string[]]$Arguments) {
    $logPath = Join-Path $projectPath "validation/$Name.log"
    $env:APPDATA = Join-Path $projectPath ".validation_appdata/$Name"
    New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
    $env:TEMP = Join-Path $env:APPDATA 'temp'
    $env:TMP = $env:TEMP
    $env:LOCALAPPDATA = Join-Path $env:APPDATA 'local'
    New-Item -ItemType Directory -Force -Path $env:TEMP | Out-Null
    New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA | Out-Null
    $argumentsList = @('--path', ('"' + $projectPath + '"'), '--log-file', ('"' + $logPath + '"')) + $Arguments
    $proc = Start-Process -FilePath $GodotPath -ArgumentList $argumentsList -WindowStyle Hidden -PassThru
    if (-not $proc.WaitForExit(90000)) { $proc.Kill(); throw "$Name exceeded 90 seconds" }
    $proc.Refresh()
    $log = Get-Content -LiteralPath $logPath -Raw
    if ($proc.ExitCode -ne 0 -or $log -match 'SCRIPT ERROR:|ERROR:|\bFAIL\b') { throw "$Name failed (exit $($proc.ExitCode)). See $logPath" }
    Write-Output "$Name passed"
}
try {
    Invoke-GodotCheck 'import' @('--headless','--editor','--quit')
    foreach ($entry in @('test_audio_realism','test_career_save_migration','test_career_economy_sim','test_championships','test_advanced_tuning','test_audio_profiles','test_ai_progression','benchmark_roster','test_roster','test_physics','test_transmissions','benchmark_transmissions','benchmark_drag_tuning','test_parameters','test_upgrade_model','test_visual_effects','test_customization','test_quality_model','test_staging','test_polish','test_audio','export_audio_demo','test_rival','test_career','test_economy','run_calibration','export_telemetry')) {
        Invoke-GodotCheck $entry @('--headless','--script',"tests/$entry.gd")
        $results += @{test=$entry;passed=$true}
    }
    if (-not $HeadlessOnly) {
        foreach ($entry in @('test_native_workshop','test_audio_steady_loops','test_vehicle_presentation','test_championships_ui','test_tuning_lab_ui','test_race_hud','test_dealer_classes_ui','test_dynamic_audio','test_audio_lab_ui','test_race_distance_camera','test_rim_rendering','test_ai_start_ui','test_roster_ui','test_quality_pass','test_qol_ui','test_upgrade_studio_ui','test_glass_ui','test_controls','test_visual_rendering','test_strip_rendering','test_customization_ui','test_quality_ui','test_dealership','test_garage_hub','test_upgrades_ui','test_menus','test_flow','test_runtime','test_shutdown')) {
            Invoke-GodotCheck $entry @('--script',"tests/$entry.gd")
            $results += @{test=$entry;passed=$true}
        }
    }
    & $PythonPath (Join-Path $PSScriptRoot 'analyze_validation.py')
    if ($LASTEXITCODE -ne 0) { throw 'Reference or audio analysis failed' }
    & $PythonPath (Join-Path $PSScriptRoot 'analyze_transmissions.py')
    if ($LASTEXITCODE -ne 0) { throw 'Transmission comparison failed' }
    & $PythonPath (Join-Path $PSScriptRoot 'analyze_career.py')
    if ($LASTEXITCODE -ne 0) { throw 'Career calibration failed' }
    if (-not $HeadlessOnly) {
        & $PythonPath (Join-Path $PSScriptRoot 'analyze_dealership.py')
        if ($LASTEXITCODE -ne 0) { throw 'Dealership analysis failed' }
    }
    @{godot=$GodotPath;headless_only=[bool]$HeadlessOnly;tests=$results;passed=$true} | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 (Join-Path $projectPath 'validation/suite_results.json')
    Write-Output 'Racing validation passed.'
} finally { $env:APPDATA = $oldAppData; $env:TEMP = $oldTemp; $env:TMP = $oldTmp; $env:LOCALAPPDATA = $oldLocalAppData }















