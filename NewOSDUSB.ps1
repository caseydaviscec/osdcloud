# Define variables
$requiredModuleVersion = "25.6.10.1"
$isoFileName = "CECWin11.1.2.iso"
$isoDownloadUrl = "http://cec-mdt.cec.coloradoearlycolleges.org/CECWin11.1.2.iso"
$isoLocalPath = Join-Path -Path $env:TEMP -ChildPath $isoFileName
$expectedfilehash = "725C20961271C648153FD25D9D0EBAF6296DC5524E9107D2E98596C6D0CC0673"

function Download-And-VerifyISO {
    param (
        [string]$Url,
        [string]$Path,
        [string]$ExpectedHash
    )
    try {
        Write-Host "Downloading ISO..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $Url -OutFile $Path
        $filehash = Get-FileHash -Path $Path -Algorithm SHA256
        if ($filehash.Hash -ne $ExpectedHash) {
            Write-Host "Downloaded ISO file hash does not match expected hash. Please try again." -ForegroundColor Red
            exit 1
        }
        Write-Host "ISO downloaded successfully and hash verified." -ForegroundColor Green
    }
    catch {
        Write-Host "Error downloading ISO." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host "Are you connected to the internet at a CEC school or VPN?"
        Write-Host "Please check your connection and try again."
        exit 1
    }
}

# Step 1: Ensure OSD module is installed
Write-Host "Checking for OSD module version $requiredModuleVersion..." -ForegroundColor Yellow
if (-not (Get-Module -ListAvailable -Name OSD | Where-Object Version -eq $requiredModuleVersion)) {
    Write-Host "Installing OSD module version $requiredModuleVersion..." -ForegroundColor Yellow
    Install-Module -Name OSD -RequiredVersion $requiredModuleVersion -Force -Scope CurrentUser
}

# Step 2: Import OSD module
Write-Host "Importing OSD module version $requiredModuleVersion..." -ForegroundColor Yellow
Import-Module OSD -Version $requiredModuleVersion -Force

# Step 3: Ensure ISO exists and is valid
$null = Dismount-DiskImage -ImagePath $isoLocalPath -ErrorAction SilentlyContinue
$needsDownload = $true
if (Test-Path $isoLocalPath) {
    $filehash = Get-FileHash -Path $isoLocalPath -Algorithm SHA256
    if ($filehash.Hash -eq $expectedfilehash) {
        Write-Host "Local ISO file hash matches expected hash. No need to re-download." -ForegroundColor Green
        $needsDownload = $false
    }
    else {
        Write-Host "Local ISO file hash does not match expected hash. Removing and re-downloading..." -ForegroundColor Yellow
        $null = Get-Item -Path $isoLocalPath | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}
if ($needsDownload) {
    Download-And-VerifyISO -Url $isoDownloadUrl -Path $isoLocalPath -ExpectedHash $expectedfilehash
}

# Step 4: Create OSDCloud USB from downloaded ISO
Write-Host "Creating OSDCloud USB from local ISO..." -ForegroundColor Yellow
New-OSDCloudUSB -fromIsoFile $isoLocalPath

# Step 5: Unmount ISO File
$null = Dismount-DiskImage -ImagePath $isoLocalPath -ErrorAction SilentlyContinue

# Step 6: Update USB with specified OS settings
Write-Host "Updating OSDCloud USB with Windows 11 24H2 Volume License ISO..." -ForegroundColor Yellow
Update-OSDCloudUSB -OSName 'Windows 11 24H2' -OSLanguage en-us -OSActivation Volume

Write-Host "OSDCloud USB process completed successfully." -ForegroundColor Green
