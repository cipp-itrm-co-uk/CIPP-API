function Invoke-CIPPStandardDisableUserSiteCreate {
    <#
    .FUNCTIONALITY
        Internal
    .COMPONENT
        (APIName) DisableUserSiteCreate
    .SYNOPSIS
        (Label) Disable site creation by standard users
    .DESCRIPTION
        (Helptext) Disables users from creating new SharePoint sites
        (DocsDescription) Disables standard users from creating SharePoint sites, also disables the ability to fully create teams
    .NOTES
        CAT
            SharePoint Standards
        TAG
        ADDEDCOMPONENT
        IMPACT
            High Impact
        ADDEDDATE
            2022-06-15
        POWERSHELLEQUIVALENT
            Update-MgAdminSharePointSetting
        RECOMMENDEDBY
        UPDATECOMMENTBLOCK
            Run the Tools\Update-StandardsComments.ps1 script to update this comment block
    .LINK
        https://docs.cipp.app/user-documentation/tenant/standards/list-standards
    #>

    param($Tenant, $Settings)
    $TestResult = Test-CIPPStandardLicense -StandardName 'DisableUserSiteCreate' -TenantFilter $Tenant -RequiredCapabilities @('SHAREPOINTWAC', 'SHAREPOINTSTANDARD', 'SHAREPOINTENTERPRISE', 'ONEDRIVE_BASIC', 'ONEDRIVE_ENTERPRISE')
    ##$Rerun -Type Standard -Tenant $Tenant -Settings $Settings 'DisableUserSiteCreate'

    if ($TestResult -eq $false) {
        Write-Host "We're exiting as the correct license is not present for this standard."
        return $true
    } #we're done.

    try {
        $CurrentInfo = New-GraphGetRequest -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings' -tenantid $Tenant -AsApp $true
    }
    catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -API 'Standards' -Tenant $Tenant -Message "Could not get the DisableUserSiteCreate state for $Tenant. Error: $ErrorMessage" -Sev Error
        return
    }

    If ($Settings.remediate -eq $true) {

        if ($CurrentInfo.isSiteCreationEnabled -or $CurrentInfo.isSiteCreationUIEnabled) {
            try {
                $body = '{"isSiteCreationEnabled": false, "isSiteCreationUIEnabled": false}'
                $null = New-GraphPostRequest -tenantid $tenant -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings' -AsApp $true -Type patch -Body $body -ContentType 'application/json'
                Write-LogMessage -API 'Standards' -tenant $tenant -message 'Disabled standard users from creating sites and adjusted UI setting' -sev Info
            } catch {
                $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
                Write-LogMessage -API 'Standards' -tenant $tenant -message "Failed to disable standard users from creating sites: $ErrorMessage" -sev Error
            }
        } else {
            Write-LogMessage -API 'Standards' -tenant $tenant -message 'Standard users are already disabled from creating sites and UI setting is adjusted' -sev Info
        }

    }

    if ($Settings.alert -eq $true) {

        if ($CurrentInfo.isSiteCreationEnabled -eq $false -and $CurrentInfo.isSiteCreationUIEnabled -eq $false) {
            Write-LogMessage -API 'Standards' -tenant $tenant -message 'Standard users are not allowed to create sites and UI setting is disabled' -sev Info
        } else {
            Write-StandardsAlert -message 'Standard users are allowed to create sites or UI setting is enabled' -object $CurrentInfo -tenant $tenant -standardName 'DisableUserSiteCreate' -standardId $Settings.standardId
            Write-LogMessage -API 'Standards' -tenant $tenant -message 'Standard users are allowed to create sites or UI setting is enabled' -sev Info
        }
    }

    if ($Settings.report -eq $true) {
        $state = $CurrentInfo.isSiteCreationEnabled -and $CurrentInfo.isSiteCreationUIEnabled ? ($CurrentInfo | Select-Object isSiteCreationEnabled, isSiteCreationUIEnabled) : $true
        Set-CIPPStandardsCompareField -FieldName 'standards.DisableUserSiteCreate' -FieldValue $State -Tenant $tenant
        Add-CIPPBPAField -FieldName 'DisableUserSiteCreate' -FieldValue $CurrentInfo.isSiteCreationEnabled -StoreAs bool -Tenant $tenant
        Add-CIPPBPAField -FieldName 'DisableUserSiteCreateUI' -FieldValue $CurrentInfo.isSiteCreationUIEnabled -StoreAs bool -Tenant $tenant
    }
}
