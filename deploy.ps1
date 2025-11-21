# Azure Red Hat OpenShift Deployment Script
# This script uses subscription-level deployment to manage multiple resource groups

param(
    [Parameter(Mandatory=$false)]
    [string]$EnvFile = ".env",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipValidation,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# Function to read .env file
function Read-EnvFile {
    param([string]$FilePath)
    
    if (!(Test-Path $FilePath)) {
        Write-ColorOutput "✗ Environment file not found: $FilePath" "Red"
        Write-ColorOutput "Please create a .env file with required parameters." "Yellow"
        exit 1
    }
    
    Write-ColorOutput "Reading environment variables from: $FilePath" "Gray"
    $env:SKIP_VALIDATION = $SkipValidation.ToString().ToLower()
    
    Get-Content $FilePath | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*?)\s*=\s*(.*?)\s*$') {
            $name = $matches[1]
            $value = $matches[2]
            $value = $value -replace '^[''"]|[''"]$', ''
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
            
            if ($name -like "*SECRET*" -or $name -like "*PASSWORD*" -or $name -like "*KEY*") {
                Write-ColorOutput "  $name = [REDACTED]" "Gray"
            } else {
                Write-ColorOutput "  $name = $value" "Gray"
            }
        }
    }
}

# Function to write colored output
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

# Function to check prerequisites
function Test-Prerequisites {
    Write-ColorOutput "Checking prerequisites..." "Yellow"
    
    try {
        $azVersion = az --version | Select-String "azure-cli" | Select-Object -First 1
        Write-ColorOutput "✓ Azure CLI installed: $azVersion" "Green"
    }
    catch {
        Write-ColorOutput "✗ Azure CLI not found. Please install Azure CLI." "Red"
        exit 1
    }
    
    try {
        $account = az account show | ConvertFrom-Json
        Write-ColorOutput "✓ Logged into Azure as: $($account.user.name)" "Green"
        Write-ColorOutput "  Subscription: $($account.name) ($($account.id))" "Gray"
    }
    catch {
        Write-ColorOutput "✗ Not logged into Azure. Please run 'az login'." "Red"
        exit 1
    }
    
    if (!(Test-Path "pullsecret.txt")) {
        Write-ColorOutput "✗ Pull secret file not found: pullsecret.txt" "Red"
        exit 1
    }
    Write-ColorOutput "✓ Pull secret file found" "Green"
}

# Function to get Service Principal Object ID
function Get-ServicePrincipalObjectId {
    param([string]$ClientId)
    
    Write-ColorOutput "Retrieving Service Principal Object ID..." "Yellow"
    
    try {
        $spInfo = az ad sp show --id $ClientId --query "{objectId:id,displayName:displayName}" | ConvertFrom-Json
        if ($spInfo -and $spInfo.objectId) {
            Write-ColorOutput "✓ Service Principal: $($spInfo.displayName)" "Green"
            return $spInfo.objectId
        }
        else {
            Write-ColorOutput "✗ Could not find Service Principal" "Red"
            exit 1
        }
    }
    catch {
        Write-ColorOutput "✗ Failed to retrieve Service Principal: $($_.Exception.Message)" "Red"
        exit 1
    }
}

# Function to get ARO Resource Provider Object ID
function Get-AroResourceProviderObjectId {
    $aroRpApplicationId = "f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875"
    
    Write-ColorOutput "Retrieving ARO Resource Provider Object ID..." "Yellow"
    
    try {
        $aroRpObjectId = az ad sp show --id $aroRpApplicationId --query "id" -o tsv
        if ($aroRpObjectId) {
            Write-ColorOutput "✓ ARO Resource Provider found" "Green"
            return $aroRpObjectId
        }
        else {
            Write-ColorOutput "✗ Could not find ARO Resource Provider" "Red"
            exit 1
        }
    }
    catch {
        Write-ColorOutput "✗ Failed to retrieve ARO RP: $($_.Exception.Message)" "Red"
        exit 1
    }
}

