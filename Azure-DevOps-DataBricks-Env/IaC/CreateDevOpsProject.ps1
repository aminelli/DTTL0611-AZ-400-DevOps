# Organization url  = https://dev.azure.com/etlforma/
# subscription id   = 8855b22a-640a-41db-bdc5-b423cb3e8feb
# subscription name = Pagamento in base al consumo
# tenant id         = 6c7d8b3b-8c71-4013-be58-e78af03cde75
# Project Name      = CORSO-DTTL0312-TEST

# Install jq
# winget install jqlang.jq

function Write-Msg {
    param ($Msg)
    Write-Output ""
    Write-Output ""
    Write-Host ("### " + $Msg.PadRight(80)) -ForegroundColor white -BackgroundColor DarkBlue
}

function Write-Msg-Status {
    param ($status)
    if ($status -eq $true) {
        Write-Output ""
        Write-Host "   OK   " -ForegroundColor white -BackgroundColor DarkGreen
        Write-Output ""
    } else {
        Write-Host "  ERROR  " -ForegroundColor white -BackgroundColor DarkRed
        exit
    }    
}

function Write-Msg-Warning {
    param ($Msg)
    Write-Host ("   " + $Msg + "    ") -ForegroundColor Black -BackgroundColor DarkYellow
}

function Write-Msg-Success {
    param ($Msg)
    Write-Host ("   " + $Msg + "    ") -ForegroundColor white -BackgroundColor DarkGreen
}
 

function Get-DevOps-Exist-Endpoint-Id {
    param($id, $url, $prjName, $qry)
    $idRet = ''
    $count = 0
    while ($count -le 20) {
        $idRet = az devops service-endpoint list --org $url -p $prjName --query "$qry" -o tsv
        if ($id -eq $idRet) {
            Write-Msg-Success "ID ENDPOINT AZ WHILE --> $idRet"
            break
        } else {
            Write-Msg-Warning "ID ENDPOINT RETRIEVE, Attempt --> $count"
        }
        $count++
        Start-Sleep 2
    }
    Write-Msg-Status ($id -eq $idRet)
    # if ($id -ne $idRet) {
    #     Write-Msg-Status $false
    # }
}

function Get-Id-Valid {
    param($jsonRet, $msg)
    $json = $jsonRet | ConvertFrom-Json
    # Write-Output $jsonRet
    Write-Output "$msg -> $($json.id)" 
    Write-Msg-Status ($json.id -ne $null)
}

Clear-Host

# Write-Msg "START" 
# az config set core.allow_broker=true
# Write-Msg "ACCOUNT CLEAR" 
# az account clear
# Write-Msg "LOGIN"
# az login

Write-Msg "Set default Subscription"
$PRM_SUBSCRIPTION_ID   = "8855b22a-640a-41db-bdc5-b423cb3e8feb"
$PRM_TENANT_ID         = "6c7d8b3b-8c71-4013-be58-e78af03cde75"

az account clear
az login --tenant $PRM_TENANT_ID
az account set -s $PRM_SUBSCRIPTION_ID

Write-Msg "PARAMETERS SETTINGS"
# $PRM_SUBSCRIPTION_ID   = az account list --query "[0].id" -o tsv
# $PRM_TENANT_ID         = az account list --query "[?id=='$PRM_SUBSCRIPTION_ID'].tenantId | [0]" -o tsv
$PRM_SUBSCRIPTION_NAME = az account list --query "[?id=='$PRM_SUBSCRIPTION_ID'].name | [0]" -o tsv

Write-Output "Tenant ID         = $PRM_TENANT_ID"
Write-Output "Subscription ID   = $PRM_SUBSCRIPTION_ID"
Write-Output "Subscription Name = $PRM_SUBSCRIPTION_NAME"


$PRM_CST_PRJ_NAME          = "CORSO-ADB-TEST"
$PRM_CST_ORG_URL           = "https://dev.azure.com/etlforma/"
$PRM_CST_ARM_CONN          = "./arm-templates/devops-create-srv-conn.json"
$PRM_CST_ARM_CONN_GIT      = "./arm-templates/devops-create-srv-conn-git.json"

$PRM_DEVOPS_VARS_GROUP_NAME   = "vars-group-adb-test"

$PRM_DEVOPS_SVC_CONN_NAME     = "svc-conn-rg-adf-test"
$PRM_DEVOPS_SVC_CONN_NAME_GIT = "github"
# $PRM_DEVOPS_SVC_CONN_NAME_GIT = "aminelli"

