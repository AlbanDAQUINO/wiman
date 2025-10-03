param([string]$sourcesfolder = "$pwd\sources\", [string]$outputfolder = "$pwd\finalized\", [string]$tempfolder = "$pwd\.tmp\", [string]$downloadsfolder = "$pwd\downloads\", [int]$Optimization = 1)
Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Includes
. ".\inc\Log.ps1"
. ".\inc\AddDriversToWIM.ps1"
. ".\inc\AddUpdatesToWIM.ps1"
. ".\inc\ConfigureWinPEConsole.ps1"
. ".\inc\ConvertArchitectureIdToString.ps1"
. ".\inc\CopyBootFiles.ps1"
. ".\inc\CopyIfNewer.ps1"
. ".\inc\DetectWindowsName.ps1"
. ".\inc\ExportWIMIndex.ps1"
. ".\inc\ExtractISO.ps1"
. ".\inc\ExtractWIM.ps1"
. ".\inc\ExtractXMLFromWIM.ps1"
. ".\inc\FinishWIM.ps1"
. ".\inc\GetLatestWinPEImages.ps1"
. ".\inc\InstallChoco.ps1"
. ".\inc\InstallWAIK.ps1"
. ".\inc\OptimizeWIM.ps1"
. ".\inc\PrepareInstallWIM.ps1"
. ".\inc\PrepareWIM.ps1"
. ".\inc\PrepareWinPEWIM.ps1"
. ".\inc\SetWinPETargetPath.ps1"
. ".\inc\FetchLatestOpenSSH.ps1"

# MAIN starts here!
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "Checking if the shell has priviledge" -ForegroundColor Yellow
Write-Host $isAdmin
if ($isAdmin -eq $true) {
    # Connectivity check
    Write-Host "Checking connectivity" -ForegroundColor Yellow
    $domains = @("https://microsoft.com", "https://github.com")
    foreach ($domain in $domains) {
        try {
            $response = Invoke-WebRequest -Uri $domain -UseBasicParsing -TimeoutSec 10
            if ($response.StatusCode -ne 200) {
                throw "Unexpected status code $($response.StatusCode)"
            }
            else {
                Write-Host "URL $domain is accessible."
            }
        }
        catch {
            Write-Host "ERROR: Cannot reach $domain. Please check firewall/network." -ForegroundColor Red
            Write-Host "Or manually place the required files in the '$downloadsfolder' folder."
            exit 1
        }
    }

    # Check if temp folder exists and remove it
    if (Test-Path $tempfolder) {
        Write-Host "Cleaning temporary files" -ForegroundColor Yellow
        Remove-Item -Recurse -Force $tempfolder
    }
    # Recreate the folder
    $folder = New-Item -Force -ItemType Directory -Path $tempfolder
    # Mark the folder as hidden
    $folder.Attributes += "HIDDEN"

    Write-Host "Checking for WAIK installations" -ForegroundColor Yellow
    DetectAndInstallWAIK

    Write-Host "Checking for OpenSSH latest binaries" -ForegroundColor Yellow
    DownloadLatestOpenSSHServer

    Write-Host "Building images ..." -ForegroundColor Cyan
    $list_isos = Get-ChildItem -Path "$sourcesfolder\*\*\*.iso"
    foreach ($iso in $list_isos) {
        Write-Host "Building media for" $iso.Directory.Name "[" $iso.Directory.Parent.Name "]"
        ExtractISO $iso $tempfolder $overwrite

        DetectWindowsName $iso

        PrepareWinPEWIM $iso $outputfolder
        PrepareInstallWIM $iso $outputfolder

        Write-Host "`tCopying boot files... " -NoNewline -ForegroundColor White
        CopyBootFiles $iso $outputfolder
        Write-Host "OK" -ForegroundColor Green
    }

    Write-Host "All Done!"
}
else {
    Write-Host -ForegroundColor red -BackgroundColor Black "please run this script in an elevated powershell instance!"
}
