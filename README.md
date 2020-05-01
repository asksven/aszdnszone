# Dynamic DNS

Some scripting to maintain an A-record in an Azure DNS zone for a home-ip.

In order to have this script to work you will need:
- an Azure DNS zone
- an Azure AD service principal. You can create one with `az ad sp create-for-rbac --name AcmeDnsUpdater`
- the SPN's `appId`, `displayName`, `name`, `password` and `tenant`
- the SPN must have the role "DNS Zone Contributor" on the DNS zone

## Config

The config of the `update-ip.sh` script is in `setenv` (can be created based on the `setenv.template`)

When the script runs it stores the last IP it has detected in `tmp/my_ip`. In order to avoid bombarding the Azure api calls are only made if that file does not exist or if the IP is different.

## Automation

1. Run `crontab -e`
1. Add `* * * * * /path/to/your/script/update-ip.sh`



