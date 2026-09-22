param(
    [Parameter(Position = 0)]
    [ValidateRange(1, 65535)]
    [int]$Port = 5078
)

$ErrorActionPreference = 'Stop'
$manager = Join-Path $PSScriptRoot 'manage-service.ps1'

& $manager -Action install -Port $Port
