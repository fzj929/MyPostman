param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('install', 'uninstall', 'start', 'stop', 'restart', 'status', 'run')]
    [string]$Action,

    [Parameter(Position = 1)]
    [ValidateRange(1, 65535)]
    [int]$Port = 5078
)

$ErrorActionPreference = 'Stop'
$serviceName = 'MyPostman'
$projectRoot = Split-Path -Parent $PSScriptRoot
$webProject = Join-Path $projectRoot 'MyPostman.Web'
$apiProject = Join-Path $projectRoot 'MyPostman.Api/MyPostman.Api.csproj'
$installDirectory = Join-Path $env:ProgramFiles 'MyPostman'
$dataDirectory = Join-Path $env:ProgramData 'MyPostman'
$listenUrl = "http://127.0.0.1:$Port"

function Invoke-CheckedCommand {
    param([string]$File, [string[]]$Arguments)
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$File failed with exit code $LASTEXITCODE."
    }
}

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Please run this command from an elevated PowerShell window.'
    }
}

function Get-InstalledService {
    Get-Service -Name $serviceName -ErrorAction SilentlyContinue
}

function Stop-InstalledService {
    $service = Get-InstalledService
    if ($service -and $service.Status -ne 'Stopped') {
        Stop-Service -Name $serviceName
        $service.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
    }
}

switch ($Action) {
    'install' {
        Assert-Administrator
        Invoke-CheckedCommand 'npm.cmd' @('ci', '--prefix', $webProject)
        Invoke-CheckedCommand 'npm.cmd' @('run', 'build', '--prefix', $webProject)
        Stop-InstalledService
        New-Item -ItemType Directory -Path $installDirectory, $dataDirectory -Force | Out-Null
        Invoke-CheckedCommand 'dotnet' @('publish', $apiProject, '-c', 'Release', '-o', $installDirectory)

        # LocalService must be able to create and update its SQLite database.
        Invoke-CheckedCommand 'icacls.exe' @($dataDirectory, '/grant', '*S-1-5-19:(OI)(CI)M', '/T')
        $executable = Join-Path $installDirectory 'MyPostman.Api.exe'
        if (-not (Get-InstalledService)) {
            New-Service -Name $serviceName -DisplayName 'MyPostman API Workspace' -BinaryPathName "`"$executable`"" -StartupType Automatic | Out-Null
        }
        Invoke-CheckedCommand 'sc.exe' @('config', $serviceName, "binPath= `"$executable`"", 'start= auto', 'obj= NT AUTHORITY\LocalService', 'password= ')
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName"
        New-ItemProperty -Path $registryPath -Name Environment -PropertyType MultiString -Value @(
            "MyPostman__DataDirectory=$dataDirectory",
            "MyPostman__ListenUrl=$listenUrl"
        ) -Force | Out-Null
        Start-Service -Name $serviceName
        (Get-Service -Name $serviceName).WaitForStatus('Running', [TimeSpan]::FromSeconds(30))
        Write-Host "MyPostman is running at $listenUrl"
        Write-Host "Data directory: $dataDirectory"
    }
    'uninstall' {
        Assert-Administrator
        if (Get-InstalledService) {
            Stop-InstalledService
            Invoke-CheckedCommand 'sc.exe' @('delete', $serviceName)
            Write-Host "Service $serviceName removed. Published files and data were preserved."
        } else {
            Write-Host "Service $serviceName is not installed."
        }
    }
    'start' {
        Assert-Administrator
        Start-Service -Name $serviceName
        Get-Service -Name $serviceName
    }
    'stop' {
        Assert-Administrator
        Stop-InstalledService
        Get-Service -Name $serviceName
    }
    'restart' {
        Assert-Administrator
        Stop-InstalledService
        Start-Service -Name $serviceName
        Get-Service -Name $serviceName
    }
    'status' {
        $service = Get-InstalledService
        if ($service) { $service | Format-List Name, DisplayName, Status, StartType }
        else { Write-Host "Service $serviceName is not installed." }
    }
    'run' {
        Invoke-CheckedCommand 'npm.cmd' @('ci', '--prefix', $webProject)
        Invoke-CheckedCommand 'npm.cmd' @('run', 'build', '--prefix', $webProject)
        $env:MyPostman__ListenUrl = $listenUrl
        Write-Host "Running MyPostman in the foreground at $listenUrl (Ctrl+C to stop)."
        Invoke-CheckedCommand 'dotnet' @('run', '--project', $apiProject, '--no-launch-profile')
    }
}
