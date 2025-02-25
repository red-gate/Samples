# Data Generation sample Instructions

- [Data Generation sample Instructions](#data-generation-sample-instructions)
  - [Requirements](#requirements)
  - [Instructions](#instructions)
  - [Troubleshooting](#troubleshooting)

## Requirements

Before you start:

- Test Environment: Use a dedicated test environment to keep live data safe similar to the proof of concept environment below.
- System Requirements: Make sure your system meets our minimum requirements [here](https://documentation.red-gate.com/x/-A4wE) for a smooth setup. 

## Instructions

1. Download the script file [.\run-data-generation.ps1](run-data-generation.ps1) and the options file [./rggenerate-options.json](rggenerate-options.json).
2. Download the [rggenerate executable](https://download.red-gate.com/EAP/RGGenerateWin64.zip) and extract it from the ZIP file, into the same directory as the script file and options file.
3. Edit the file [.\run-data-generation.ps1](run-data-generation.ps1). You need to enter your Sql Server instance details at the top in the `param` section.
4. Run the script to plan data generation for your database by executing this command in the Windows command prompt. You may like to check the output generation json file afterwards.

   ```PowerShell
   powershell -ep bypass .\run-data-generation.ps1 -plan
   ```

5. Run the script to generate data and populate your database by executing this command

   ```PowerShell
   powershell -ep bypass .\run-data-generation.ps1 -populate
   ```

## Troubleshooting

- You may need to set the [PowerShell Execution Policy](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.4) to ByPass, or Unrestricted.

```PowerShell
# To determine your execution policy:
Get-ExecutionPolicy

# To change your execution policy for a single session:
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process

# To permanently change your execution policy (must be executed as admin):
Set-ExecutionPolicy RemoteSigned
```
