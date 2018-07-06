<#
    .SYNOPSIS
    Creates a new Service Principal with password.

    .DESCRIPTION
    Creates a new Service Principal with password.
    
    .PARAMETER subscriptionName
        The name of the Subscription to connect.
    
    .PARAMETER servicePrincipalName
        The name of the Service Principal. 
    
    .NOTES 
#>
Param(
    [Parameter(Mandatory = $true)]
    [string]$subscriptionName,
    [Parameter(Mandatory = $true)]
    [string]$servicePrincipalName
)

Write-Output "Subscription Name:       $subscriptionName"
Write-Output "Service Principal Name:  $servicePrincipalName"

$connectionName = "AzureRunAsConnection"

try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName    

    Write-Output "Azure Run As Connection: $servicePrincipalConnection"     

    "Logging in to Azure..."
    Connect-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch 
{
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } 
    else
    {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Initialize
$appNameLower = $servicePrincipalName.ToLower()
$homePage = "http://" + $appNameLower + ".com"
$identifierUri = $homePage
$password = [System.Web.Security.Membership]::GeneratePassword(16,3)
$securePassword = ConvertTo-SecureString -Force -AsPlainText -String $password
$passwordExpirationDate = (Get-Date "1/1/2099 1:00 AM")

$azureSubscription = Get-AzureRmSubscription -SubscriptionName $subscriptionName
$tenantId = $azureSubscription.TenantId
$id = $azureSubscription.Id

# Check if the service principal already exists
$app = Get-AzureRmADApplication `
    -IdentifierUri $homePage `
    -ErrorAction "SilentlyContinue"

if ($app -ne $null)
{
    $appId = $app.ApplicationId

    Write-Output "An Azure AAD Appication with the provided values already exists, skipping the creation of the application..."
}
else
{    
    Write-Output "Creating a new Application in AAD (App URI - $identifierUri)" -Verbose

    try 
    {
        # Create a new AD Application
        $azureAdApplication = New-AzureRmADApplication `
            -DisplayName $servicePrincipalName `
            -HomePage $homePage `
            -IdentifierUris $identifierUri `
            -Verbose
    }
    catch
    {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }    
    
    $appId = $azureAdApplication.ApplicationId

    Write-Output "Azure AAD Application creation completed successfully (Application Id: $appId)" -Verbose
}

# Check if the principal already exists
$spn = Get-AzureRmADServicePrincipal `
    -ServicePrincipalName $appId `
    -ErrorAction "SilentlyContinue"

if ($spn -ne $null)
{
   Write-Output "An Azure AD Service Principal for the application already exists, skipping the creation of the principal..."
}
else
{
    # Create new SPN
    Write-Output "Creating a new SPN" -Verbose

    try 
    {
        # Create a new Service Principal
        $spn = New-AzureRmADServicePrincipal `
        -ApplicationId $appId `
        -EndDate $passwordExpirationDate `
        -Password $securePassword `
        -Verbose
    }
    catch
    {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }    

    $spnName = $spn.ServicePrincipalNames

    Write-Output "SPN creation completed successfully (SPN Name: $spnName)" -Verbose
}

Write-Output "***************************************************************************"
Write-Output "Tenant Id: $tenantId"
Write-Output "Subscription Id: $id"
Write-Output "Subscription Name: $subscriptionName"
Write-Output "Service Principal Client (Application) Id: $appId"
Write-Output "Service Principal key: $password"
Write-Output "Service Principal Display Name: $servicePrincipalName"
Write-Output "Service Principal Names:"
foreach ($spnname in $spn.ServicePrincipalNames)
{
    Write-Output "   *  $spnname"
}
Write-Output "***************************************************************************"

Write-Output "Script Completed"