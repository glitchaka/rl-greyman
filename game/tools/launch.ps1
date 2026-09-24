$ErrorActionPreference = 'Stop'
$projectPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$enginePath = [System.IO.Path]::GetFullPath((Join-Path $projectPath '..\godot\Godot_v4.7.2-stable_win64.exe'))
if (-not (Test-Path -LiteralPath $enginePath)) { throw 'No se encuentra el Godot incluido.' }

# Ask only this project's running game to close normally. Its notification
# saves the expedition. Never terminate the editor or force-kill a process.
$instances = Get-CimInstance Win32_Process -Filter "Name='Godot_v4.7.2-stable_win64.exe'"
foreach ($instance in $instances) {
    $arguments = [string]$instance.CommandLine
    if ($arguments.IndexOf($projectPath, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
    if ($arguments -match '--editor|--script') { continue }
    $runningGame = Get-Process -Id $instance.ProcessId -ErrorAction SilentlyContinue
    if ($null -eq $runningGame) { continue }
    if (-not $runningGame.CloseMainWindow() -or -not $runningGame.WaitForExit(10000)) {
        throw 'Cierra la ventana anterior para guardar la partida y vuelve a abrir Jugar.'
    }
}
Start-Process -FilePath $enginePath -ArgumentList @('--path', ('"' + $projectPath + '"')) -WorkingDirectory $projectPath
