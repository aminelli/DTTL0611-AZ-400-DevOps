# Creare un gruppo con approccio Imperativo o Dichiarativo


## Approccio Imperativo

```bash
# Creo gruppo con approccio imperativo
az group create --name GRPIPPO --location northeurope
```

## Approccio Dichiarativo

```bash
# Creo gruppo con approccio dichiarativo
az deployment sub create --location northeurope  --name dist_tony_test --template-file .\template.json --parameters ./parameters.json
```

