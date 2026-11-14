az deployment group create ^
    --name TestBastion ^
    --resource-group (redacted) ^
    --subscription (redacted) ^
    --template-file template.json ^
    --parameters @parameters.json