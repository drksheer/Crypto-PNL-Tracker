### Check to make sure powershell is ran as admin
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}

Install-Module PSSQLite
Import-Module PSSQLite

$global:path = "H:\dev\projects\apps\pnl-tracker\PNLTracker\db-files"
$global:DataSource = "$($path)\accountData.db"
$global:Logfile = "$($path)\accountData.log"
$refresh = 10 # minutes
$accounts = (gc "$($path)\settings.json" | ConvertFrom-Json) | ? { $_.enabled -eq "true" }

### create transactions table if doesn't exist
$Query = "CREATE TABLE if not exists Transactions ( accountNum INTEGER, exchange TEXT, name TEXT, symbol TEXT, incomeType TEXT, income NUMERIC, asset TEXT, info TEXT, tranId TEXT, tradeId TEXT, totalWalletBalance NUMERIC, totalUnrealizedProfit NUMERIC, todayRealizedPnl NUMERIC, totalRealizedPnl NUMERIC, source TEXT, time INTEGER, datetime DATETIME )"
Invoke-SqliteQuery -DataSource $DataSource -Query $Query
### optimize the existing db
Invoke-SqliteQuery -DataSource $DataSource -Query "PRAGMA optimize"

Function write-log {
    Param ([string]$logstring)
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$date] $logstring" -ForegroundColor Yellow
    # Add-Content $Logfile -Value "[$date] $logstring"
  }

function getLocalTime {
    param( [parameter(Mandatory = $true)] [String] $UTCTime )
    $strCurrentTimeZone = (Get-WmiObject win32_timezone).StandardName
    $TZ = [System.TimeZoneInfo]::FindSystemTimeZoneById($strCurrentTimeZone)
    $LocalTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($UTCTime, $TZ)
    return $LocalTime
}

function date2unix () {
    param ($dateTime)
    $unixTime = ([DateTimeOffset]$dateTime).ToUnixTimeMilliseconds()
    return $unixTime
}

function unix2date () {
    param ($utcTime)
    $datetime = [datetimeoffset]::FromUnixTimeMilliseconds($utcTime).DateTime
    return $datetime
}

function getPrice () {
    Param($symbol,$startTime)
    $symbol = $symbol + "USDT"
    $limit = 1
    $klines = "https://fapi.binance.com/fapi/v1/klines?symbol=$($symbol)&interval=1m&limit=$($limit)&startTime=$($startTime)"
    while ($true) {
      $klinesInformation = Invoke-RestMethod -Uri $klines
      if (($klinesInformation[0])[4]) { break }
      sleep 1
    }
    $price = [decimal] ($klinesInformation[0])[4]
    return $price
}

function betterSleep ($seconds) {
    $doneDT = (Get-Date).AddSeconds($seconds)
    while($doneDT -gt (Get-Date)) {
        $minutes = [math]::Round(($seconds / 60),2)
        $secondsLeft = $doneDT.Subtract((Get-Date)).TotalSeconds
        $percent = ($seconds - $secondsLeft) / $seconds * 100
        Write-Progress -Activity "Please stand by" -Status "Sleeping $($minutes) minutes..." -SecondsRemaining $secondsLeft -PercentComplete $percent
        [System.Threading.Thread]::Sleep(500)
    }
    Write-Progress -Activity "Please stand by" -Status "Sleeping $($minutes) minutes..." -SecondsRemaining 0 -Completed
}

