param(
    [string]$GodotPath = 'C:\Godot\godot.exe',
    [string]$PythonPath = 'python',
    [switch]$HeadlessOnly
)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runner = Join-Path $PSScriptRoot 'run_regressions.py'
$arguments = @($runner, '--godot', $GodotPath, '--output', (Join-Path $projectPath '.qa/regressions'))
if (-not $HeadlessOnly) { $arguments += '--graphical' }
& $PythonPath @arguments
exit $LASTEXITCODE
