# bootstrap-profile

A powershell script to initialize an empty windows machine with profile settings and programs using scoop or winget.

## Pre-requisites

A repo with profile.ps1 in the root that will added to your user profile.
Install-ScoopApps or Install-WinGetApps functions in the profile.ps1 to install programs.

## Usage

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser;
Invoke-RestMethod -Uri https://raw.githubusercontent.com/twirlse/bootstrap-profile/main/bootstrap.ps1 | Invoke-Expression;
Bootstrap-Profile -Repo <username/profile-repo-name>;
```

## Parameters

- **Repo**: The repository to clone and install programs from. Default: `twirlse/bootstrap-profile`.
- **RepoLocation**: The location to clone the repository to. Default: `./scripts`.
- **Installer**: The package manager to use, scoop or winget. Default: `scoop`.
- **Preset**: The preset for which programs to install, minimal or full. Default: `minimal`.
