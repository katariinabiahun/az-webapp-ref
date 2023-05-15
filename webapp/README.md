ohje
1. https://learn.microsoft.com/en-us/azure/static-web-apps/getting-started?tabs=vanilla-javascript
2. https://learn.microsoft.com/en-us/azure/static-web-apps/add-api?tabs=vanilla-javascript

oma try
https://learn.microsoft.com/en-us/azure/static-web-apps/build-configuration?tabs=github-actions
# After the Static Site is provisioned, you'll need to associate your target repository, which contains your web app, to the Static Site, by following the Azure Static Site document.
# https://learn.microsoft.com/en-us/azure/static-web-apps/build-configuration?tabs=github-actions

1. GIT TOKEN  HOW IN PREVIOUS VERSION
https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token

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

2. AZURE_STATIC_WEB_APPS_API_TOKEN (copy from the output)
4b7201ab78e02bb989bbd1fedc83e773ea872df01c1a4e0129e638d02f3b6e6f3-bd2cfffc-842a-40ff-985c-7e7278e1f882003232450

3. github repo with api and src folders

4. add workload
.github/workflows/azure-staticwebapp.yml