# Function to get latest OpenShift version
function Get-LatestOpenShiftVersion {
    param([string]$Location)
    
    Write-ColorOutput "Retrieving latest OpenShift version for $Location..." "Yellow"
    
    try {
        $versions = az aro get-versions --location $Location | ConvertFrom-Json
        if ($versions -and $versions.Count -gt 0) {
            $latestVersion = $versions | Sort-Object -Descending | Select-Object -First 1
            Write-ColorOutput "✓ Latest OpenShift version: $latestVersion" "Green"
            return $latestVersion
        }
        else {
            Write-ColorOutput "✗ Could not retrieve OpenShift versions" "Red"
            exit 1
        }
    }
    catch {
        Write-ColorOutput "✗ Failed to retrieve OpenShift versions: $($_.Exception.Message)" "Red"
        exit 1
    }
}

# Function to prepare parameters
function Set-DeploymentParameters {
    Write-ColorOutput "Preparing deployment parameters..." "Yellow"
    
    # Get all environment variables
    $clientSecret = [Environment]::GetEnvironmentVariable('CLIENT_SECRET')
    $clientId = [Environment]::GetEnvironmentVariable('CLIENT_ID')
    $location = [Environment]::GetEnvironmentVariable('LOCATION')
    $networkRgName = [Environment]::GetEnvironmentVariable('NETWORK_RESOURCE_GROUP_NAME')
    $clusterRgName = [Environment]::GetEnvironmentVariable('CLUSTER_RESOURCE_GROUP_NAME')
    $vnetName = [Environment]::GetEnvironmentVariable('VNET_NAME')
    $vnetAddressPrefix = [Environment]::GetEnvironmentVariable('VNET_ADDRESS_PREFIX')
    $clusterName = [Environment]::GetEnvironmentVariable('ARO_CLUSTER_NAME')
    $domain = [Environment]::GetEnvironmentVariable('DOMAIN')
    $apiServerVisibility = [Environment]::GetEnvironmentVariable('API_SERVER_VISIBILITY')
    $ingressVisibility = [Environment]::GetEnvironmentVariable('INGRESS_VISIBILITY')
    $masterVmSize = [Environment]::GetEnvironmentVariable('MASTER_VM_SIZE')
    $workerVmSize = [Environment]::GetEnvironmentVariable('WORKER_VM_SIZE')
    $workerNodeCount = [int][Environment]::GetEnvironmentVariable('WORKER_NODE_COUNT')
    $clusterResourcesRgName = [Environment]::GetEnvironmentVariable('CLUSTER_RESOURCES_RG_NAME')
    
    # Get Object IDs
    $spObjectId = Get-ServicePrincipalObjectId -ClientId $clientId
    $aroRpObjectId = Get-AroResourceProviderObjectId
    
    # Get latest OpenShift version
    $aroVersion = Get-LatestOpenShiftVersion -Location $location
    
    # Create parameters content
    $parametersContent = @{
        '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
        contentVersion = "1.0.0.0"
        parameters = @{
            location = @{ value = $location }
            networkResourceGroupName = @{ value = $networkRgName }
            clusterResourceGroupName = @{ value = $clusterRgName }
            vnetName = @{ value = $vnetName }
            vnetAddressPrefix = @{ value = $vnetAddressPrefix }
            aroClusterName = @{ value = $clusterName }
            aroVersion = @{ value = $aroVersion }
            masterVmSize = @{ value = $masterVmSize }
            workerVmSize = @{ value = $workerVmSize }
            workerNodeCount = @{ value = $workerNodeCount }
            apiServerVisibility = @{ value = $apiServerVisibility }
            ingressVisibility = @{ value = $ingressVisibility }
            servicePrincipalClientId = @{ value = $clientId }
            servicePrincipalObjectId = @{ value = $spObjectId }
            aroResourceProviderObjectId = @{ value = $aroRpObjectId }
            servicePrincipalClientSecret = @{ value = $clientSecret }
        }
    }
    
    # Add optional parameters
    if (![string]::IsNullOrEmpty($domain)) {
        $parametersContent.parameters.domain = @{ value = $domain }
    }
    
    if (![string]::IsNullOrEmpty($clusterResourcesRgName)) {
        $parametersContent.parameters.clusterResourcesResourceGroupName = @{ value = $clusterResourcesRgName }
    }
    
    # Save parameters to file
    $parametersPath = "infra/parameters-deployment.json"
    $parametersContent | ConvertTo-Json -Depth 10 | Out-File -FilePath $parametersPath -Encoding UTF8
    Write-ColorOutput "✓ Parameters file created" "Green"
    
    return $parametersPath
}

