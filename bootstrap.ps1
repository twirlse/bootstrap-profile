param (
    [String]$Repo,
    [String]$RepoLocation = "./scripts",
    [String]$Installer = "scoop",
    [String]$Preset = "minimal"
)

function Bootstrap-Profile {
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Repo,

        [ValidateNotNullOrEmpty()]
        [String]$RepoLocation = "./scripts",

        [ValidateNotNullOrEmpty()]
        [ValidateSet('scoop', 'winget')]
        [String]$Installer = "scoop",

        [ValidateNotNullOrEmpty()]
        [ValidateSet('full', 'minimal')]
        [String]$Preset = "minimal"
    )

    $ErrorActionPreference = "Stop"

    if (Test-Path $RepoLocation) {
        throw "Repo location already exists, please provide a new location. Path: $RepoLocation"
    }

    $repoPath = GetAbsolutePath $RepoLocation

    BootstrapPrereqs -Installer $Installer
    CloneProfileRepo -RepoName $Repo -RepoLocation $repoPath
    AddRepoToProfile -RepoName $Repo -RepoLocation $repoPath
    InstallApps -Installer $Installer -Preset $Preset

}

function BootstrapPrereqs ([String]$Installer) {
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

    Write-Host "Installing git and gh..."
    scoop install git
    scoop install gh
    Write-Host "Installed."
}

function BootstrapUsingWinGet {
    throw "Not implemented."
}

function CloneProfileRepo([String]$RepoName, [String]$RepoLocation) {
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

function AddRepoToProfile([String]$RepoName, [String]$RepoLocation) {
    Write-Host "Adding $RepoName to powershell profile..."
    Write-Host "Repo path: $RepoLocation"

    $profilePath = $PROFILE.CurrentUserAllHosts
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

function SetRepoPath([String]$RepoPath) {
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

function CreatePsProfile {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$ProfilePath
    )

    # create profile folder if not exists
    if (-not (Test-Path $profilePath)) {
        $dir = [System.IO.Path]::GetDirectoryName($profilePath)

        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir | Out-Null
        }
    }

    # create profile file if not exists
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath | Out-Null
    }
}

function GetAbsolutePath([String]$Path) {
    $isRelative = [System.IO.Path]::IsPathRooted($Path)

    if (-not $isRelative) {
        $currentDir = Get-Location
        $joinedPath = Join-Path -Path $currentDir -ChildPath $Path

        return [System.IO.Path]::GetFullPath($joinedPath)
    }

    return [System.IO.Path]::GetFullPath($Path)
}

function InstallApps([String]$Installer, [String]$Preset) {
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

if (-not ([String]::IsNullOrWhiteSpace($Repo))) {
    Bootstrap-Profile -Repo $Repo -RepoLocation $RepoLocation -Installer $Installer -Preset $Preset
}