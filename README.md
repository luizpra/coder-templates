# Coder templates

```sh
coder login
coder templates list
coder templates pull <template-name> ./<new-template-name>
coder templates push <new-template-name> -d ./<new-template-name>
```

## Coder APP
To rum coder apps we have to define a terraform `coder_app` resource.
`https://registry.terraform.io/providers/coder/coder/2.1.0/docs/resources/app`



### Angular
```sh
ng server --disable-host-check --base-href "@luiz/test.main/apps/angular"
```