### get account info
function getAccount () {
    Param(
        [Parameter(Mandatory = $false, Position = 0)]$accountNum
    )
    $exchange = ($accounts | Where-Object { $_.number -eq $accountNum }).exchange
    $accountName = ($accounts | Where-Object { $_.number -eq $accountNum }).name
    $key = ($accounts | Where-Object { $_.number -eq $accountNum }).key
    $secret = ($accounts | Where-Object { $_.number -eq $accountNum }).secret
    $TimeStamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    if ($exchange -eq "binance") {
        $TimeStamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $QueryString = "&recvWindow=5000&timestamp=$TimeStamp"
        $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
        $hmacsha.key = [Text.Encoding]::ASCII.GetBytes($secret)
        $signature = $hmacsha.ComputeHash([Text.Encoding]::ASCII.GetBytes($QueryString))
        $signature = [System.BitConverter]::ToString($signature).Replace('-', '').ToLower()
        $uri = "https://fapi.binance.com/fapi/v1/account?$QueryString&signature=$signature"
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("X-MBX-APIKEY", $key)
        $result = @()
        $result = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get | Select-Object totalWalletBalance, totalUnrealizedProfit
        $datetime = getLocalTime ([datetimeoffset]::FromUnixTimeMilliseconds($TimeStamp).DateTime)
        $newItem = [PSCustomObject]@{
            "accountNum"            = $accountNum
            "exchange"              = $exchange
            "name"                  = $accountName
            "symbol"                = $null
            "incomeType"            = $null
            "income"                = $null
            "asset"                 = $null
            "info"                  = $null
            "tranId"                = $null
            "tradeId"               = $null
            "totalWalletBalance"    = $result.totalWalletBalance
            "totalUnrealizedProfit" = $result.totalUnrealizedProfit
            "todayRealizedPnl"      = $null
            "totalRealizedPnl"      = $null
            "source"                = "account"
            "time"                  = [int64] $TimeStamp
            "datetime"              = $datetime
        }
        return $newItem
    }
    elseif ($exchange -eq "bybit") {
        $TimeStamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $symbol = ($accounts | Where-Object { $_.number -eq $accountNum }).symbol
        $QueryString = "api_key=$key&coin=$($symbol)&timestamp=$TimeStamp"
        $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
        $hmacsha.key = [Text.Encoding]::ASCII.GetBytes($secret)
        $signature = $hmacsha.ComputeHash([Text.Encoding]::ASCII.GetBytes($QueryString))
        $signature = [System.BitConverter]::ToString($signature).Replace('-', '').ToLower()
        $uri = "https://api.bybit.com/v2/private/wallet/balance?$QueryString&sign=$signature"
        $datetime = getLocalTime ([datetimeoffset]::FromUnixTimeMilliseconds($TimeStamp).DateTime)
        $result = @()
        $result = Invoke-RestMethod -Uri $uri -Method Get
        $newItem = [PSCustomObject]@{
            "accountNum"            = $accountNum
            "exchange"              = $exchange
            "name"                  = $accountName
            "symbol"                = $symbol + "USD"
            "incomeType"            = $null
            "income"                = $null
            "asset"                 = $null
            "info"                  = $null
            "tranId"                = $null
            "tradeId"               = $null
            "totalWalletBalance"    = $result.result.$symbol.wallet_balance
            "totalUnrealizedProfit" = $result.result.$symbol.unrealised_pnl
            "todayRealizedPnl"      = $result.result.$symbol.realised_pnl
            "totalRealizedPnl"      = $result.result.$symbol.cum_realised_pnl
            "source"                = "account"
            "time"                  = [int64] $TimeStamp
            "datetime"              = $datetime
        }
        if ($newItem.wallet_balance -ne "0") {
            return $newItem
        }
    }
}