$PRM_DEVOPS_QUERY_SVC         = "[?name=='$PRM_DEVOPS_SVC_CONN_NAME'].id | [0]"
$PRM_DEVOPS_QUERY_SVC_GIT     = "[?name=='$PRM_DEVOPS_SVC_CONN_NAME_GIT'].id | [0]"

Write-Msg "PARAMETERS SETTINGS for ENDPOINT GITHUB"
$GITHUB_USER                     = "aminelli"
$GITHUB_REPO_NAME                = "Azure-DevOps-DataBricks-Env"
$GITHUB_REPO_NAME_EXT            = $GITHUB_USER + "/Azure-DevOps-DataBricks-Env"
$GITHUB_REPO_URL                 = "https://github.com/aminelli/Azure-DevOps-DataBricks-Env"
$GITHUB_TOKEN                    = "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"
$env:AZURE_DEVOPS_EXT_GITHUB_PAT = $GITHUB_TOKEN


Write-Msg "CREATE DEVOPS PROJECT"
$jsonRet = az devops project create `
    --name $PRM_CST_PRJ_NAME `
    -d "Test" `
    --org $PRM_CST_ORG_URL `
    -s git `
    -p Agile `
    --visibility private 

Get-Id-Valid $jsonRet "Project ID"


Write-Msg "ARM JSON GENERATED"
$CNST_ARM_DEVOPS_CREATE_CONN = @"
{
    "name": "$PRM_DEVOPS_SVC_CONN_NAME",
    "type": "azurerm",
    "url": "https://management.azure.com/",
    "isShared": false,
    "isReady": true,
    "authorization": {
        "parameters": {
            "tenantid": "$PRM_TENANT_ID"
        },
        "scheme": "ServicePrincipal"
    },
    "data": {
        "creationMode": "Automatic",
        "environment": "AzureCloud",
        "scopeLevel": "Subscription",
        "subscriptionId": "$PRM_SUBSCRIPTION_ID",
        "subscriptionName": "$PRM_SUBSCRIPTION_NAME"
    }
}
"@

Write-Msg "SAVE ARM JSON"
$CNST_ARM_DEVOPS_CREATE_CONN | Out-File -Encoding ascii "$PRM_CST_ARM_CONN"


Write-Msg "CREATE DEVOPS ENDPOINT for AZURE Resource Group"
$jsonRet =  az devops service-endpoint create `
    --org $PRM_CST_ORG_URL  `
    -p $PRM_CST_PRJ_NAME `
    --service-endpoint-configuration $PRM_CST_ARM_CONN

Get-Id-Valid $jsonRet "ENDPOINT ID"
$PRM_CST_SRV_CONN_ID = ($jsonRet | ConvertFrom-Json).id
#$PRM_CST_SRV_CONN_ID = $id 

Write-Msg "WAIT ENDPOINT CREATION for AZURE Resource Group"
Get-DevOps-Exist-Endpoint-Id $PRM_CST_SRV_CONN_ID $PRM_CST_ORG_URL $PRM_CST_PRJ_NAME $PRM_DEVOPS_QUERY_SVC

Write-Msg "UPDATE DEVOPS PROJECT ENDPOINT for AZURE Resource Group (--enable-for-all true)"
$jsonRet = az devops service-endpoint update `
    --org $PRM_CST_ORG_URL  `
    -p "$PRM_CST_PRJ_NAME" `
    --enable-for-all "true" `
    --id "$PRM_CST_SRV_CONN_ID"

Get-Id-Valid $jsonRet "ENDPOINT UPDATE AZURE Resource Group ID"
#$id = ($jsonRet | ConvertFrom-Json).id



Write-Msg "SET Parameters for VARIABLES GROUP"
$PRM_DEVOPS_VAR_SUBSCRIPTION_ID           = $PRM_SUBSCRIPTION_ID    
$PRM_DEVOPS_VAR_BASE_NAME                 = "course"    
$PRM_DEVOPS_VAR_LOCATION                  = "northeurope"    
$PRM_DEVOPS_VAR_AZURE_RESOURCEGROUP_NAME  = $PRM_DEVOPS_VAR_BASE_NAME.ToUpper() 
$PRM_DEVOPS_VAR_GITHUB_ACCOUNT            = "aminelli" 
$PRM_DEVOPS_VAR_GITHUB_REPOSITORY_NAME    = "Azure-DataBricks-Notebooks"


Write-Msg "CREATE DEVOPS VARIABLES GROUP"
$jsonRet = az pipelines variable-group create `
    --org $PRM_CST_ORG_URL `
    -p "$PRM_CST_PRJ_NAME" `
    --authorize true `
    --desc "Variabili di test" `
    --name "$PRM_DEVOPS_VARS_GROUP_NAME" `
    --variables `
    BASE_NAME="$PRM_DEVOPS_VAR_BASE_NAME" `
    LOCATION=$PRM_DEVOPS_VAR_LOCATION `
    SUBSCRIPTION_ID=$PRM_DEVOPS_VAR_SUBSCRIPTION_ID `
    RESOURCE_GROUP_NAME=$PRM_DEVOPS_VAR_AZURE_RESOURCEGROUP_NAME `
    SRV_CONN_NAME=$PRM_DEVOPS_SVC_CONN_NAME `
    GITHUB_ACCOUNT=$PRM_DEVOPS_VAR_GITHUB_ACCOUNT `
    GITHUB_REPO=$PRM_DEVOPS_VAR_GITHUB_REPOSITORY_NAME

