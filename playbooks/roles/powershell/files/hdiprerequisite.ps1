<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Powershell script to create Service Principal and grant it permission for the ADLS

 .PARAMETER subscriptionId
    The subscription id where the template will be deployed.

 .PARAMETER resourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER resourceGroupLocation
    Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.

 .PARAMETER deploymentName
    The deployment name.

 .PARAMETER templateFilePath
    Optional, path to the template file. Defaults to template.json.

 .PARAMETER parametersFilePath
    Optional, path to the parameters file. Defaults to parameters.json. If file is not found, will prompt for parameter values based on template.
#>


param(
 [Parameter(Mandatory=$True)]
 [string]
 $subscriptionId,

 [Parameter(Mandatory=$True)]
 [string]
 $certificateFileDir,
 
 [Parameter(Mandatory=$True)]
 [string]
 $clusterName,
 
 [Parameter(Mandatory=$True)]
 [string]
 $clusterShortName,
 
 [Parameter(Mandatory=$True)]
 [string]
 $certPassword,
 
 [Parameter(Mandatory=$True)]
 [string]
 $KeyVaultName,
 
 [Parameter(Mandatory=$True)]
 [string]
 $dataLakeStorageGen1Name,
 
 [Parameter(Mandatory=$True)]
 [string]
 $SShPwd,
 
 [Parameter(Mandatory=$True)]
 [string]
 $ambariPwd,
 
 [Parameter(Mandatory=$True)]
 [string]
 $ResourceGroupName,
  
 [Parameter(Mandatory=$True)]
 [string]
 $subscriptionId_DataLake,
 
 [Parameter(Mandatory=$True)]
 [string]
 $subscriptionId_KeyVault,

 [Parameter(Mandatory=$True)]
 [string]
 $client_id,
 
 [Parameter(Mandatory=$True)]
 [string]
 $secret,
 
 [Parameter(Mandatory=$True)]
 [string]
 $tenant

)

## above is needed to login to Azure with PowerShell from Ansible/Jenkins translate all params from all file to param names as stated above. 

#Enable RM Alias
Enable-AzureRmAlias
# Log in to your Azure account 
##TO_DO: Use a service principal to automate this

$applicationId = "64d704d4-7816-4ab7-9f26-732795a8ca2d"
$securePassword = "S7*1ik-DX.7K.oW255rg[YbIOCd9ddwD" | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $applicationId, $securePassword
Connect-AzureRmAccount -ServicePrincipal -Credential $credential -TenantId $tenant

#echo  $subscriptionId $certificateFileDir $clusterName $clusterShortname $certPassword $KeyVaultName $dataLakeStorageGen1Name $SShPwd $ambariPwd $ResourceGroupName $subscriptionId_DataLake $subscriptionId_KeyVault

#######################################################
###          Create Managed Identity 		    ###
###		& Permission	                    ###
#######################################################

## below is used to set identity id for managed identy to assign role to AD
Set-AzureRmContext -SubscriptionId $subscriptionId
$identity = Get-AzureRmUserAssignedIdentity -ResourceGroupName $ResourceGroupName -Name "mi-${ClusterShortName}"
Start-Sleep -Seconds 300
#Assign Permissions to Identity
Set-AzureRmContext -SubscriptionId "dd10eed9-865c-4bfa-a260-d3e8fe16b047"
New-AzureRmRoleAssignment -ObjectId $identity.PrincipalId -ResourceGroupName "Liberty-Global-Shared-Resources" -ResourceName "providers/Microsoft.AAD/domainServices/libertyglobal0.onmicrosoft.com" -RoleDefinitionName "HDInsight Domain Services Contributor" -ResourceType "Azure AD Domain Services"
echo $identity
echo "LOG:Managed Identity permission assigned"

#######################################################
###          COnfigure SQL AD Endpoint 		    ###
###		  & peering 			    ###
#######################################################

## All done in Ansible

####################################### 
### 	Create Certificate          ###
#######################################

$certFilePath = "${certificateFileDir}/${clusterName}_certFile.pfx"
$certStartDate = (Get-Date).Date
$certStartDateStr = $certStartDate.ToString("MM/dd/yyyy")
$certEndDate = $certStartDate.AddDays(900)
$certEndDateStr = $certEndDate.ToString("MM/dd/yyyy")
$certName = $clusterName
$certPasswordSecureString = ConvertTo-SecureString $certPassword -AsPlainText -Force
$duration = [timespan]::FromDays(900)

