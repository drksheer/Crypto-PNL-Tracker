# Crypto-PNL-Tracker
A generic crypto PNL tracker which can work with Binance, Bybit or your own data.

## Requirements
1. The actual Crypto Tracker app - [**grab the latest release**](https://github.com/drksheer/Crypto-PNL-Tracker/releases) and unzip it into a folder such as *C:\Bots\Tracker*.
2. [Daisy's automatic import script](https://github.com/daisy613/accountData). Download the script and the settings file into the same folder as above.
3. [Microsoft .NET 5.0 Runtime](https://dotnet.microsoft.com/download) if you don't already have it (*Had reports entire SDK may need to be installed, can someone confirm this?*).

A lot of configuration below uses the JSON-file format. **If you are new to this, be careful not to disrupt the curly braces or double quotes or you might break things.**

## Getting Started
### 1) Get the tracker
1. Unzip the Crypto PNL tracker into a folder such as *C:\Bots\Tracker*

### 2) Run Daisy's Binance/Bybit Data Import
This script generates a database for which the Crypto PNL tracker uses as a plugin, so first step is importing your data.
1. Download [Daisy's automatic import script](https://github.com/daisy613/accountData) the settings file into the tracker folder. Follow the setup instructions on that page.
2. Run `accountData.ps1` from PowerShell as Administrator (Start menu -> PowerShell -> Right click, Run as Administrator). Navigate to the directory and type `.\accountData.ps1`.
3. This will commence data import. **This may take up a while depending on how old the account is - about 10 mins per month of the account.** When the first import occurs, the green message will say "Import Complete". After that, it will continue to import every 10 minutes. Leave this process running to keep your data up to date.
4. Now you can proceed to the tracker setup.

### 2) Running the Tracker
1. Edit the JSON file format `accounts.json` in the root of the Crypto Tracker.
    - Edit the values appropriately to your setup. Ensuring `"enabled": true` and change `startBalance` from null to a number if your original balance cannot be obtained in the import.
    - **If using Daisy's Binance/Bybit import:**
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
            "startBalance": null,
            "PNL": []
        }
        ```
        - Ensure `dbFileName` is set to the relative location to tracker root of where your database file is being generated (See setup instructions). Make sure to use the forward-slash character. Use the default value unless you have an advanced custom setup and you know what you are doing.
        - `accountName` is the same as specified in the `name` property in Daisy's `accountData.json`.
        - `fromDate` should be left null unless you wish to specify tracking to occur from a certain date on the chart. Eg. "2012-01-01" to only build the graph from 1st Jan onwards.
    - **If manually tracking:**
        - Edit the `"PNL"` value array manually setting a UTC-compatible date and decimal for each day.
    - *Multiple accounts:* You can setup multiple accounts by copying the entire account property from `{` to `}`, and pasting it again separating it by a comma.
2. Run `PNLTracker.exe` this should launch a web server and your results will be available on http://localhost:5000 once all data has been imported.
3. Keep Daisy's PowerShell script running in the background to automatically keep your data up-to-date.
