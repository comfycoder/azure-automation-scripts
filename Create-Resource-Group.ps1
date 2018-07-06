<#
    .SYNOPSIS
    Used to create an Azure Role Group and assign acce3ss permissions
    to a Service principal used as an endpoint for VSTS deployments,
    and optionally a development team AD Role Group access.

    .DESCRIPTION
    Create a new Resource Group and assigns Contributor access to the input
    Service Principal name and optional AD Role Group name.
    
    .PARAMETER subscriptionName
        The name of the Subscription to connect.
    
    .PARAMETER resourceGroupName
        The name of the Resource Group to create.
    
    .PARAMETER resourceGroupOwnerName
        The name of the Resource Group owner (e.g., SP-VSTS-MyMockups).
    
    .PARAMETER adRoleGroupName
        The name of the AD Role Group to allow access (e.g., R-App-MyMockups-Developers)
    
    .PARAMETER tagAssetCode
        A descriptive Tag to assign to the Resource Group.
    
    .PARAMETER location
        The name of the Resource Group location.
    
    .NOTES 
#>
Param (
  [Parameter(Mandatory = $true)]
  [string] $subscriptionName,
  [Parameter(Mandatory = $true)]
  [string] $resourceGroupName,
  [Parameter(Mandatory = $true)]
  [string] $resourceGroupOwnerName,
  [Parameter(Mandatory = $false)]
  [string] $adRoleGroupName,
  [Parameter(Mandatory = $false)]
  [string] $tagAssetCode,
  [Parameter(Mandatory = $false)]
  [string] $location = "northcentralus"
)

Write-Output "Subscription Name:       $subscriptionName"
Write-Output "Resource Group Name:  $resourceGroupName"
Write-Output "Resource Group Owner Name:  $resourceGroupOwnerName"
Write-Output "AD Role Group Name:  $adRoleGroupName"
Write-Output "Service Principal Name:  $servicePrincipalName"
Write-Output "Service Principal Name:  $servicePrincipalName"
Write-Output "Service Principal Name:  $servicePrincipalName"

$connectionName = "AzureRunAsConnection"

try {
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
catch {
  if (!$servicePrincipalConnection) {
    $ErrorMessage = "Connection $connectionName not found."
    throw $ErrorMessage
  } 
  else {
    Write-Error -Message $_.Exception
    throw $_.Exception
  }
}

# Check if the service principal already exists
$rg = Get-AzureRmResourceGroup `
  -Name $resourceGroupName `
  -Location $location `
  -ErrorAction "SilentlyContinue"

if ($rg -ne $null)
{
  Write-Output "A Resource Group with the provided values already exists, skipping the creation of the resource group..." -Verbose
}
else
{    
  Write-Output "Creating a new Resource Group ($resourceGroupName)" -Verbose

  try 
  {
    # Create a new AD Application
    $rg = New-AzureRmResourceGroup `
      -Name $resourceGroupName `
      -Location $location `
      -Tag @{Asset_Code = $tagAssetCode} `
      -Force `
      -Verbose
  }
  catch
  {
    Write-Error -Message $_.Exception
    throw $_.Exception
  }

  Write-Output "Azure Resource Group creation completed successfully ($resourceGroupName)" -Verbose
}

# Assign Service Principal Permissions 
if ($resourceGroupOwnerName -ne "")
{  
  Write-Output "Assigning role to Service Principal ($resourceGroupOwnerName)" -Verbose

  # Check if the principal already exists
  $spn = Get-AzureRmADServicePrincipal `
    -DisplayName $resourceGroupOwnerName `
    -ErrorAction "SilentlyContinue"

  if ($spn -ne $null)
  {
    $ra = Get-AzureRmRoleAssignment `
      -ObjectId $spn.Id  `
      -RoleDefinitionName "Contributor" `
      -Scope $rg.ResourceId `
      -ErrorAction "SilentlyContinue"

    if ($ra -ne $null)
    {
      Write-Output "Role already assigned to Service Principal ($resourceGroupOwnerName)" -Verbose
    }
    else 
    {
      try 
      {
        # Assign role to Service Principal
        New-AzureRmRoleAssignment `
          -ObjectId $spn.Id  `
          -RoleDefinitionName "Contributor" `
          -Scope $rg.ResourceId
      }
      catch
      {
          Write-Error -Message $_.Exception
          throw $_.Exception
      }

      Write-Output "Successfully assigned role to Service Principal ($resourceGroupOwnerName)" -Verbose
    }
  }
  else {
    Write-Output "Unable to find Service Principal ($resourceGroupOwnerName)" -Verbose
  }
}

# Assign AD Role Group Permissions 
if ($adRoleGroupName -ne "")
{  
  Write-Output "Assigning role to AD Role Group ($resourceGroupOwnerName)" -Verbose

  # Get the target AD Role Group
  $adrg = Get-AzureRmADGroup `
    -SearchString $adRoleGroupName | ?{$_.DisplayName -eq $adRoleGroupName} `
    -ErrorAction "SilentlyContinue"

  if ($adrg -ne $null)
  {
    $ra2 = Get-AzureRmRoleAssignment `
      -ObjectId $adrg.Id  `
      -RoleDefinitionName "Contributor" `
      -Scope $rg.ResourceId `
      -ErrorAction "SilentlyContinue"

    if ($ra2 -ne $null)
    {
      Write-Output "Role already assigned to AD Role Group ($adRoleGroupName)" -Verbose
    }
    else 
    {
      try 
      {
        # Assign role to Service Principal
        New-AzureRmRoleAssignment `
          -ObjectId $adrg.Id  `
          -RoleDefinitionName "Contributor" `
          -Scope $rg.ResourceId
      }
      catch
      {
          Write-Error -Message $_.Exception
          throw $_.Exception
      }

      Write-Output "Successfully assigned role to AD Role Group ($adRoleGroupName)" -Verbose
    }
  }
  else {
    Write-Output "Unable to find AD Role Group ($adRoleGroupName)" -Verbose
  }
}

Write-Output "Script Complete"