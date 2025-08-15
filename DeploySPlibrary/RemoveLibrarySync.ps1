#Script variables:
$SharePointTenantName = "Contoso Incorporated"
$SiteLibraryDisplayName = "Site - Library" # Contoso - Documents


# Stop the OneDrive process
Stop-Process -Name "OneDrive" -Force

#Grabs all user profiles on computer
$userProfiles = Get-WmiObject -Class Win32_UserProfile | Where-Object { $_.Special -eq $false }

#Remove sync on each profile
foreach ($userProfile in $userProfiles) {
    $userProfilePath = $userProfile.LocalPath
    $syncFolderPath = "$userProfilePath\$SharePointTenantName\$SiteLibraryDisplayName"
    $onedriveConfigPath = "$userProfilePath\AppData\Local\Microsoft\OneDrive\settings\Business1"

    # Debugging output
    Write-Output "Checking profile: $userProfilePath"
    Write-Output "Looking for sync folder path: $syncFolderPath"

    # Remove the sync relationship for the specified folder
    if (Test-Path -Path $onedriveConfigPath) {
        $configFiles = Get-ChildItem -Path $onedriveConfigPath -Filter "*-*-*-*-*.ini"
        foreach ($file in $configFiles) {
            $content = Get-Content $file.PSPath -Raw
            $updatedContent = @()

            foreach ($line in $content -split "`n") {

                if (!($line | Select-String -Pattern $syncFolderPath -SimpleMatch)) {
                    $updatedContent += $line
                } else {
                    Write-Output "Removing line: $line"
                }
            }
            #do a .bak before overwriting. FYI
            Set-Content -Value ($updatedContent -join "`n") -Path $file.PSPath -Encoding utf8NoBOM
        }
    }
}

#Delete the folder on every profile
foreach ($userProfile in $userProfiles) {
    $userProfilePath = $userProfile.LocalPath
    $syncFolderPath = "$userProfilePath\$SharePointTenantName\$SiteLibraryDisplayName"
    $onedriveConfigPath = "$userProfilePath\AppData\Local\Microsoft\OneDrive\settings\Business1"

    # Remove the sync relationship for the specified folder
    if (Test-Path -Path $onedriveConfigPath) {
        $configFiles = Get-ChildItem -Path $onedriveConfigPath -Filter "*.ini"
        foreach ($file in $configFiles) {
            (Get-Content $file.PSPath) | ForEach-Object {
                if ($_ -notmatch [regex]::Escape($syncFolderPath)) {
                    $_
                }
            } | Set-Content $file.PSPath
        }
    }
}

# Restart the OneDrive process
Start-Process -FilePath "C:\Program Files\Microsoft OneDrive\OneDrive.exe"