# Function to check if cluster exists
function Test-ClusterExists {
    param(
        [string]$ClusterName,
        [string]$ResourceGroupName
    )
    
    Write-ColorOutput "Checking if cluster already exists..." "Yellow"
    
    try {
        $cluster = az aro show `
            --name $ClusterName `
            --resource-group $ResourceGroupName `
            --query "id" -o tsv 2>$null
        
        if ($cluster) {
            Write-ColorOutput "✓ Cluster '$ClusterName' already exists in resource group '$ResourceGroupName'" "Green"
            return $true
        }
        else {
            Write-ColorOutput "✓ Cluster does not exist, proceeding with deployment" "Green"
            return $false
        }
    }
    catch {
        Write-ColorOutput "✓ Cluster does not exist, proceeding with deployment" "Green"
        return $false
    }
}

# Function to validate deployment
function Test-Deployment {
    param([string]$ParametersPath)
    
    $skipValidation = [Environment]::GetEnvironmentVariable('SKIP_VALIDATION')
    
    if ($skipValidation -eq 'true') {
        Write-ColorOutput "Skipping deployment validation" "Yellow"
        return
    }
    
    Write-ColorOutput "Validating deployment at subscription scope..." "Yellow"
    
    $validationResult = az deployment sub validate `
        --location ([Environment]::GetEnvironmentVariable('LOCATION')) `
        --template-file "infra/main.bicep" `
        --parameters "@$ParametersPath" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✓ Deployment validation passed" "Green"
    }
    else {
        Write-ColorOutput "✗ Deployment validation failed" "Red"
        Write-ColorOutput $validationResult "Red"
        exit 1
    }
}

# Function to deploy infrastructure
function Deploy-Infrastructure {
    param(
        [string]$ParametersPath,
        [bool]$WhatIfMode
    )
    
    $location = [Environment]::GetEnvironmentVariable('LOCATION')
    $deploymentName = "aro-split-rg-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    if ($WhatIfMode) {
        Write-ColorOutput "Running What-If analysis..." "Yellow"
        
        az deployment sub what-if `
            --name $deploymentName `
            --location $location `
            --template-file "infra/main.bicep" `
            --parameters "@$ParametersPath"
        
        Write-ColorOutput "`nWhat-If analysis complete. No changes were made." "Cyan"
        return
    }
    
    Write-ColorOutput "Starting deployment at subscription scope..." "Yellow"
    Write-ColorOutput "This will create two resource groups and deploy infrastructure..." "Yellow"
    Write-ColorOutput "Estimated time: 35-45 minutes" "Yellow"
    
    az deployment sub create `
        --name $deploymentName `
        --location $location `
        --template-file "infra/main.bicep" `
        --parameters "@$ParametersPath" `
        --verbose
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✓ Deployment completed successfully" "Green"
        
        # Get deployment outputs
        $outputs = az deployment sub show `
            --name $deploymentName `
            --query "properties.outputs" | ConvertFrom-Json
        
        Write-ColorOutput "`nDeployment Outputs:" "Cyan"
        Write-ColorOutput "Network RG: $($outputs.networkResourceGroupName.value)" "White"
        Write-ColorOutput "Cluster RG: $($outputs.clusterResourceGroupName.value)" "White"
        Write-ColorOutput "VNet Name: $($outputs.vnetName.value)" "White"
        Write-ColorOutput "Cluster Name: $($outputs.aroClusterName.value)" "White"
        Write-ColorOutput "API Server: $($outputs.aroApiServerUrl.value)" "White"
        Write-ColorOutput "Console: $($outputs.aroConsoleUrl.value)" "White"
        Write-ColorOutput "Domain: $($outputs.aroDomain.value)" "White"
        
        return $outputs
    }
    else {
        Write-ColorOutput "✗ Deployment failed" "Red"
        exit 1
    }
}

