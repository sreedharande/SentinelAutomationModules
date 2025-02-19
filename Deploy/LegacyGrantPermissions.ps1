#  Required Permissions
#  To execute the Set-APIPermissions function you will need an Azure AD Global Administrator or an Azure AD Privileged Role Administrator
#  To execute the Set-RBACPermissions function you will need either Resource Group Owner or User Access Administrator on the Microsoft Sentinel resource group

$TenantID=""  #Add your AAD Tenant Id
$AzureSubscriptionId = "" #Azure Subscrition Id of Sentinel Subscription
$SentinelResourceGroupName = "" #Resource Group Name of Sentinel

$AADLogicAppName="Get-AADUserRisksInfo"          #Name of the AAD Risks Logic App
$BaseLogicAppName="Base-Module"                  #Name of the Base Module
$FileLogicAppName="Get-FileInsights"             #Name of the FileInsights Logic App
$KQLLogicAppName="Run-KQLQuery"                  #Name of the KQL Query Logic App
$UEBALogicAppName="Get-UEBAInsights"             #Name of the UEBA Logic App
$OOFLogicAppName="Get-OOFDetails"                #Name of the OOF Logic App
$MDELogicAppName="Get-MDEInsights"               #Name of the MDE Logic App
$MCASLogicAppName="Get-MCASInvestigationScore"   #Name of the MCAS Logic App
$RelatedAlertsLogicAppName="Get-RelatedAlerts"   #Name of the Related Alerts Logic App
$RunPlaybookLogicAppName="Run-Playbook"          #Name of the Run-Playbook Logic App
$ScoringLogicAppName="Calculate-RiskScore"       #Name of the Risk Scoring Logic App
$TILogicAppName="Get-ThreatIntel"                #Name of the TI Logic App
$WatchlistLogicAppName="Get-WatchlistInsights"   #Name of the Watchlists Logic App

$SampleLogicAppName="Sample-STAT-Triage"      #Name of the Sample Logic App

Get-RequiredModules("Az")
Get-RequiredModules("AzureAD")

Connect-AzureAD -TenantId $TenantID
Login-AzAccount
Set-AzContext -Subscription $AzureSubscriptionId

function Set-APIPermissions ($MSIName, $AppId, $PermissionName) {
    $MSI = Get-AppIds -AppName $MSIName
    Start-Sleep -Seconds 2
    $GraphServicePrincipal = Get-AzureADServicePrincipal -Filter "appId eq '$AppId'"
    $AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
    New-AzureAdServiceAppRoleAssignment -ObjectId $MSI.ObjectId -PrincipalId $MSI.ObjectId -ResourceId $GraphServicePrincipal.ObjectId -Id $AppRole.Id
}

function Get-AppIds ($AppName) {
    Get-AzureADServicePrincipal -Filter "displayName eq '$AppName'"
}

function Set-RBACPermissions ($MSIName, $Role) {
    $MSI = Get-AppIds -AppName $MSIName
    New-AzRoleAssignment -ApplicationId $MSI.AppId -Scope "/subscriptions/$($AzureSubscriptionId)/resourceGroups/$($SentinelResourceGroupName)" -RoleDefinitionName $Role
}

Function Get-RequiredModules {
    <#
    .DESCRIPTION 
    Get-RequiredModules is used to install and then import a specified PowerShell module.
    
    .PARAMETER Module
    parameter specifices the PowerShell module to install. 
    #>

    [CmdletBinding()]
    param (        
        [parameter(Mandatory = $true)] $Module        
    )
    
    try {
        $installedModule = Get-InstalledModule -Name $Module -ErrorAction SilentlyContinue       

        if ($null -eq $installedModule) {
            Write-Host "The $Module PowerShell module was not found"
            #check for Admin Privleges
            $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

            if (-not ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
                #Not an Admin, install to current user            
                Write-Host "Can not install the $Module module. You are not running as Administrator"
                Write-Host "Installing $Module module to current user Scope"
                
                Install-Module -Name $Module -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
                Import-Module -Name $Module -Force
            }
            else {
                #Admin, install to all users																		   
                Write-Host "Installing the $Module module to all users"
                Install-Module -Name $Module -Repository PSGallery -Force -AllowClobber
                Import-Module -Name $Module -Force
            }
        }
        else {
            if ($UpdateAzModules) {
                Write-Host "Checking updates for module $Module"
                $currentVersion = [Version](Get-InstalledModule | Where-Object {$_.Name -eq $Module}).Version
                # Get latest version from gallery
                $latestVersion = [Version](Find-Module -Name $Module).Version
                if ($currentVersion -ne $latestVersion) {
                    #check for Admin Privleges
                    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

                    if (-not ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
                        #install to current user            
                        Write-Host "Can not update the $Module module. You are not running as Administrator"
                        Write-Host "Updating $Module from [$currentVersion] to [$latestVersion] to current user Scope"
                        Update-Module -Name $Module -RequiredVersion $latestVersion -Force
                    }
                    else {
                        #Admin - Install to all users																		   
                        Write-Host "Updating $Module from [$currentVersion] to [$latestVersion] to all users"
                        Update-Module -Name $Module -RequiredVersion $latestVersion -Force
                    }
                }
                else {
                    $latestVersion = [Version](Get-Module -Name $Module).Version               
                    Write-Host "Importing module $Module with version $latestVersion"
                    Import-Module -Name $Module -RequiredVersion $latestVersion -Force
                }
            }
            else {                
                # Get latest version
                $latestVersion = [Version](Get-Module -Name $Module).Version               
                Write-Host "Importing module $Module with version $latestVersion"
                Import-Module -Name $Module -RequiredVersion $latestVersion -Force                
            }
        }
        # Install-Module will obtain the module from the gallery and install it on your local machine, making it available for use.
        # Import-Module will bring the module and its functions into your current powershell session, if the module is installed.  
    }
    catch {
        Write-Host "An error occurred in Get-RequiredModules() method - $($_)"        
    }
}

