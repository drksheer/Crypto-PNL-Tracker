# Crypto-PNL-Tracker
A generic crypto PNL tracker which can work with Binance, Bybit or your own data.

<img src="https://raw.githubusercontent.com/drksheer/Crypto-PNL-Tracker/main/guides/Crypto-Tracker-New.png" target="Crypto Tracker" height="500">

## Requirements
1. The actual Crypto Tracker app - [**grab the latest release**](https://github.com/drksheer/Crypto-PNL-Tracker/releases) and unzip it into a folder such as *C:\Bots\Tracker*.
2. [Daisy's automatic import script](https://github.com/daisy613/accountData). Download the script and the settings file into the same folder as above.
3. [ASP.NET Core 5.0 Hosting Bundle](https://dotnet.microsoft.com/download/dotnet/thank-you/runtime-aspnetcore-5.0.4-windows-hosting-bundle-installer)

A lot of configuration below uses the JSON-file format. **If you are new to this, be careful not to disrupt the curly braces or double quotes or you might break things.**

## Video Guides
Video guides for installation and other troubleshooting now available: [**https://www.youtube.com/playlist?list=PLkZXfeWbs5zLUAseH9ORcONCTJpg02QYJ**](https://www.youtube.com/playlist?list=PLkZXfeWbs5zLUAseH9ORcONCTJpg02QYJ)

## Getting Started
### 1) Get the tracker
1. Unzip the Crypto PNL tracker into a folder such as *C:\Bots\Tracker*

### 2) Run Daisy's Binance/Bybit Data Import
This script generates a database for which the Crypto PNL tracker uses as a plugin, so first step is importing your data.
Download [Daisy's automatic import script](https://github.com/daisy613/accountData) the settings file into the tracker folder. Follow the setup instructions on that page to setup and begin the data import.

When the first import occurs, the green message will say "Import Complete". After that, it will continue to import every 10 minutes. Leave this process running to keep your data up to date.

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
            "discord": {
                "webHookUrl": "",
                "dailyReportTime": "7:00"
            },
            "startBalance": null,
            "PNL": []
        }
        ```
        - Ensure `dbFileName` is set to the relative location to tracker root of where your database file is being generated (See setup instructions). Make sure to use the forward-slash character. Use the default value unless you have an advanced custom setup and you know what you are doing.
        - `accountName` is the same as specified in the `name` property in Daisy's `accountData.json`.
        - `fromDate` should be left null unless you wish to specify tracking to occur from a certain date on the chart. Eg. "2012-01-01" to only build the graph from 1st Jan onwards.
        - `discord.weebHookUrl`: **(NEW)** Set this to your discord webhook if you want daily PNL reports!
        - `discord.dailyReportTime`: **(NEW)** Set this to the time in hh:mm when you wish to receive the reports.
    - **If manually tracking:**
        - Edit the `"PNL"` value array manually setting a UTC-compatible date and decimal for each day.
    - *Multiple accounts:* You can setup multiple accounts by copying the entire account property from `{` to `}`, and pasting it again separating it by a comma.
2. Run `PNLTracker.exe` this should launch a web server and your results will be available on http://localhost:5000 once all data has been imported.
3. Keep Daisy's PowerShell script running in the background to automatically keep your data up-to-date.

## You're Done!

### Troubleshooting
If Rolling Balance/Cumulative Profit % does not match, or not what you expect, the tracker or the Binance API probably could not correctly determine your starting balance. So this must be set manually.
This is done by a simple calculation,
1. Firstly enter a number close to your estimated original balance into `startBalance` field of the JSON file. Eg. $1000.
2. Now reload the Tracker.
3. Check and hover over the graph,
For the below screenshot, this is the formula
`2321.43 [Current Balance] - 1793.87 [Rolling Balance] = 527.56 [difference]`
**Sum** this result on top of the balance you wrote into the `startBalance` field of the JSON file. Eg if difference was 50 and you wrote 100 originally, type 150.

<img src="https://raw.githubusercontent.com/drksheer/Crypto-PNL-Tracker/main/guides/balanceInconsistency.png" target="Crypto Tracker">

## Donations/Tips:
- USDT (TRC20): `TWhjv6ita4Y1i2xevTjxgB6g92yZLpkTwv`
- BTC: `13nsGbe7A7K1SR2KpJHRPH9eArKf823T9o`
