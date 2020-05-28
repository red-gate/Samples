# ExportTo-OneTrust.ps1

This sample was developed in cooperation with [OneTrust](https://www.onetrust.com/)

This script exports two known tags that must exist in your taxonomy and aggregates these up to the database level:

- Data Subject - The individuals whose data is stored in the catalog (e.g. Customers)
- Data Elements - The types of data that is stored (e.g. E-mail address, Phone number)

If your taxonomy differs, this Cmdlet allows you to redefine what you would call Data Subject, e.g. "Subject"

## Please note that

- the Subject names must match those registered in OneTrust (Data Mapping - Setup - Inventory Manager - Data Subject Types - Key)
- the Element names must match those registed in OneTrust (Data Mapping - Setup - Inventory Manager - Data Elements - Key)
- there must be a registed Asset type called "Instance" in OneTrust (Data Mapping - Setup - Inventory Manager - Asset Attributes - Type)