#UEBA
Set-APIPermissions -MSIName $UEBALogicAppName -AppId "ca7f3f0b-7d91-482c-8e09-c5d840d0eac5" -PermissionName "Data.Read"
Set-RBACPermissions -MSIName $UEBALogicAppName -Role "Microsoft Sentinel Responder"

#OOF
Set-APIPermissions -MSIName $OOFLogicAppName -AppId "00000003-0000-0000-c000-000000000000" -PermissionName "MailboxSettings.Read"
Set-RBACPermissions -MSIName $OOFLogicAppName -Role "Microsoft Sentinel Responder"

#RelatedAlerts
Set-APIPermissions -MSIName $RelatedAlertsLogicAppName -AppId "ca7f3f0b-7d91-482c-8e09-c5d840d0eac5" -PermissionName "Data.Read"
Set-RBACPermissions -MSIName $RelatedAlertsLogicAppName -Role "Microsoft Sentinel Responder"

#MDE
Set-APIPermissions -MSIName $MDELogicAppName -AppId "00000003-0000-0000-c000-000000000000" -PermissionName "User.Read.All"
Set-APIPermissions -MSIName $MDELogicAppName -AppId "fc780465-2017-40d4-a0c5-307022471b92" -PermissionName "AdvancedQuery.Read.All"
Set-APIPermissions -MSIName $MDELogicAppName -AppId "fc780465-2017-40d4-a0c5-307022471b92" -PermissionName "Machine.Read.All"
Set-RBACPermissions -MSIName $MDELogicAppName -Role "Microsoft Sentinel Responder"

#MCAS
Set-APIPermissions -MSIName $MCASLogicAppName -AppId "05a65629-4c1b-48c1-a78b-804c4abdd4af" -PermissionName "investigation.read"
Set-RBACPermissions -MSIName $MCASLogicAppName -Role "Microsoft Sentinel Responder"

#Watchlists
Set-APIPermissions -MSIName $WatchlistLogicAppName -AppId "ca7f3f0b-7d91-482c-8e09-c5d840d0eac5" -PermissionName "Data.Read"
Set-RBACPermissions -MSIName $WatchlistLogicAppName -Role "Microsoft Sentinel Responder"

#Base module
Set-APIPermissions -MSIName $BaseLogicAppName -AppId "00000003-0000-0000-c000-000000000000" -PermissionName "User.Read.All"
Set-APIPermissions -MSIName $BaseLogicAppName -AppId "00000003-0000-0000-c000-000000000000" -PermissionName "Reports.Read.All"
Set-APIPermissions -MSIName $BaseLogicAppName -AppId "00000003-0000-0000-c000-000000000000" -PermissionName "RoleManagement.Read.Directory"
Set-RBACPermissions -MSIName $BaseLogicAppName -Role "Microsoft Sentinel Responder"

#File module
Set-APIPermissions -MSIName $FileLogicAppName -AppId "8ee8fdad-f234-4243-8f3b-15c294843740" -PermissionName "AdvancedHunting.Read.All"
Set-RBACPermissions -MSIName $FileLogicAppName -Role "Microsoft Sentinel Responder"

#KQL module
Set-APIPermissions -MSIName $KQLLogicAppName -AppId "ca7f3f0b-7d91-482c-8e09-c5d840d0eac5" -PermissionName "Data.Read"
Set-APIPermissions -MSIName $KQLLogicAppName -AppId "8ee8fdad-f234-4243-8f3b-15c294843740" -PermissionName "AdvancedHunting.Read.All"
Set-RBACPermissions -MSIName $KQLLogicAppName -Role "Microsoft Sentinel Responder"

#AADRisksModule
Set-APIPermissions -MSIName $AADLogicAppName -AppId "ca7f3f0b-7d91-482c-8e09-c5d840d0eac5" -PermissionName "Data.Read"
Set-APIPermissions -MSIName $AADLogicAppName -AppId "00000003-0000-0000-c000-000000000000" -PermissionName "User.Read.All"
Set-APIPermissions -MSIName $AADLogicAppName -AppId "00000003-0000-0000-c000-000000000000" -PermissionName "IdentityRiskyUser.Read.All"
Set-RBACPermissions -MSIName $AADLogicAppName -Role "Microsoft Sentinel Responder"

#TI
Set-APIPermissions -MSIName $TILogicAppName -AppId "ca7f3f0b-7d91-482c-8e09-c5d840d0eac5" -PermissionName "Data.Read"
Set-RBACPermissions -MSIName $TILogicAppName -Role "Microsoft Sentinel Responder"

#Triage-Content Sample
Set-RBACPermissions -MSIName $SampleLogicAppName -Role "Microsoft Sentinel Responder"

#Calculate-RiskScore
Set-RBACPermissions -MSIName $ScoringLogicAppName -Role "Microsoft Sentinel Responder"

#Run-Playbook
Set-RBACPermissions -MSIName $RunPlaybookLogicAppName -Role "Microsoft Sentinel Responder"
