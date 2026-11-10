param(
    [switch]$DryRun,
    [switch]$SkipBackup,
    [string]$WebContainer = 'ace-joao-okabe-db-1',
    [string]$MobileContainer = 'backend-banco-1',
    [string]$WebHost = 'host.docker.internal',
    [int]$WebPort = 5433,
    [string]$WebDatabase = 'ace',
    [string]$WebUser = 'ace',
    [string]$WebPassword = 'ace_local_dev',
    [string]$MobileDatabase = 'aether',
    [string]$MobileUser = 'postgres'
)

$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$projectRoot = Split-Path -Parent $PSScriptRoot
$aceRoot = Split-Path -Parent $projectRoot
$backupDir = Join-Path $aceRoot "backups\sync_web_mobile_$stamp"
$logDir = Join-Path $aceRoot 'logs'
$sqlPath = Join-Path $PSScriptRoot 'sync_web_to_mobile.sql'
$containerSql = "/tmp/ace_sync_web_to_mobile_$stamp.sql"

function Assert-Container([string]$Name, [string]$ExpectedDatabase) {
    $running = docker inspect --format '{{.State.Running}}' $Name 2>$null
    if ($LASTEXITCODE -ne 0 -or $running -ne 'true') {
        throw "Container obrigatorio nao esta em execucao: $Name"
    }
    $database = if ($Name -eq $WebContainer) {
        docker exec $Name psql -U $WebUser -d $WebDatabase -At -c 'SELECT current_database()'
    } else {
        docker exec $Name psql -U $MobileUser -d $MobileDatabase -At -c 'SELECT current_database()'
    }
    if ($LASTEXITCODE -ne 0 -or $database -ne $ExpectedDatabase) {
        throw "O container $Name nao corresponde ao database esperado $ExpectedDatabase."
    }
}

Assert-Container $WebContainer $WebDatabase
Assert-Container $MobileContainer $MobileDatabase

if (-not $SkipBackup -and -not $DryRun) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $webTmp = "/tmp/ace_web_pre_sync_$stamp.dump"
    $mobileTmp = "/tmp/ace_mobile_pre_sync_$stamp.dump"

    docker exec $WebContainer pg_dump -U $WebUser -d $WebDatabase -Fc -f $webTmp
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar backup do banco Web.' }
    docker cp "${WebContainer}:$webTmp" (Join-Path $backupDir 'web_ace.dump') | Out-Null

    docker exec $MobileContainer pg_dump -U $MobileUser -d $MobileDatabase -Fc -f $mobileTmp
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar backup do banco Mobile.' }
    docker cp "${MobileContainer}:$mobileTmp" (Join-Path $backupDir 'mobile_aether.dump') | Out-Null
}

New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$logPath = Join-Path $logDir "sync_web_mobile_$stamp.log"
docker cp $sqlPath "${MobileContainer}:$containerSql" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Falha ao copiar o script SQL para o container Mobile.' }

$dryRunValue = if ($DryRun) { 'true' } else { 'false' }
$previousErrorPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
docker exec $MobileContainer psql -X -U $MobileUser -d $MobileDatabase `
    -v "web_host=$WebHost" `
    -v "web_port=$WebPort" `
    -v "web_database=$WebDatabase" `
    -v "web_user=$WebUser" `
    -v "web_password=$WebPassword" `
    -v "dry_run=$dryRunValue" `
    -f $containerSql 2>&1 | Tee-Object -FilePath $logPath
$psqlExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorPreference

if ($psqlExitCode -ne 0) {
    throw "Sincronizacao falhou. Consulte o log: $logPath"
}

Write-Output "Log: $logPath"
if (-not $SkipBackup -and -not $DryRun) {
    Write-Output "Backups: $backupDir"
}
