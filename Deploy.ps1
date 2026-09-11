# ============================================================
# DeployForge - Windows Software Deployment
# Version 1.0
# ============================================================

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigFile = Join-Path $ScriptRoot "config.yaml"
$InstallerRoot = Join-Path $ScriptRoot "installers"
$LogRoot = Join-Path $ScriptRoot "logs"

if (!(Test-Path $LogRoot)) {
    New-Item -ItemType Directory -Path $LogRoot | Out-Null
}

$ComputerName = $env:COMPUTERNAME
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

$LogFile = Join-Path $LogRoot "$ComputerName-$Timestamp.log"

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------

function Write-Log {
    param (
        [string]$Message
    )

    $Time = Get-Date -Format "HH:mm:ss"
    $Line = "[$Time] $Message"

    Write-Host $Line
    Add-Content -Path $LogFile -Value $Line
}

# ------------------------------------------------------------
# Administrator Check
# ------------------------------------------------------------

$CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)

if (-not $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {

    Write-Host ""
    Write-Host "ERROR: DeployForge must be run as Administrator." -ForegroundColor Red
    Write-Host ""

    Read-Host "Press Enter to exit"
    exit 1
}

# ------------------------------------------------------------
# Start
# ------------------------------------------------------------

Clear-Host

Write-Host "==============================================="
Write-Host "           DEPLOYFORGE v1.0"
Write-Host "==============================================="
Write-Host ""

Write-Log "Deployment started"
Write-Log "Computer: $ComputerName"
Write-Log "Deployment directory: $ScriptRoot"

# ------------------------------------------------------------
# Check configuration
# ------------------------------------------------------------

if (!(Test-Path $ConfigFile)) {
    Write-Log "ERROR: config.yaml not found."
    exit 1
}

if (!(Test-Path $InstallerRoot)) {
    Write-Log "ERROR: installers directory not found."
    exit 1
}

# ------------------------------------------------------------
# YAML Parser
# ------------------------------------------------------------

# PowerShell does not natively parse YAML.
# For our first version we will use a simple configuration
# format and later add a proper YAML parser.

Write-Log "Configuration file found."
Write-Log "Installer directory found."

# ------------------------------------------------------------
# Temporary software list
# ------------------------------------------------------------

$Software = @(
    @{
        Name = "Google Chrome"
        Installer = "$InstallerRoot\Chrome\ChromeSetup.exe"
        Type = "exe"
        Arguments = "/silent"
    },

    @{
        Name = "Visual Studio Code"
        Installer = "$InstallerRoot\VSCode\VSCodeSetup.exe"
        Type = "exe"
        Arguments = "/VERYSILENT /NORESTART"
    },

    @{
        Name = "Git"
        Installer = "$InstallerRoot\Git\GitSetup.exe"
        Type = "exe"
        Arguments = "/VERYSILENT /NORESTART"
    },

    @{
        Name = "7-Zip"
        Installer = "$InstallerRoot\7zip\7zipSetup.exe"
        Type = "exe"
        Arguments = "/S"
    },

    @{
        Name = "Node.js"
        Installer = "$InstallerRoot\NodeJS\NodeJS.msi"
        Type = "msi"
        Arguments = "/qn /norestart"
    }
)

# ------------------------------------------------------------
# Results
# ------------------------------------------------------------

$Results = @()

# ------------------------------------------------------------
# Installation
# ------------------------------------------------------------

foreach ($App in $Software) {

    Write-Host ""
    Write-Host "-----------------------------------------------"
    Write-Host "Installing: $($App.Name)"
    Write-Host "-----------------------------------------------"

    Write-Log "Starting installation: $($App.Name)"

    if (!(Test-Path $App.Installer)) {

        Write-Log "ERROR: Installer not found: $($App.Installer)"

        $Results += [PSCustomObject]@{
            Software = $App.Name
            Status   = "FAILED"
            ExitCode = "N/A"
        }

        continue
    }

    try {

        if ($App.Type -eq "exe") {

            $Process = Start-Process `
                -FilePath $App.Installer `
                -ArgumentList $App.Arguments `
                -Wait `
                -PassThru
        }

        elseif ($App.Type -eq "msi") {

            $Process = Start-Process `
                -FilePath "msiexec.exe" `
                -ArgumentList "/i `"$($App.Installer)`" $($App.Arguments)" `
                -Wait `
                -PassThru
        }

        else {

            throw "Unknown installer type: $($App.Type)"
        }

        $ExitCode = $Process.ExitCode

        if ($ExitCode -eq 0) {

            Write-Log "$($App.Name): SUCCESS"

            $Results += [PSCustomObject]@{
                Software = $App.Name
                Status   = "SUCCESS"
                ExitCode = $ExitCode
            }

        }
        else {

            Write-Log "$($App.Name): FAILED - Exit code $ExitCode"

            $Results += [PSCustomObject]@{
                Software = $App.Name
                Status   = "FAILED"
                ExitCode = $ExitCode
            }
        }

    }
    catch {

        Write-Log "$($App.Name): ERROR - $($_.Exception.Message)"

        $Results += [PSCustomObject]@{
            Software = $App.Name
            Status   = "ERROR"
            ExitCode = "N/A"
        }
    }
}

# ------------------------------------------------------------
# Final Report
# ------------------------------------------------------------

Write-Host ""
Write-Host ""
Write-Host "==============================================="
Write-Host "             DEPLOYMENT REPORT"
Write-Host "==============================================="
Write-Host ""

$Results | Format-Table -AutoSize

$Successful = ($Results | Where-Object {$_.Status -eq "SUCCESS"}).Count
$Failed = ($Results | Where-Object {$_.Status -ne "SUCCESS"}).Count

Write-Log "-----------------------------------------------"
Write-Log "Deployment finished"
Write-Log "Successful: $Successful"
Write-Log "Failed: $Failed"
Write-Log "Log: $LogFile"
Write-Log "-----------------------------------------------"

Write-Host ""
Write-Host "Successful: $Successful" -ForegroundColor Green
Write-Host "Failed:     $Failed" -ForegroundColor Red
Write-Host ""
Write-Host "Log saved to:"
Write-Host $LogFile
Write-Host ""

Read-Host "Press Enter to exit"