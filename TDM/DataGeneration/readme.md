## Instructions
1. Download the script file [.\run-data-generation.ps1](run-data-generation.ps1) and the options file [./rggenerate-options.json](rggenerate-options.json).
1. Download the [rggenerate executable](https://download.red-gate.com/EAP/RGGenerateWin64.zip) and extract it from the ZIP file, into the same directory as the script file and options file.
1. Check whether you have the Microsoft Sql Server ODBC drivers installed.
   - In the Start menu, open "ODBC Data Sources (64-bit)"
   - Click the drivers tab
   - Check for an entry "ODBC Driver 18 for Sql Server"
1. If you do not have the Sql Server ODBC drivers installed, please [download them](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server?view=sql-server-ver16) and install them. You may also need to install the [Microsoft C++ runtimes](https://aka.ms/vs/15/release/vc_redist.x64.exe). If you have a different version of the ODBC drivers installed, you may also need to edit the ODBC driver name.
1. Edit the file [.\run-data-generation.ps1](run-data-generation.ps1). You need to enter your Sql Server instance details at the top in the `param` section.
1. Run the script to plan data generation for your database by executing this command in the Windows command prompt. You may like to check the output generation json file afterwards.
   ```
   powershell -ep bypass .\run-data-generation.ps1 -plan
   ```
1. Run the script to generate data and populate your database by executing this command
   ```
   powershell -ep bypass .\run-data-generation.ps1 -populate
   ```

## Troubleshooting
- You may need to set the [PowerShell Execution Policy](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.4) to ByPass, or Unrestricted.

```
# To determine your execution policy:
Get-ExecutionPolicy

# To change your execution policy for a single session:
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process

# To permanently change your execution policy (must be executed as admin):
Set-ExecutionPolicy RemoteSigned
```