function getIncome () {
    Param([Parameter(Mandatory = $false, Position = 0)]$accountNum,
        [Parameter(Mandatory = $false, Position = 1)]$startTime
    )
    $key = ($accounts | Where-Object { $_.number -eq $accountNum }).key
    $secret = ($accounts | Where-Object { $_.number -eq $accountNum }).secret
    $exchange = ($accounts | Where-Object { $_.number -eq $accountNum }).exchange
    $accountName = ($accounts | Where-Object { $_.number -eq $accountNum }).name
    if ($exchange -eq "binance") {
        # https://binance-docs.github.io/apidocs/futures/en/#get-income-history-user_data
        $limit = "1000"    # max 1000
        $results = @()
        while ($true) {
            $result = @()
            $TimeStamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            $QueryString = "&recvWindow=5000&limit=$limit&timestamp=$TimeStamp&startTime=$startTime"
            $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
            $hmacsha.key = [Text.Encoding]::ASCII.GetBytes($secret)
            $signature = $hmacsha.ComputeHash([Text.Encoding]::ASCII.GetBytes($QueryString))
            $signature = [System.BitConverter]::ToString($signature).Replace('-', '').ToLower()
            $uri = "https://fapi.binance.com/fapi/v1/income?$QueryString&signature=$signature"
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $headers.Add("X-MBX-APIKEY", $key)
            $result = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
            $result = $result | sort time
            $newitems = @()
            foreach ($item in $result) {
                $datetime = getLocalTime ([datetimeoffset]::FromUnixTimeMilliseconds($item.time).DateTime)
                ### convert commissionAsset to Usd
                if (($item.incomeType -eq "COMMISSION" -or $item.incomeType -eq "TRANSFER") -and $item.asset -eq "BNB") {
                    $item.income = (getPrice $item.asset $item.time) * ($item.income)
                    $item.asset = "USDT"
                }
                $newItem = [PSCustomObject]@{
                    "accountNum"            = $accountNum
                    "exchange"              = $exchange
                    "name"                  = $accountName
                    "symbol"                = $item.symbol
                    "incomeType"            = $item.incomeType
                    "income"                = $item.income
                    "asset"                 = $item.asset
                    "info"                  = $item.info
                    "tranId"                = $item.tranId
                    "tradeId"               = $item.tradeId
                    "totalWalletBalance"    = $null
                    "totalUnrealizedProfit" = $null
                    "todayRealizedPnl"      = $null
                    "totalRealizedPnl"      = $null
                    "source"                = "income"
                    "time"                  = [int64] $item.time
                    "datetime"              = $datetime
                }
                $newitems += $newItem
            }
            $results += $newitems
            write-log "getIncome, account: $($accountNum) startTime: $($newitems[0].time) dateTime: $($newitems[0].datetime) result: $($newItems.length)"
            if ($result.length -lt 1000) { break }
            $startTime = [int64]($result.time | sort)[-1] + 1
        }
        return $results
    }
    elseif ($exchange -eq "bybit") {
        ### https://bybit-exchange.github.io/docs/inverse/#t-walletrecords
        $limit = 50  # max 50
        $symbol = ($accounts | Where-Object { $_.number -eq $accountNum }).symbol
        $results = @()
        $page = 1
        while ($true) {
            $TimeStamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            $datetime = [datetimeoffset]::FromUnixTimeMilliseconds($startTime).DateTime
            $datetime = $datetime.ToString("yyyy-MM-dd")
            $QueryString = "api_key=$key&currency=$symbol&limit=$limit&page=$page&start_date=$datetime&timestamp=$TimeStamp"
            $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
            $hmacsha.key = [Text.Encoding]::ASCII.GetBytes($secret)
            $signature = $hmacsha.ComputeHash([Text.Encoding]::ASCII.GetBytes($QueryString))
            $signature = [System.BitConverter]::ToString($signature).Replace('-', '').ToLower()
            $baseUri = "https://api.bybit.com/v2/private/wallet/fund/records"
            $uri = "$($baseUri)?$($QueryString)&sign=$($signature)"
            $result = @()
            $result = Invoke-RestMethod -Uri $uri -Method Get
            if ($result.result.data.length -eq "0") { break }
            $newItems = @()
            foreach ($item in $result.result.data) {
                $time = ([DateTimeOffset]$item.exec_time).ToUnixTimeMilliseconds()
                $datetime = [datetime] $item.exec_time  # converts UTC to local
                if ($item.type -like "*withdraw*") { $item.amount = - $item.amount }
                $newItem = [PSCustomObject]@{
                    "accountNum"            = $accountNum
                    "exchange"              = $exchange
                    "name"                  = $accountName
                    "symbol"                = $item.address
                    "incomeType"            = $item.type
                    "income"                = $item.amount
                    "asset"                 = $item.coin
                    "info"                  = $null
                    "tranId"                = $item.tx_id
                    "tradeId"               = $null
                    "totalWalletBalance"    = $item.wallet_balance
                    "totalUnrealizedProfit" = $null
                    "todayRealizedPnl"      = $null
                    "totalRealizedPnl"      = $null
                    "source"                = "income"
                    "time"                  = [int64] $time
                    "datetime"              = $datetime
                }
                $newItems += $newItem
            }
            $results += $newItems
            write-log "getIncome, account: $($accountNum) startTime: $($startTime) dateTime: $($datetime) page: $($page) result: $($newItems.length)"
            $page++
        }
        return $results
    }
}

