# A description of the Powershell files in this directory

This directory contains a number of scripts to help you integrate [Sql Data Catalog](https://www.red-gate.com/products/dba/sql-data-catalog/) with [Data Masker](https://www.red-gate.com/products/dba/data-masker/).

**Note:** These samples presumes that you have a recent installation of Data Masker and SQL Data Catalog with the default taxonomy.

## Tag a column for masking.ps1

This Powershell demonstrates how you'd tag a column of the `AdventureWorks` database so that it will be picked up by the following script.

## Generate masking set from catalog.ps1

At the top of the file, paste in your auth token from Data Catalog and the server url where your Data Catalog instance lives.

This Powershell script will then use the Data Masker command line to generate a masking set file using the taxonomy in Data Catalog.

The `$maskingSetPath` variable is the output path to the file that the script will produce.

## DataMaskerHelpers.psm1

This file contains some utility functions that the other scripts use.