Get-Id-Valid $jsonRet "variable-group ID"





$CNST_ARM_DEVOPS_CREATE_CONN = @"
{
    "name": "$PRM_DEVOPS_SVC_CONN_NAME_GIT",
    "type": "GitHub",
    "url": "https://github.com",
    "isShared": false,
    "isReady": true,
    "authorization": {
        "parameters": {
            "AccessToken": "$GITHUB_TOKEN"
        },
        "scheme": "Token"
    }
}
"@

# "scheme": "InstallationToken"

Write-Msg "SAVE ARM JSON"
$CNST_ARM_DEVOPS_CREATE_CONN | Out-File -Encoding ascii "$PRM_CST_ARM_CONN_GIT"


Write-Msg "CREATE DEVOPS ENDPOINT GITHUB"
$jsonRet =  az devops service-endpoint create `
    --org $PRM_CST_ORG_URL  `
    -p $PRM_CST_PRJ_NAME `
    --service-endpoint-configuration $PRM_CST_ARM_CONN_GIT

Get-Id-Valid $jsonRet "ENDPOINT ID"
$PRM_CST_SRV_CONN_GITHUB_ID = ($jsonRet | ConvertFrom-Json).id
#$PRM_CST_SRV_CONN_GITHUB_ID = $id 

Write-Msg "WAIT ENDPOINT CREATION GITHUB"
Get-DevOps-Exist-Endpoint-Id $PRM_CST_SRV_CONN_GITHUB_ID $PRM_CST_ORG_URL $PRM_CST_PRJ_NAME $PRM_DEVOPS_QUERY_SVC_GIT


Write-Msg "UPDATE DEVOPS ENDPOINT GITHUB (--enable-for-all true)"
$jsonRet = az devops service-endpoint update `
    --org $PRM_CST_ORG_URL  `
    -p "$PRM_CST_PRJ_NAME" `
    --enable-for-all "true" `
    --id "$PRM_CST_SRV_CONN_GITHUB_ID"

Get-Id-Valid $jsonRet "ENDPOINT GITHUB ID"    


# for ($i = 1; $i -le 100; $i++ ) {
#     Write-Progress -Activity "In Progress" -Status "$i% Complete:" -PercentComplete $i
#     Start-Sleep -Milliseconds 250
# }

Write-Msg "CREATE NEW PIPELINE --> 'CREATE ENVIRONMENT'"
$jsonRet = az pipelines create `
    --org $PRM_CST_ORG_URL  `
    -p "$PRM_CST_PRJ_NAME" `
    --name "CREATE ENVIRONMENT" `
    --branch "main" `
    --repository "$GITHUB_REPO_NAME_EXT" `
    --yaml-path "/IaC/01-create-environment-adb.yml" `
    --repository-type github `
    --skip-first-run true `
    --service-connection "$PRM_CST_SRV_CONN_GITHUB_ID"

Get-Id-Valid $jsonRet "PIPELINE ID"    

Write-Msg "CREATE NEW PIPELINE --> 'DELETE ENVIRONMENT'"
$jsonRet = az pipelines create `
    --org $PRM_CST_ORG_URL  `
    -p "$PRM_CST_PRJ_NAME" `
    --name "DELETE ENVIRONMENT" `
    --branch "main" `
    --repository "$GITHUB_REPO_NAME_EXT" `
    --yaml-path "/IaC/99-delete-environment-adb.yml" `
    --repository-type github `
    --skip-first-run true `
    --service-connection "$PRM_CST_SRV_CONN_GITHUB_ID"

Get-Id-Valid $jsonRet "PIPELINE ID"    

# Write-Msg "FASE 2 - Esecuzione Pipelines "
# Pause
# 
# Write-Msg "RUN PIPELINE --> 'CREATE ENVIRONMENT'"
# az pipelines run `
#     --org $PRM_CST_ORG_URL `
#     -p "$PRM_CST_PRJ_NAME" `
#     --name "CREATE ENVIRONMENT"


