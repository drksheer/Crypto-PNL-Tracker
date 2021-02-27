# Crypto-PNL-Tracker
A generic crypto PNL tracker which can work with Binance, Bybit or your own data.

## Setup Instructions
You will need four things: -
1. The actual Crypto Tracker app, get the [latest release]().
2. [Daisy's Binance/Bybit import script]() and settings file. *Most likely you want this, unless you are wanting to manage your PNL data manually*. Download and unzip all this to the one location.
3. Daisy's script also relies on PowerShell 5.0+, you probably already have it if you run Windows, if not, [grab it here](https://aka.ms/powershell-release?tag=stable).
3. [Microsoft .NET 5.0 Runtime](https://dotnet.microsoft.com/download) if you don't already have it.

A lot of configuration below uses the JSON-file format. **If you are new to this, becareful not to disrupt the curly braces or double quotes or you might break things.**

## Getting Started
### 1) Run Binance/Bybit Data Import
This script generates a database for which the Crypto PNL tracker uses as a plugin, so first step is importing your data.
1. Edit `$global:path` in `get-accountData.ps1` and set this to the root of where you are running the Crypto Tracker from, suffixed with `db-files`. Eg. `D:\crypto\pnl-tracker\db-files`.
3. Move Daisy's `settings.json` file across to this new db storage folder.
4. Edit `settings.json` and configure as many accounts as you would like to track, by filling in the fields and ensuring `"enabled": "true"` for accounts you wish to import.
5. Run `get-accountData.ps1` from PowerShell as Administrator (Start menu -> PowerShell -> Right click, Run as Administrator). Navigate to the directory and type `.\get-accountData.ps1`.
6. This will commence data import. **This may take up to 15 minutes.** After that, it will continue to import every 10 amount of minutes. Leave this process running to keep your data up to date.
7. While this is running you can setup the tracker..

### 2) Running the Tracker
2. Edit the JSON file format `accounts.json` in the root of the Crypto Tracker.
    - Edit the values appropriately to your setup. Ensuring `"enabled": true`.
    - **If using Binance/Bybit import:**
        - Ensure `dbFileName` is set to the relative location to tracker root of where your database file is being generated (See setup instructions).
        - A basic setup should look like this,
        ```
        {
            "account": "Primary bot",
            "enabled": true,
            "plugins": [
            {
                "type": "SQLiteImport",
                "accountName": "primary",
                "fromDate": null,
                "dbFileName": "db-files/accountData.db"
            }
            ],
            "PNL": []
        }
        ```
        - `fromDate` should be left null unless you wish to specify tracking to occur from a certain date on the chart. Eg. "2012-01-01" to only build the graph from 1st Jan onwards.
    - **If manually tracking:**
        - Edit the `"PNL"` value array manually setting a UTC-compatible date and decimal for each day.
    - *Multiple accounts:* You can setup multiple accounts by copying the entire account property from `{` to `}`, and pasting it again separating it by a comma.
3. Run `PNLTracker.exe` this should launch a web server and your results will be available on http://localhost:5000 once all data has been imported.
4. Keep Daisy's PowerShell script running in the background to automatically keep your data up-to-date.

## Tips when setting up Daisy's settings.json file
- It's best to set your `start` date to the start date of, or as close as you can to when your Binance/Bybit account was created. If you specify an arbitrary date which is much earlier than the acccount start date, the import may only process the last 30 or so days.