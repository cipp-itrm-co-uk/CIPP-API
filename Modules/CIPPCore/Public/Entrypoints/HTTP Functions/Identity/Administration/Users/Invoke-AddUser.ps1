using namespace System.Net

Function Invoke-AddUser {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Identity.User.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    Write-LogMessage -headers $Headers -API $APIName -message 'Accessed this API' -Sev 'Debug'

    $UserObj = $Request.Body

    if ($UserObj.Scheduled.Enabled) {
        $TaskBody = [pscustomobject]@{
            TenantFilter  = $UserObj.tenantFilter
            Name          = "New user creation: $($UserObj.mailNickname)@$($UserObj.PrimDomain.value)"
            Command       = @{
                value = 'New-CIPPUserTask'
                label = 'New-CIPPUserTask'
            }
            Parameters    = [pscustomobject]@{ UserObj = $UserObj }
            ScheduledTime = $UserObj.Scheduled.date
            PostExecution = @{
                Webhook = [bool]$Request.Body.PostExecution.Webhook
                Email   = [bool]$Request.Body.PostExecution.Email
                PSA     = [bool]$Request.Body.PostExecution.PSA
            }
        }
        Add-CIPPScheduledTask -Task $TaskBody -hidden $false -DisallowDuplicateName $true -Headers $Headers
        $body = [pscustomobject] @{
            'Results' = @("Successfully created scheduled task to create user $($UserObj.DisplayName)")
        }
    } else {
        $CreationResults = New-CIPPUserTask -UserObj $UserObj -APIName $APIName -Headers $Headers
        $body = [pscustomobject] @{
            'Results'  = @(
                $CreationResults.Results[0],
                $CreationResults.Results[1],
                @{
                    'resultText' = $CreationResults.Results[2]
                    'copyField'  = $CreationResults.password
                    'state'      = 'success'
                }
            )
            'CopyFrom' = @{
                'Success' = $CreationResults.CopyFrom.Success
                'Error'   = $CreationResults.CopyFrom.Error
            }
        }
    }
    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $Body
        })

}