# Function to get cluster credentials
function Get-ClusterCredentials {
    param($Outputs)
    
    $clusterName = $Outputs.aroClusterName.value
    $clusterRgName = $Outputs.clusterResourceGroupName.value
    
    Write-ColorOutput "`nGetting cluster credentials..." "Yellow"
    
    $credentials = az aro list-credentials `
        --name $clusterName `
        --resource-group $clusterRgName | ConvertFrom-Json
    
    if ($credentials) {
        Write-ColorOutput "`nCluster Credentials:" "Cyan"
        Write-ColorOutput "Username: $($credentials.kubeadminUsername)" "White"
        Write-ColorOutput "Password: $($credentials.kubeadminPassword)" "White"
        
        az aro get-admin-kubeconfig `
            --name $clusterName `
            --resource-group $clusterRgName `
            --file "kubeconfig-$clusterName"
        
        Write-ColorOutput "✓ Kubeconfig saved to: kubeconfig-$clusterName" "Green"
    }
}

# Function to prepare manifest files
function Update-ManifestFiles {
    param($ClusterName)
    
    Write-ColorOutput "`nPreparing manifest files..." "Yellow"
    
    if (!(Test-Path "manifest-templates")) {
        Write-ColorOutput "⚠ manifest-templates directory not found, skipping manifest preparation" "Yellow"
        return
    }
    
    $templateFiles = Get-ChildItem -Path "manifest-templates\*.yaml" -ErrorAction SilentlyContinue
    
    if ($templateFiles.Count -eq 0) {
        Write-ColorOutput "⚠ No template files found in manifest-templates" "Yellow"
        return
    }
    
    # Get infrastructure name from cluster
    Write-ColorOutput "Retrieving cluster infrastructure name..." "Gray"
    $infraName = ""
    try {
        $infraName = oc get infrastructure cluster -o jsonpath='{.status.infrastructureName}' 2>$null
        if ($infraName) {
            Write-ColorOutput "✓ Infrastructure name: $infraName" "Green"
        } else {
            Write-ColorOutput "⚠ Could not retrieve infrastructure name, using cluster name" "Yellow"
            $infraName = $ClusterName
        }
    }
    catch {
        Write-ColorOutput "⚠ Could not retrieve infrastructure name, using cluster name" "Yellow"
        $infraName = $ClusterName
    }
    
    $copiedCount = 0
    foreach ($file in $templateFiles) {
        try {
            $content = Get-Content $file.FullName -Raw
            $content = $content -replace '<CLUSTERNAME>', $ClusterName
            $content = $content -replace '<INFRANAME>', $infraName
            $destinationPath = "manifests\$($file.Name)"
            Set-Content -Path $destinationPath -Value $content -NoNewline
            $copiedCount++
        }
        catch {
            Write-ColorOutput "⚠ Failed to process $($file.Name): $($_.Exception.Message)" "Yellow"
        }
    }
    
    if ($copiedCount -gt 0) {
        Write-ColorOutput "✓ Processed $copiedCount manifest files with cluster name: $ClusterName" "Green"
    }
}

# Function to show summary
function Show-Summary {
    param($Outputs)
    
    Write-ColorOutput "`n$('='*60)" "Cyan"
    Write-ColorOutput "DEPLOYMENT COMPLETED SUCCESSFULLY!" "Green"
    Write-ColorOutput "$('='*60)" "Cyan"
    
    Write-ColorOutput "`nResource Groups Created:" "Yellow"
    Write-ColorOutput "  Network: $($Outputs.networkResourceGroupName.value)" "White"
    Write-ColorOutput "  Cluster: $($Outputs.clusterResourceGroupName.value)" "White"
    
    $clusterName = $Outputs.aroClusterName.value
    
    Write-ColorOutput "`nNext Steps:" "Yellow"
    Write-ColorOutput "1. Connect to cluster:" "White"
    Write-ColorOutput "   `$env:KUBECONFIG = `"`$PWD\kubeconfig-$clusterName`"" "Gray"
    Write-ColorOutput "   kubectl get nodes" "Gray"
    
    Write-ColorOutput "`n2. Access console:" "White"
    Write-ColorOutput "   $($Outputs.aroConsoleUrl.value)" "Gray"
    
    Write-ColorOutput "`n3. Deploy infrastructure nodes:" "White"
    Write-ColorOutput "   kubectl apply -f manifests/infra-nodes-internal-zone1.yaml" "Gray"
    Write-ColorOutput "   kubectl apply -f manifests/infra-nodes-internal-zone2.yaml" "Gray"
    Write-ColorOutput "   kubectl apply -f manifests/infra-nodes-internal-zone3.yaml" "Gray"
    Write-ColorOutput "   kubectl apply -f manifests/infra-nodes-external-zone1.yaml" "Gray"
    Write-ColorOutput "   kubectl apply -f manifests/infra-nodes-external-zone2.yaml" "Gray"
    Write-ColorOutput "   kubectl apply -f manifests/infra-nodes-external-zone3.yaml" "Gray"
    
    Write-ColorOutput "`n4. Move default ingress to infra nodes:" "White"
    Write-ColorOutput "   kubectl apply -f manifests/default-ingress-to-infra.yaml" "Gray"
    
    Write-ColorOutput "`n5. Deploy ingress controllers:" "White"
    Write-ColorOutput "   kubectl apply -f manifests/ingress-controller-internal.yaml" "Gray"
    Write-ColorOutput "   kubectl apply -f manifests/ingress-controller-external.yaml" "Gray"
}

# Main execution
Write-ColorOutput "Azure Red Hat OpenShift - Split Resource Group Deployment" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"
Write-ColorOutput "Subscription-level deployment with split resource groups" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

try {
    Read-EnvFile -FilePath $EnvFile
    Test-Prerequisites
    
    $clusterName = [Environment]::GetEnvironmentVariable('ARO_CLUSTER_NAME')
    $clusterRgName = [Environment]::GetEnvironmentVariable('CLUSTER_RESOURCE_GROUP_NAME')
    
    # Check if cluster already exists
    $clusterExists = Test-ClusterExists -ClusterName $clusterName -ResourceGroupName $clusterRgName
    
    if ($clusterExists) {
        Write-ColorOutput "`nCluster already exists, skipping deployment..." "Yellow"
        
        # Get cluster information
        Write-ColorOutput "`nRetrieving cluster information..." "Yellow"
        $clusterInfo = az aro show `
            --name $clusterName `
            --resource-group $clusterRgName | ConvertFrom-Json
        
        # Create outputs object matching deployment output format
        $outputs = @{
            networkResourceGroupName = @{ value = [Environment]::GetEnvironmentVariable('NETWORK_RESOURCE_GROUP_NAME') }
            clusterResourceGroupName = @{ value = $clusterRgName }
            vnetName = @{ value = [Environment]::GetEnvironmentVariable('VNET_NAME') }
            aroClusterName = @{ value = $clusterName }
            aroApiServerUrl = @{ value = $clusterInfo.properties.apiserverProfile.url }
            aroConsoleUrl = @{ value = $clusterInfo.properties.consoleProfile.url }
            aroDomain = @{ value = $clusterInfo.properties.clusterProfile.domain }
        }
        
        if (!$WhatIf) {
            Get-ClusterCredentials -Outputs $outputs
            Update-ManifestFiles -ClusterName $clusterName
            Show-Summary -Outputs $outputs
        }
    }
    else {
        # Proceed with deployment
        $parametersPath = Set-DeploymentParameters
        Test-Deployment -ParametersPath $parametersPath
        
        $outputs = Deploy-Infrastructure -ParametersPath $parametersPath -WhatIfMode $WhatIf
        
        if (!$WhatIf) {
            Get-ClusterCredentials -Outputs $outputs
            Update-ManifestFiles -ClusterName $outputs.aroClusterName.value
            Show-Summary -Outputs $outputs
        }
    }
    
    Write-ColorOutput "`nDeployment script completed!" "Green"
}
catch {
    Write-ColorOutput "✗ An error occurred: $($_.Exception.Message)" "Red"
    Write-ColorOutput $_.ScriptStackTrace "Red"
    exit 1
}
finally {
    if (Test-Path "infra/parameters-deployment.json") {
        Remove-Item "infra/parameters-deployment.json" -Force
    }
}
