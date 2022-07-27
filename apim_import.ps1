param(
    [Parameter(Mandatory=$true)]
    [string]$apimApiId,
    [Parameter(Mandatory=$true)]
    [string]$apimResourceGroupName,
    [Parameter(Mandatory=$true)]
    [string]$apiDisplayName,
    [Parameter(Mandatory=$true)]
    [string]$apimServiceName,
    [Parameter(Mandatory=$true)]
    [string]$apiSpecificationUrl,
    [Parameter(Mandatory=$true)]
    [string]$apiSpecificationFormat,
    [Parameter(Mandatory=$true)]
    [string]$apiPath,
    [Parameter(Mandatory=$true)]
    [string]$apiVersion,
    [Parameter(Mandatory=$true)]
    [string]$apiServiceUrl,
    [Parameter(Mandatory=$true)]
    [string]$apiProtocols,
    [Parameter(Mandatory=$true)]
    [string]$productName,
    [Parameter(Mandatory=$true)]
    [string]$productDescription,
    [Parameter(Mandatory=$true)]
    [string]$productState,
    [Parameter(Mandatory=$true)]
    [string]$subscriptionKeyName,
    [Parameter(Mandatory=$true)]
    [string]$subscriptionKeyParamName,
    [Parameter(Mandatory=$true)]
    [string]$subscriptionRequired,
    [Parameter(Mandatory=$true)]
    [string]$env,
    [Parameter(Mandatory=$true)]
    [string]$dir
)
$apiName = $apiDisplayName + " " + $apiVersion

Write-Host "[VERSION SET] Looking up version set"
$versionSetLookup = az apim api versionset list -g $apimResourceGroupName -n $apimServiceName --query "[?displayName=='$apiDisplayName'].name" --output tsv
if($null -eq $versionSetLookup)
{
    Write-Host "[VERSION SET] Version set NOT FOUND for: $apiDisplayName, creating a new one. "
    az apim api versionset create -g $apimResourceGroupName -n $apimServiceName --display-name "$apiDisplayName" `--versioning-scheme "Segment"
    $versionSetLookup = az apim api versionset list -g $apimResourceGroupName -n $apimServiceName --query "[?displayName=='$apiDisplayName'].name"
}

$versionSetId = $versionSetLookup
Write-Host "[VERSION SET] version set is: $versionSetId"
Write-Host  "[IMPORT] Importing Swagger: $apiSpecificationFormat "
az apim api import --api-id $apimApiId --display-name $apiName --path $apiPath --service-url $apiServiceUrl -g $apimResourceGroupName -n $apimServiceName --specification-format $apiSpecificationFormat --specification-url $apiSpecificationUrl --api-version-set-id $versionSetId --api-version $apiVersion --subscription-key-header-name $subscriptionKeyName --subscription-key-query-param-name $subscriptionKeyParamName --subscription-required $subscriptionRequired
$apiId = az apim api list --filter-display-name $apiName -g $apimResourceGroupName -n $apimServiceName --query "[?displayName=='$apiName'].id"
Write-Host  "[IMPORT] Imported API $apiName : $api" 
Start-Sleep -Seconds 10

Write-Host "[PRODUCT] Looking up product"
$productId = az apim product list -g $apimResourceGroupName -n $apimServiceName --query "[?displayName=='$productName'].name" --output tsv
if($null -eq $productId){
    Write-Host "[PRODUCT] Product not found creating new product "
    az apim product create -g $apimResourceGroupName -n $apimServiceName --product-name $productName
    $productId = az apim product list -g $apimResourceGroupName -n $apimServiceName --query "[?displayName=='$productName'].name"
    Write-Host "[PRODUCT] Created new product $productName id = $product"
}

Write-Host "[PRODUCT] Adding product $productName with the id $productId to the API $apiDisplayName $apiVersion that has the id $apiId"
az apim product api add --api-id $apimApiId --product-id $productId -g $apimResourceGroupName -n $apimServiceName

Write-Host "[ACCOUNT] querying subscription ID"
$subId = az account show --query id --output tsv

$jsonPath = "$dir/policy-$env.json"
Write-Host "[REST CALL] making rest call to import policy definitions from $jsonPath"
Test-Path -Path $jsonPath -PathType Leaf
$uri = "https://management.azure.com/subscriptions/$subId/resourceGroups/$apimResourceGroupName/providers/Microsoft.ApiManagement/service/$apimServiceName/apis/$apimApiId/policies/policy?api-version=2021-08-01"
Write-Host "[REST CALL] uri: $uri"
az rest --method PUT --uri $uri --body @$jsonPath