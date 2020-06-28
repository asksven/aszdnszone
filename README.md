# Dynamic DNS

Some scripting to maintain an A-record in an Azure DNS zone for a home-ip.

In order to have this script to work you will need:
- an Azure DNS zone
- an Azure AD service principal. You can create one with `az ad sp create-for-rbac --name AcmeDnsUpdater`
- the SPN's `appId`, `displayName`, `name`, `password` and `tenant`
- the SPN must have the role "DNS Zone Contributor" on the DNS zone


## Migrate from earlier versions

### 2020-06-28

- The variable `REQUESTED_NAMES` in now a comma-separated string
- The variable `INITIALIZED` (default is unset, that is compatible with the previous behavior) was added to prevent the script from settings its variables using `setenv`; this is useful when running in a container where the env-vars are set by e.g. a configmap
- The variable `STATELESS` (default is unset, that is compatible with the previous behavior) was added to avoid writing/reading "old" to/from a file. When set to `1` the current (old) IP is retrieved by doing a DNS query
- The variable `TWELVE_FACTORS` (default is unset, that is compatible with the previous behavior) was added to ensure that all logging happens on stdout and stderr. When set to `1` the behavior is such that all logs are passed to the container orchestrator

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

## Run as container

Pre-requisite: a `setenv` file needs to be present in the directory you run the container from, or you need to replace `$PWD` with the path of the config-file
```
docker run -v $PWD:/config asksven/azdnszone:1 /bin/bash -c "/update-ip.sh config/setenv"
```

## Build container

Unfortuantely at this time (2020-06-27) there is no multi-arch azure-cli docker image available, so I decided to build one. The image containes the azure-cli v2.8.0 and can be pulled at `asksven/az-cli:1`. The repo is [here](https://github.com/asksven/azure-cli)

To build the azdnszone image based on the cli:
```
{
    export REPOSITORY=asksven/azdnszone
    export VERSION=1
    export DOCKER_CLI_EXPERIMENTAL=enabled
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
}

make
```

## Run on Kubernetes

`azdnszone` can be run on Kubernetes, as a cron-job:

1. Create a namespace: `kubectl create ns azdnszone`
1. Create a configmap: `source setenv && kubectl  -n azdnszone create configmap azdnszone-config --from-literal INITIALIZED=1 --from-literal appId=$appId --from-literal password=$password --from-literal tenant=$tenant --from-literal SUBSCRIPTION=$SUBSCRIPTION --from-literal REQUESTED_NAMES=$REQUESTED_NAMES --from-literal AZ_DNS_RG=$AZ_DNS_RG --from-literal PARENT_DOMAIN=$PARENT_DOMAIN --from-literal STATELESS=$STATELESS --from-literal TWELVE_FACTORS=$TWELVE_FACTORS`
1. Create a cron-job: `kubectl -n azdnszone apply -f kubernetes/`
