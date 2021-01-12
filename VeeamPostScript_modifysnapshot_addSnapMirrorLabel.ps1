# ログ出力先
$logFile = $PSScriptRoot + "¥log¥`Veeamlogfile.txt"

# LogMessage関数を作成
function LogMessage($Message){
    $msg = "$(Get-Date -Format G): $Message"
    Write-Output $msg
    $msg >> $logFile
}

# Veeam Command Enable
Add-PSSnapin VeeamPSSnapin

# Get Snapshot List
# 3つの条件に該当するスナップショットを抽出 : CreateTimeBackupが1時間以内 and Job Nameに"*bkupp*"を含む and Snapshot Nameに"VP-*"を含む 
try {
    #$VPSNAPLIST=Get-StoragePluginSnapshot  |Where-Object {$_.CreationTimeSrv -gt (Get-Date).AddHours(-1) -and $_.Name -Like '*Backup*' -and  $_.Name -Like 'VP-*'} | Select-Object name ,internalid
    #$VPSNAPLIST=Get-StoragePluginSnapshot  |Where-Object {$_.CreationTimeSrv -gt (Get-Date).AddHours(-1) -and $_.Name -Like '*ddddssss*' -and  $_.Name -Like 'VP-*'} | Select-Object name ,internalid
    $VPSNAPLIST=Get-StoragePluginSnapshot  |Where-Object {$_.CreationTimeSrv -gt (Get-Date).AddHours(-1) -and $_.Name -Like '*bkup*' -and  $_.Name -Like 'VP-*'} | Select-Object name ,internalid
    LogMessage "Target SnapshotName:JobName SnapID"
    LogMessage $VPSNAPLIST.Name
    LogMessage $VPSNAPLIST.Internalid
} catch {
    LogMessage $error[0]
}

# Snapshot List is Null
if([string]::IsNullOrEmpty($VPSNAPLIST))
 {
        # NULL や '' の場合はこちら。
        LogMessage "Snapshot List is Null"
        exit 11
 }

# Enable Tls 1.2 
 [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Ignore Cert 
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

# Set Auth
# Element UIのログインユーザ名とパスワードを入力
$USER = ""
$PASS = ""
$SECPASS = ConvertTo-SecureString $PASS -AsPlainText -Force
$CRED = New-Object System.Management.Automation.PSCredential($USER, $SECPASS)

# Set URI
# Element APIのエンドポイントを入力 e.g. https://10.128.211.100/json-rpc/12.2
$API = ""

# Set Snapmirror Label
# Snapmirrorのラベル名を入力 e.g. set-from-ps-gt-1hour
$SMLABEL=""

foreach ($i in $VPSNAPLIST.internalid) {
    # Split SnapName/JobName

    # Set SnapName/JobName/SnapID
    $SnapID=$i

    # Set Body
    $BodyJSON = @"
    {
        "method": "ModifySnapshot",
        "params": {
            "snapshotID": $SnapID,
    	    "snapMirrorLabel": "$SMLABEL"
        },
        "id": 1
    }
"@

    # set Snapmirror Label by RestAPI 
    try {
      $Result=Invoke-RestMethod -Uri $API -Body $BodyJSON -ContentType 'application/json' -Method Post  -Credential $CRED
      $Message="SnapID : $SnapID set Snapmirror Label" 
      LogMessage $Message 
    } catch {
      LogMessage $error[0]

    }
}
