## System set up
You will need:
- A Windows machine to run this script and the rggenerate/rganonymize CLIs on.
- You may need to set the [PowerShell Execution Policy](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.4) to ByPass, or Unrestricted.

```
# To determine your execution policy:
Get-ExecutionPolicy

# To change your execution policy for a single session:
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process

# To permanently change your execution policy (must be executed as admin):
Set-ExecutionPolicy RemoteSigned
```

## Instructions
1. Download the script file [.\run-data-generation.ps1](run-data-generation.ps1), and rggenerate and rganonymize.
1. Start a trial of TDM and authorize rganonymize by executing this command.
   ```
   rganonymize auth login --i-agree-to-the-eula --start-trial
   ```
1. Edit the file [.\run-data-generation.ps1](run-data-generation.ps1). You need to enter your Sql Server instance details at the top in the `param` section.
1. Run the script to classify your database by executing this command. You may like to check the output classification json file afterwards.
   ```
   powershell .\run-data-generation.ps1 -classify
   ```
1. Run the script to plan data generation for your database by executing this command. You may like to check the output generation json file afterwards.
   ```
   powershell .\run-data-generation.ps1 -plan
   ```
1. Run the script to generate data and populate your database by executing this command
   ```
   powershell .\run-data-generation.ps1 -populate
   ```

