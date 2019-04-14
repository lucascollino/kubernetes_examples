# Hashicorp Vault in Kubernetes with HA, TLS enabled and consul-free

Haven't had an easy time finding complete examples for this specific scenario, so here goes a tryin' to fill the void (or my lack of google-fu).

## Use case
A simple key value store (using the newer vault kv2 engine). Users are mapped through LDAP groups (not covered here, will be added shortly).
It's a simple and flexible way to store secrets per env/app/team ot whatever path you need.
Secrets can contain:
  - user passwords
  - app passwords and tokens
  - certificates
  - sensible configs can be imported directly to an app using native libraries.
Vault is much more complete than what this doc covers.

## Requirements

This guide assumes an AWS account and a running Kubernetes cluster with the following requirements.

### AWS
- S3 bucket
- DynamoDB table (for HA lock management)
- KMS key (to encrypt sensible data in the bucket and auto unseal)
- IAM role to manage the aws resources.

### Kubernetes
- In this example we use [Helm](https://github.com/helm/helm), though you could manage templated yamls with [kubetpl](https://github.com/shyiko/kubetpl) and be happier.
- [nginx ingress controller]()
- [kiam](https://github.com/helm/charts/tree/master/stable/kiam) (you can manage AWS roles directly at instance level but this is better).
- [vault](https://github.com/helm/charts/tree/master/incubator/vault)
- A secret with a cert and key you can use (in this case it's provided by [cert-manager](https://github.com/helm/charts/tree/master/stable/cert-manager). You can use [this guide](https://itnext.io/using-wildcard-certificates-with-cert-manager-in-kubernetes-and-replicating-across-all-namespaces-5ed1ea30bb93)as a good starting point.

## Installation

### S3 bucket
Create the bucket.
```
$ aws --region us-east-1 --profile company s3api create-bucket --bucket company_vault
```
Your bucket ARN is:
```
arn:aws:s3:::company-vault
```
### DynamoDB table

It will be created by vault. The example Kiam role file containes a policy that allows this.

### KMS Key

Update the file [kms_key_policy.json](aws_files/kms_key_policy.json) to match your infrastructure.
Create the Customer Managed Key, its alias, and take note of the ARN:

```
$ aws --region us-east-1 --profile company kms create-key --policy file://aws_files/kms_key_policy.json
$ aws --region us-east-1 --profile company kms create-alias --alias-name alias/k8s_vault --target-key-id 1234abcd-12ab-34cd-56ef-1234567890ab
$ aws --region us-east-1 --profile company kms describe-key --key-id alias/k8s_vault
```

### kiam role

Update the file [vault_role_trust_relationship.json](aws_files/vault_role_trust_relationship.json) with your data and create the role.
```
$ aws --profile company iam create-role --role-name k8s_vault --assume-role-policy-document file://aws_files/vault_role_trust_relationship.json
```
Update the file [vault_policy.json](aws_files/vault_policy.json) and deploy it.
```
$ aws --profile company iam put-role-policy --role-name k8s_vault --policy-name k8s_vault --policy-document file://aws_files/vault_policy.json
```

### Vault install

Make sure bucket and dynamodb table names in [vault.yaml](vault.yaml) match the ones you created.

```
$ kubectl create ns vault
$ kubectl edit ns vault
```
Add the following to the namespace metadata.
```
  annotations:
    iam.amazonaws.com/permitted: vault
```
Install the chart.
```
$ cd vault
$ source vault.sh
$ ../chartInstaller.sh install
```
Initialize the Vault cluster and check status before and after:
```
$ export VAULT_ADDR='http://vault.mycompany.com'
$ vault status
$ vault operator init
$ vault status
```
List the mounts to check everything is working:
```
$ export VAULT_TOKEN='the token you just created'
$ vault read sys/mounts
```
Store the keys and root token in a safe place, don't use the root token, either link it to your LDAP or create user/pass resources in the identity engine.
