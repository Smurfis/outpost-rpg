param([Parameter(Mandatory=$true)][string]$Godot)
$ErrorActionPreference = 'Stop'
$engine = (Resolve-Path $Godot).Path
$project = Split-Path $PSScriptRoot -Parent
$originalAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $env:TEMP ('outpost-renewal-' + [guid]::NewGuid())
    New-Item -ItemType Directory $env:APPDATA | Out-Null
    Write-Output "Isolated saves and logs: $env:APPDATA"
    foreach ($phase in 'prepare','publish','staged_fail','commit','reopen','reload') {
        $log = Join-Path $env:APPDATA "$phase.log"
        $marker = Join-Path $env:APPDATA "Godot/app_userdata/Outpost/$phase.checkpoint"
        $arguments = "--headless --fixed-fps 60 --log-file `"$log`" --script res://tests/mine_renewal.gd -- $phase"
        if ($phase -ne 'reload') { $arguments += ' interrupt' }
        $process = Start-Process $engine -WorkingDirectory $project -ArgumentList $arguments -WindowStyle Hidden -PassThru
        try {
            $until = [datetime]::UtcNow.AddSeconds(75)
            while (!$process.HasExited -and !(Test-Path -LiteralPath $marker) -and [datetime]::UtcNow -lt $until) {
                Start-Sleep -Milliseconds 100
            }
            if ($phase -ne 'reload') {
                if (!(Test-Path $marker) -or [int](Get-Content $marker) -ne $process.Id) { throw "Missing $phase checkpoint. See $log" }
                $process.Kill()
            }
            if (!$process.WaitForExit(5000)) { throw "Test timeout. See $log" }
            if (!(Select-String -LiteralPath $log -SimpleMatch "RENEWAL $phase true") -or (Select-String -LiteralPath $log -SimpleMatch 'SCRIPT ERROR')) {
                throw "Failed $phase verification. See $log"
            }
            Write-Output "Verified $phase"
        } finally {
            if (!$process.HasExited) { $process.Kill(); $process.WaitForExit() }
        }
    }
} finally {
    $env:APPDATA = $originalAppData
}
