# A description of the Powershell files in this directory

This directory contains a number of scripts to help you integrate [Sql Data Catalog](https://www.red-gate.com/products/dba/sql-data-catalog/) with [Sql Data Masker](https://www.red-gate.com/products/dba/data-masker/)

## Add masking taxonomy.ps1

The masking scripts expect a Tag Category named `Masking Data Set` with a number of tags such as `EmailAddress`.
This Powershell script adds this category and the tags to the taxonomy.

## Tag a column for masking.ps1

This Powershell demonstrates how you'd mark tag a column of the AdventureWorks database so that it will be picked up by the following script.

## Generate masking set from catalog.ps1

This Powershell script takes as input a masking set definition file.

```powershell
$inputMaskingSetPath = "AdventureWorks.DMSMaskSet"
```

It will load this file, and then process the columns of the given instance and database

```powershell
$instanceName = 'sql-server1.domain.com'
$databaseName = 'AdventureWorks'
```

to generate a masking set which it will be saved into the output file.

```powershell
$outputMaskingSetPath = "AdventureWorks Generated.DMSMaskSet"
```

## DataMaskerHelpers.ps1

This file contains some utility functions that the other scripts use.
