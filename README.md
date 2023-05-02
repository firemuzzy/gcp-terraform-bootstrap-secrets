# gcp-terraform-bootstrap-secrets

A demo of how I ended up loading in secrets into terraform from google cloud secrets manger

## Initial problem

I am using terraform to manage my Cloud Run deployments but the Cloud Run deployments depend on secrets. Therefore Secret Manager secrets have to exist before `terraform apply` is run otherwise `Cloud Run` services fail to state

All the tutorials online use hardcoded secrets which defeat the purpose of using a secrets manger. Following John Hanley comment from https://stackoverflow.com/questions/76149258  the solution I settled on is to have secrets separate from terraform with terraform only injecting them to use them. 

I am also choosing to prefill my secrets with random values if they do not exist. This allows me to start up the cloud run service, although the service will not correctly boot up due to missing secrets, I know my infrastructure is set up.

After go into google console, set the secrets and restart the cloud run service and all is good.


## Overview

- uses GCP bucket for tf state
- secrets are bootstrapped with a bash script with random values if no secrete value is present
- secrets are imported into terraform
- terraform creates the infrastructure to run a cloud run service with the secrets

## To Run

```
# update SECRETS in gcloud.init.sh and in `main.tf` for different secrets

> ./gcloud.init.sh -p [GCLOUD_PROJECT_ID]

# will create state.tf and terraform.tfvars
# will create state bucket
# will seed the secrets
# will run terraform init, need to import afterwards
# will import the secrets into terraform

> terraform apply
```

## About files

- `gcloud.init.sh`: bash script to bootstrap the project with secrets
- `main.tf`: tf local and provider
- `project.tf`: service enabling and service account for cloud run
- `secrets.tf`: defines `google_secret_manager_secret` resources that are imported by `gcloud.init.sh` and used by cloud run service
- `service.tf`: defines the cloud run service
- `variables.tf`: variable validation
- `state.tf.template`: a template used by `gcloud.init.sh` to generate a `state.tf` file. Am not allowed to reverence variables in `state.tf` so my bash script create it using the project id that is passed into the bash script
- `state.tf`: a `gcloud.init.sh` generate state file
- `terraform.tfvars`: variables, `project` and `region` ar added in by `gcloud.init.sh`


## Problems:

- secret keys are duplicated in two places, in `gcloud.init.sh` and in `main.locals`
- terraform will destroy imported secrets on `terraform destroy` so it can clean up everything, be careful
- terraform cloud run does not clean up a starts cloud service on error you will have to manually delete it if you need to run `terraform apply` after an error
> Error creating Service: googleapi: Error 409: Resource 'my-service' already exists