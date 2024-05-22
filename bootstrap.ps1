param (
    [string]$Repo,
    [string]$RepoLocation = "./scripts",
    [string]$Installer = "scoop",
    [string]$Preset = "minimal"
)

function Bootstrap-Profile {
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Repo,

        [ValidateNotNullOrEmpty()]
        [string]$RepoLocation = "./scripts",

        [ValidateNotNullOrEmpty()]
        [ValidateSet('scoop', 'winget')]
        [string]$Installer = "scoop",

        [ValidateNotNullOrEmpty()]
        [ValidateSet('full', 'minimal')]
        [string]$Preset = "minimal"
    )

    Write-Host "Bootstrapping profile..."

    $ErrorActionPreference = "Stop"

    if (Test-Path $RepoLocation) {
        throw "Repo location already exists, please provide a new location. Path: $RepoLocation"
    }

    $repoPath = GetAbsolutePath $RepoLocation

    BootstrapPrereqs -Installer $Installer
    CloneProfileRepo -RepoName $Repo -RepoLocation $repoPath

    # add repo scripts to ps 5 profile
    AddRepoToProfile -PsVersion 5 -RepoName $Repo -RepoLocation $repoPath
    # add repo scripts to ps 7 profile
    AddRepoToProfile -PsVersion 7 -RepoName $Repo -RepoLocation $repoPath

    # install apps from saved preset
    InstallApps -Installer $Installer -Preset $Preset

    Write-Host "Profile bootstrapped."
}

function BootstrapPrereqs ([string]$Installer) {
    if ($Installer -eq "scoop") {
        BootstrapUsingScoop
    }
    elseif ($Installer -eq "winget") {
        BootstrapUsingWinGet
    }
    else {
        throw "Invalid installer: $Installer"
    }
}

function BootstrapUsingScoop {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Scoop..."
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        Write-Host "Scoop installed."
    }
    else {
        Write-Host "Scoop already installed, updating."
        scoop update
        Write-Host "Scoop updated."
    }

    Write-Host "Installing git, gh and pwsh..."
    scoop install git
    scoop install gh
    scoop install pwsh
    Write-Host "Installed."
}

function BootstrapUsingWinGet {
    throw "Not implemented."
}

function CloneProfileRepo([string]$RepoName, [string]$RepoLocation) {
    Write-Host "Cloning $RepoName to $RepoLocation..."

    # check if already logged in into github (supress output and error messages)
    try {
        gh auth status *>&1 | Out-Null
    }
    catch {
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Authenticating with GitHub..."
            gh auth login
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to authenticate with GitHub. Error code: $LASTEXITCODE"
            }
        }
    }

    gh repo clone $RepoName $RepoLocation
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone $RepoName. Error code: $LASTEXITCODE"
    }

    Write-Host "Cloned to $RepoLocation."

    if (-not (Test-Path $RepoLocation)) {
        throw "Something went wrong, repo directory not found on disk. Path: $RepoLocation"
    }

    # set repo path in env variable
    SetRepoPath -RepoPath $RepoLocation
}

function AddRepoToProfile([int]$PsVersion, [string]$RepoName, [string]$RepoLocation) {
    Write-Host "Adding $RepoName to powershell $PsVersion profile..."
    Write-Host "Repo path: $RepoLocation"

    $profilePath = GetProfilePath -PsVersion $PsVersion
    Write-Host "Profile path: $profilePath"

    CreatePsProfile -ProfilePath $profilePath

    $importStr = ". $RepoLocation\profile.ps1"
    # add import statement if not exists
    $escapedImportStr = [Regex]::Escape($importStr)
    if (-not (Select-String -Path $profilePath -Pattern $escapedImportStr)) {
        Add-Content $profilePath -Value "`n$importStr"
    }

    Write-Host "Added."
}

function InstallApps([string]$Installer, [string]$Preset) {
    Write-Host "Installing apps for preset: $Preset..."

    # start a new shell and install apps
    if ($Installer -eq "scoop") {
        Start-Process powershell -ArgumentList "-Command & { Install-ScoopApps -Preset $Preset }" -NoNewWindow -Wait
    }
    elseif ($Installer -eq "winget") {
        Start-Process powershell -ArgumentList "-Command & { Install-WinGetApps -Preset $Preset }" -NoNewWindow -Wait
    }

    Write-Host "Done installing apps."
}

function SetRepoPath([string]$RepoPath) {
    if (-not (Test-Path $RepoPath)) {
        throw "Invalid repo path: $RepoPath"
    }

    if (-not (Test-Path "Env:\SCRIPT_REPO_ROOT")) {
        Write-Host "Setting SCRIPT_REPO_ROOT env. variable to '$RepoPath'..."
        $location = Resolve-Path $RepoPath
        [System.Environment]::SetEnvironmentVariable('SCRIPT_REPO_ROOT', "$location", 'User')
        Write-Host "Done."
    }
}

function GetProfilePath([int]$PsVersion) {
    $profilePath = ""

    if ($PsVersion -eq 5) {
        $profilePath = & powershell -NoProfile -Command { $PROFILE.CurrentUserAllHosts }
    }
    elseif ($PsVersion -ge 7) {
        $profilePath = & pwsh -NoProfile -Command { $PROFILE.CurrentUserAllHosts }
    }
    else {
        throw "Invalid PowerShell version: $PsVersion"
    }

    return $profilePath
}

function CreatePsProfile {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    # create profile folder and file if not exists
    if (-not (Test-Path $profilePath)) {
        $dir = [System.IO.Path]::GetDirectoryName($profilePath)

        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir | Out-Null
        }

        # create profile file
        New-Item -ItemType File -Path $profilePath | Out-Null
    }
}

function GetAbsolutePath([string]$Path) {
    $isRelative = [System.IO.Path]::IsPathRooted($Path)

    if (-not $isRelative) {
        $currentDir = Get-Location
        $joinedPath = Join-Path -Path $currentDir -ChildPath $Path

        return [System.IO.Path]::GetFullPath($joinedPath)
    }

    return [System.IO.Path]::GetFullPath($Path)
}

if (-not ([string]::IsNullOrWhiteSpace($Repo))) {
    Bootstrap-Profile -Repo $Repo -RepoLocation $RepoLocation -Installer $Installer -Preset $Preset
}