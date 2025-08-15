#Region Variables to edit
$OutputFolder = "$env:USERPROFILE\downloads"
$IntuneWinAppUtilpath = "C:\path\to\folder\with\Intune_PackageBuilder"
$DocLibURLs = @(
    "https://contoso.sharepoint.com/sites/site/library"
)

# PNP app registration
if (!$clientid){$clientid = Read-Host -Prompt "Enter your PnP Client ID"}

#Region Functions
function Get-SyncScriptOutput {
    param (
        $DocLibURL,
        $ClientID
    )

    $siteURL = (Split-Path -Path $DocLibURL -Parent) -replace "\\","/"
    $LibraryDisplayName = (Split-Path -Path $DocLibURL -Leaf) -replace "%20"," " 

    Write-Host "Connecting to : $siteurl"
    Connect-PnPOnline -Url $siteURL -Interactive -ClientId $clientid

    $web = Get-PnPWeb
    $site = Get-PnPSite -Includes Id
    $list = get-pnplist -Identity $LibraryDisplayName

    $output = [PSCustomObject]@{
        webUrl = $web.Url
        webTitle = $web.Title
        siteId = $site.Id
        webId = $web.Id
        listTitle = $list.Title
        listId = $list.Id
    }

    return $output
}

function Out-SharePointSyncScript {
    param (
        $results
    )

    $OutputScript = (
        '$WebURL = "' + $results.webUrl + "`"`n" +
        '$webTitle = "' + $results.webTitle + "`"`n" +
        '$SiteID = "' + $results.siteId.Guid + "`"`n" +
        '$webId  = "' + $results.webId.Guid + "`"`n" +
        '$listTitle = "' + $results.listTitle + "`"`n" +
        '$ListID = "' + $results.ListID.Guid +  "`"`n" +
        '$UserEmail = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\Business1" -Name "UserEmail").useremail' + "`n" +
        '$odopen = "odopen://sync/?siteId=" + $SiteID + "&webId=" + $webId + "&webUrl=" + $WebURL + "&listId=" + $ListID + "&userEmail=" + $UserEmail + "&webTitle=" + $webTitle + "&listTitle=" + $listTitle' + "`n" +
        'Start-Process $odopen'
    )

    return $OutputScript 
}

function Out-IntuneWin32AppAndPSScript {
    param (
        $clientid,
        $list,
        $IntuneWinAppUtil,
        $OutputFolder
    )

    if (($IntuneWinAppUtil -like "*\IntuneWinAppUtil.exe")) {
        $IntuneWinAppUtilpath = Split-Path -Path $IntuneWinAppUtil -Parent

    }
    if (!(Test-Path -Path "$IntuneWinAppUtil\IntuneWinAppUtil.exe")) {
        Write-Error "IntuneWinAppUtil.exe missing or wrong name. Please check the path and name."
        exit 1
    }

    $scriptFolder = "$OutputFolder\script"
    $intuneFolder = "$OutputFolder\intune"
    if (!(Test-Path -Path $scriptFolder -ErrorAction SilentlyContinue)) {mkdir $scriptFolder}
    if (!(Test-Path -Path $intuneFolder -ErrorAction SilentlyContinue)) {mkdir $intuneFolder}

    $results = Get-SyncScriptOutput -DocLibURL $list -ClientID $clientid
    $OutputScript = Out-SharePointSyncScript -results $results
    $filename = ($results.webTitle + "_" + $results.listTitle)
    Out-File -InputObject $OutputScript -FilePath $scriptFolder\$filename.ps1 -Force
    Set-Location -Path $IntuneWinAppUtilpath
    .\IntuneWinAppUtil.exe -c $scriptFolder -s "$filename.ps1" -o $intuneFolder -q
    #Remove-Item $scriptFolder\$filename.ps1 -Force
}

#Region Main Process
foreach ($library in $DocLibURLs) {
    Out-IntuneWin32AppAndPSScript -list $list -clientid $clientid -IntuneWinAppUtil $IntuneWinAppUtil -OutputFolder $OutputFolder
}

#Out-SharePointSyncScript -results (Get-SyncScriptOutput -DocLibURL "https://contoso.sharepoint.com/sites/site name/library name" -ClientID $clientid) | out-file ~\downloads\DeploymentScript.ps1

#Opens the folder
Invoke-Item $OutputFolder
$OutputFolder