## Create Directory for Certificate
$cert = New-SelfSignedCertificate -OutCertPath $certFilePath -NotBefore  $certStartDate -CommonName $certName -Duration $duration -Passphrase $certPasswordSecureString -CertificateFormat 'pfx'
$certThumbprint = $cert.Thumbprint
echo $cert
echo "LOG:Certificate Created"
####################################### 
### 	Create Service Principal    ###
###	using the Certficate	    ###
#######################################
##$certificatePFX = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certFilePath, $certPasswordSecureString)
$keyValue = [System.Convert]::ToBase64String((Get-Content $certFilePath -AsByteStream))
$certValue = [System.Convert]::ToBase64String($cert.GetRawCertData())
#echo $certName $certValue $certEndDate $certStartDate
$application = New-AzureRMADApplication -DisplayName $certName -CertValue $certValue -EndDate $certEndDate -StartDate $certStartDate -IdentifierUris "https://$clusterName.azurehdinsight.net" 
$servicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $application.ApplicationId
echo $application
echo $servicePrincipal
echo "Service Principal Created"
####################################### 
### 	Store secret into	    ###
###         Key Vault	            ###
#######################################

Set-AzureRmContext -SubscriptionId $subscriptionId_KeyVault

# Store Service Principal ApplicationId
$applicationIdSecureString = ConvertTo-SecureString $servicePrincipal.ApplicationId -AsPlainText -Force
$secret1 = Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name "${clusterName}-AppId" -SecretValue $applicationIdSecureString
 
# Store Servive Principal Id
$idSecureString = ConvertTo-SecureString $servicePrincipal.Id -AsPlainText -Force
$secret2 = Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name "${clusterName}-Id" -SecretValue $idSecureString
 
# Store certificate for Servive Principal 
$CertSecureString = ConvertTo-SecureString $keyValue -AsPlainText -Force
$secret3 = Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name "${clusterName}-Cert" -SecretValue $CertSecureString
# Store Certificate Password for Servive Principal
$secret4 = Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name "${clusterName}-CertPwd" -SecretValue $certPasswordSecureString
 
## Generate random password and pass it as variable for sshpwd
# Store Password for SSH 
$SShPwdSecureString = ConvertTo-SecureString $SShPwd -AsPlainText -Force
$secret5 = Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name "${clusterName}-SShPwd" -SecretValue $SShPwdSecureString

 ## Generate random password and pass it as variable for ambari 
# Store Password for Ambari
$ambariPwdSecureString = ConvertTo-SecureString $ambariPwd -AsPlainText -Force
$secret6 = Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name "${clusterName}-Pwd" -SecretValue $ambariPwdSecureString

echo $secret1 
echo "LOG:Service Principal ApplicationId stored"
echo $secret2 
echo "LOG:Service Principal ID stored"
echo $secret3 
echo "LOG:Certificate Service Principal ID stored"
echo $secret4 
echo "LOG:Certificate Password Service Principal ID stored"
echo $secret5 
echo "LOG:SSH password stored"
echo $secret6 
echo "LOG:Ambari Password stored"

####################################### 
###  Grant permission to Service    ###
###       Principal on ADLS	    ###
#######################################

Set-AzureRmContext -SubscriptionId $subscriptionId_DataLake

$dataLakeStorage = "${dataLakeStorageGen1Name}.azuredatalakestore.net"
$data_path = "/SDP"
#Create folder for the Cluster
New-AzureRmDataLakeStoreItem  -AccountName $dataLakeStorage -Path "/clusters/${clusterName}" -Folder

#Default permission
$Id=$servicePrincipal.Id
$fullAcl="user:${Id}:rwx,default:user:${Id}:rwx"
$newFullAcl = $fullAcl.Split(",")

#Grant permission to cluster folder
Set-AzureRmDataLakeStoreItemAclEntry -AccountName $dataLakeStorage -Path / -AceType User -Id $Id -Permissions All
Set-AzureRmDataLakeStoreItemAclEntry -AccountName $dataLakeStorage -Path /clusters -AceType User -Id $Id -Permissions All
Set-AzureRmDataLakeStoreItemAclEntry -AccountName $dataLakeStorage -Path "/clusters/${clusterName}" -Acl $newFullAcl -Recurse

#Check If SDP folder exist
$path_exist = Test-AzureRmDataLakeStoreItem -AccountName $dataLakeStorage -Path $data_path

if ( !$path_exist ){
	New-AzureRmDataLakeStoreItem  -AccountName $dataLakeStorage -Path $data_path -Folder
}