function addData () {
    $results = @()
    foreach ($account in $accounts) {
        $result = @()
        ### get income
        $lastTime = $null
        ### looks for the latest record's datetime for this account
        $Query = 'SELECT max(time) as max_time from Transactions WHERE accountNum = ''' + $account.number + ''' AND source = ''income'''
        $lastTime = [int64] (Invoke-SqliteQuery -DataSource $DataSource -Query $Query).max_time
        ### if last record for this type of record is not found, use the start date from the settings
        if (!($lastTime)) { $lastTime = date2unix $account.start }
        if ($account.exchange -eq "bybit") {
            ### get the time for the midnight of $lastTime
            $midnightDate = ([datetimeoffset]::FromUnixTimeMilliseconds($lastTime).DateTime).Date
            ### convert it to unix time
            $midnightLastTime = ([DateTimeOffset]$midnightDate).ToUnixTimeMilliseconds()
            $Query = 'SELECT * from Transactions WHERE accountNum = ''' + $account.number + ''' AND source = ''income'' AND time >= ' + $($midnightLastTime)
            $old = $new = @()
            $old = Invoke-SqliteQuery -DataSource $DataSource -Query $Query
            $new = getIncome $account.number $lastTime
            ### the following line is supposed to dedupe the results, but doesn't work sometimes, thus the later deduping of the whole db
            [array]$result += ([array]$new | ? { [array]$old -NotContains $_ })
            # $result += ([array]$new + [array]$old) | sort * -uniq
        }
        if ($account.exchange -eq "binance") {
            [array]$result += getIncome $account.number ($lastTime + 1)
        }
        ### get account
        [array]$result += getAccount $account.number
        $results += $result
        write-log "addData, account: $($account.number) results: $($result.length)"
    }
    write-log "Adding results to the database..."
    $DataTable = $results | sort time | sort * -uniq | Out-DataTable
    Invoke-SQLiteBulkCopy -DataTable $DataTable -DataSource $DataSource -Table "Transactions" -NotifyAfter 1000 -Confirm:$false
    ### dedupe the db, cuz you know....
    Invoke-SqliteQuery -DataSource $DataSource -Query "DELETE FROM Transactions WHERE rowid NOT IN (SELECT min(rowid) FROM TRANSACTIONS GROUP BY accountNum, exchange, name, symbol, incomeType, income, asset, info, tranId, tradeId, totalWalletBalance, totalUnrealizedProfit, todayRealizedPnl, totalRealizedPnl, source, time, datetime)"
    # $results | sort * -uniq | sort time | ConvertTo-Csv -NoTypeInformation | select -Skip 1 | ac "$($path)\data\data.csv"
}

while ($true) {
    write-log "Checking for new data..."
    addData
    write-log "Import Complete"
    write-log "Sleeping $($refresh) minutes..."
    betterSleep ($refresh * 60)
}
