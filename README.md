# Table of Contents
- [Table of Contents](#table-of-contents)
- [Reference architecture for a website on Azure](#reference-architecture-for-a-website-on-azure)
  - [Security](#security)
  - [Operational excellence](#operational-excellence)
  - [Reliability](#reliability)
  - [Performance Efficiency](#performance-efficiency)
  - [Cost Optimization](#cost-optimization)
  - [Background of architectual decisions and further development](#background-of-architectual-decisions-and-further-development)
- [Details & Usage](#details--usage)
  - [Prerequisites](#prerequisites)
  - [Pipelines](#pipelines)
  - [IaC](#iac)
  - [Frontend](#frontend)
  - [Backend](#backend)
- [Other documentation](#other-documentation)

# Reference architecture for a website on Azure
This architecture creates a modern website. Frontend is a Single Page Application and it’s served from Azure Storage Account Blob Storage static website. Microservices backend, which provides API’s for the frontend, is served from a Azure Linux Web App.

The backend application communicates safely via a Virtual Network (Vnet) to other services like Service Bus and PostGreSQL database. Service Bus queues are used to de-couple long lasting processing from the API-layer and a worker Linux Web App consumes messages from the queues.

All secrets are kept in Azure Key Vault. Linux Web App can retrieve them via Vnet and identity-based access control is utilized.

The application uses Application Insights to collect logs and metrics and to create alerts in case of errors or bottlenecks.

Azure Front Door is placed in front of all end-user endpoints. Front Door can cache the requests to static assets and therefore works as a CDN. A Web Application Firewall (WAF) can be applied to Front Door, which improves security.

![Architecture](./docs/images/azure-webapp-ref.drawio.svg)

## Security
- All network traffic is protected with TLS (1.2)
- All data is stored encrypted with customer managed key saved in Key Vault
- Endpoints serving end-users are behind Front Door
  - As Front Door is a global Azure service, it’s hard to Ddos it
  - A WAF can and should be setup with Front Door. WAF can be used to mitigate many security issues. E.g. with the Log4J-vurnerability, WAF could’ve been set to filter jndi-strings
- All secrets are saved to Key Vault
- All communication between backend services (Web app, database, Key Vault and Application Insights) is done via Vnet
- Access to PostGreSQL should be limited to Vnet and maybe also to developers/admins from the internet. In this case, the developers/admins IP’s should be added to PostGreSQL’s firewall. The other way to let developers/admins use PostGreSQL is to set up a VPN Gateway to the Vnet

## Operational excellence
- All used services are Azure PaaS
  - Azure takes care of running and patching the services
- Logs and metrics are collected to Application Insights
  - Based on logs and metrics, alerts and even self-healing automation can be setup
- Infrastructure is setup with a Terraform IaC –template
- CI/CD is done with Github Actions that is authenticated with OIDC

## Reliability
- All used services are Azure PaaS
  - Azure takes care of running and patching the services

## Performance Efficiency
- Azure Linux Web App autoscaling can be applied to automatically up&downscale
- Azure PostGreSQL can scale automatically, but some automation needs to be built to make it happen
- Using Front Door, end users will see better response times as:
  - Static assets can be cached to Front Door edge location and therefore they are more close to users
  - Also dynamic requests will benefit from Front Door traffic acceleration

## Cost Optimization
- Be sure to select the optimal SKU-sizes for Linux Web App and PostGreSQL

## Background of architectual decisions and further development
- Why we didn’t use
  - Azure Static Web Apps
    - As of writing, it does not support Vnet integration, so we didn’t get the wanted security. If it’s ok for your application to have open database ports to the internet, feel free to use Static Web Apps
  - Azure Functions
    - We probably will make a reference architecture with Azure Functions in the future.
- Potential new features to this reference architecture
  - Azure AD –authentication
  - CosmosDB as database

# Details & Usage
This chapter contains detailed information about each of the components.

## Prerequisites

To use this architecture, you'll need:
-	#### An Azure account with an active subscription.
-	#### A GitHub account and repository to store templates and workflow files.
-	#### Node.js / npm

    How to install Node.js on Windows:
    1. Download Windows Installer (32-bit/64bit version) from Node.js page: https://nodejs.org/en/download
    2. Install Node.js: \
      2.1. Run the .msi file \
      2.2. Check the “**I accept**” box and click **Next**. \
      2.3. Leave the default destination directory and click the **Next** button. \
      2.4. Leave the Node.js default features and click the **Next** button. \
      2.5. Leave Tools for Native Modules not selected by default and click **Next**. \
      2.6. Click the **Install** button. \
      2.7. Click the **Finish** button.
    3. To verify the installation open any terminal application (e.g. Command Prompt, Windows Terminal etc.) on your computer and run the following commands:
        -	To check the node version: `Node –version`
        -	To check the npm version: `npm --version`
    4. Run the following command to update npm: `npm install -g npm@latest` .

    How to install Node.js on Linux:
      1. Run in your terminal the following command to install the curl command-line tool: `sudo apt install curl` .
      2. Choose the Node.js version for your Linux Distribution from Node.js Distributions page and follow the installation instructions: https://github.com/nodesource/distributions
      3. To verify the installation open your Linux terminal and run the following commands:
          -	To check the node version: `Node –version`
          -	To check the npm version: `npm --version`
      4. To update npm run `sudo npm install -g n` and then `sudo n latest`

- #### Terraform
  Choose Windows or Linux and follow the installation instructions on the page: https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

- #### Azure CLI

  How to install Azure CLI on Windows:
  1. Download Azure CLI by clicking **Latest release of the Azure CLI** button in the page: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli
  2. Check the “**I accept**” box and click **Install**.

  How to install Azure CLI on Linux:
  1. Choose an installation method and follow the installation instructions: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt

- #### GitHub CLI (Optional)

  How to install GitHub CLI on Windows:
  1. Download needed MSI installer on the releases page: https://github.com/cli/cli/releases/tag/v2.29.0

  How to install GitHub CLI on Linux:
  1. Follow the installation instructions: https://github.com/cli/cli/blob/trunk/docs/install_linux.md

## Pipelines

### How to copy the repository:

#### Authenticate with a GitHub host
1. Run `gh auth login` and do the following steps:
    ```
    ? What account do you want to log into? `GitHub.com`
    ? You're already logged into github.com. Do you want to re-authenticate? `Yes`
    ? What is your preferred protocol for Git operations? `HTTPS`
    ? Authenticate Git with your GitHub credentials? `Yes`
    ? How would you like to authenticate GitHub CLI? `Login with a web browser`
    ! First copy your one-time code: `****-****`
    ```
2. Insert the code into a code field in the browser.

#### Clone a GitHub repository locally
  1. On GitHub page go to the `azure-webapp-ref` repository.
  2. Click `Code` in the upper right corner.
  3. Choose the preferred option, e.g. `HTTPS`, `SSH`, or `GitHub CLI`.
  4. Copy the link and run in the terminal, e.g. in `GitHub Cli` case it would be:
      ```
      gh repo clone CGI-Finland/azure-webapp-ref
      ```

### How to set up GitHub Actions workflows:

#### Create an Azure Active Directory application and service principal
  1. In Azure CLI run
      ```
      az ad app create --display-name "myApp"
      ```
  2. Copy from the output `appId` and run
      ```
      az ad sp create --id $appId
      ```
  3. Copy from the output `id` and run
      ```
      az role assignment create --role contributor --subscription $subscriptionId --assignee-object-id $id --assignee-principal-type ServicePrincipal --scope /subscriptions/{subscription-id}/resourceGroups/{resource-group}
      ```

#### Add federated credentials
  1. Run the following command
      ```
      az rest --method POST --uri 'https://graph.microsoft.com/beta/applications/$appId/federatedIdentityCredentials' --body '{"name":"CredentialName","issuer":"https://token.actions.githubusercontent.com","subject":"repo: <Organization/Repository >:environment:<EnvironmentName>","audiences":["api://AzureADTokenExchange"]}'
      ```

#### Use the Azure login action with a service principal secret
  1. Run the following command
      ```
      az ad sp create-for-rbac --name "myApp" --role contributor --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group}
      ```
  2. Copy from the output `clientSecret`.

#### Create GitHub secrets
  1. In GitHub repository go to **Settings**.
  2. In **Security** section click on **Secrets and variables** and then click on **Actions**.
  3. Click **New repository secret** and add: \
    - AZURE_CLIENT_ID (`appId`) \
    - AZURE_CLIENT_SECRET (`clientSecret`) \
    - AZURE_SUBSCRIPTION_ID (`subscriptionId`) \
    - AZURE_TENANT_ID (`tenantId`)

## IaC

File structure
```
CDKTF/
├── .github/
│   └── workflows/
│       └── workflows.yml
├── vnet/
│   ├── outputs.tf
│   ├── variables.tf
│   ├── vnet.tf
│   └── vnet.yaml
├── webapp/
│   ├── mywebsite/
│   |   ├── 404.html
│   |   └── index.html
│   ├── frontdoor.tf
│   ├── frontdoor.yaml
│   ├── insights.tf
│   ├── insights.yaml
│   ├── kv.tf
│   ├── kv.yaml
│   ├── outputs.tf
│   ├── postgre.tf
│   ├── postgre.yaml
│   ├── servicebus.tf
│   ├── servicebus.yaml
│   ├── storage.tf
│   ├── storage.yaml
│   ├── variables.tf
│   ├── webapp.tf
│   └── webapp.yaml
├── .gitignore
├── main.tf
├── outputs.tf
├── providers.tf
├── rg.tf
└── variables.tf
```

Setting the preferences:
- Change
  - needed variables in `./variables.tf` file
  - needed variables in following yaml-files:
    - `vnet/vnet.yaml`
    - `webapp/frontdoor.yaml`
    - `webapp/insights.yaml`
    - `webapp/kv.yaml`
    - `webapp/postgre.yaml`
    - `webapp/servicebus.yaml`
    - `webapp/storage.yaml`
    - `webapp/webapp.yaml`
- In the terminal run `terraform init`.
- In order to check infrastructure
apply the following beforehand: `terraform plan`.
- Push changes to your GitHub repository.

> Infrastructure applying can be checked in GitHub Actions workflow. For that go to your repository, click **Actions** and click the latest running workflow in the **All workflows**.
>
> After applying all needed resources of infrastructure will appear in Azure.

> Since Azure PostGreSQL should scale automatically it shouldn't use Basic pricing tiers. Dynamic scaling to and from the Basic pricing tiers is currently not supported.
>
> Azure Database for PostgreSQL is set as a Single Server since it supports Private link. Access to PostGreSQL is implemented by limitation to Vnet. Due to that, developers/admins IP’s should be added to PostGreSQL’s firewall (i.e. to `firewall_rule` in postgre.yaml).

> Vnet has two subnets. One of them has delegation and it's implemented for Linux Web App. The other one is set for private endpoints of the following resources: `Insights`, `ServiceBus`, `KeyVault`, `PostgreSQL`. Application Insights in addition to endpoint uses Monitor Private Link Scope.

> The `extension_version` setting of Application Insights is used in the Linux Web App, as well as `APPINSIGHTS_INSTRUMENTATIONKEY` and `APPLICATIONINSIGHTS_CONNECTION_STRING`.

> Key Vault uses a customer-managed key for Azure Storage encryption. To add a key to the Key Vault, the user is assigned the `Key Vault Crypto Officer` role.

> Service Bus private access is only available for Premium namespaces with the following capacity: 1, 2, 4, 8, or 16.

> In the Storage account `static_website` settings can only be set if the `account_kind` is set to `StorageV2` or `BlockBlobStorage`. In addition, the  storage account must have `identity` settings set for Key Vault.

> Linux Web App connects to the Storage account by Service Connector and to Service Bus using the `connection_string`. The `site_config` settings of Linux Web App must be set for Front Door. Additionally, the `identity` setting must be set for Key Vault as well.

## Frontend
Home page `index.html` and error page `404.html` are placed in `./webapp/mywebsite/` folder. They can be changed if needed.

## Backend
TBD

# Other documentation
Material in PPTX can be found [here](https://groupecgi.sharepoint.com/:p:/r/teams/COL00012971/Shared%20Documents/Developer%20portal/BU_ICE_Reference_architecture_Azure-v1.pptx?d=w1771e4f3f3784532a3dff9138e8144e2&csf=1&web=1&e=GbOltT).
