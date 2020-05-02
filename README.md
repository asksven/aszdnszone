# Dynamic DNS

Some scripting to maintain an A-record in an Azure DNS zone for a home-ip.

In order to have this script to work you will need:
- an Azure DNS zone
- an Azure AD service principal. You can create one with `az ad sp create-for-rbac --name AcmeDnsUpdater`
- the SPN's `appId`, `displayName`, `name`, `password` and `tenant`
- the SPN must have the role "DNS Zone Contributor" on the DNS zone

## Config

The default config of the `update-ip.sh` script is in `setenv` (can be created based on the `setenv.template`). If you want to run multiple instances with multiple configs it is also possible to pass the name of the config-file: `update-ip.sh <config-file>`.

When the script runs it stores the last IP it has detected in `tmp/my_ip`. The name of the file can be overridden by setting `IP_FILE` in the config-file. In order to avoid bombarding the Azure api calls are only made if that file does not exist or if the IP is different.

### Scenario 1: update only one domain

If you want to update the IP for one domain (e.g. `foo.bar`) the config-file should have:

- `REQUESTED_NAMES=("")`
- `PARENT_DOMAIN="foo.bar"`

### Scenario 2: update multiple FQDNs in the domain

If you want to update the IP for multiple FQDNs, e.g. `home.foo.bar` and `lab.home.foo.bar` the config-file should have:

- `REQUESTED_NAMES=("home" "lab.home")`
- `PARENT_DOMAIN="foo.bar"`
 
## Automation

1. Run `crontab -e`
1. Add `* * * * * /path/to/your/script/update-ip.sh`



