# Hashicorp Vault in K8s with HA, TLS enabled and  consul-free

Haven't had an easy time finding complete docs for this specific scenario, so here goes a tryin' to fill the void (or my lack of google-fu).

## Requirements

### AWS
- S3 bucket
- DynamoDB table (for HA lock management)
- KMS key (to encrypt sensible data in the bucket and auto unseal)
- IAM role to manage the aws resources.

### Kubernetes
- In this example we use [Helm](https://github.com/helm/helm), though you could manage templated yamls with [kubetpl](https://github.com/shyiko/kubetpl) and be happier.
- [kiam](https://github.com/helm/charts/tree/master/stable/kiam) (you can manage AWS roles directly at instance level but this is better).
- [vault](https://github.com/helm/charts/tree/master/incubator/vault)
- A secret with a cert and key you can use (in this case it's provided by [Cert-manager](https://github.com/helm/charts/tree/master/stable/cert-manager)

## Installation

### S3 bucket
Create the bucket:
```
$ aws --region us-east-1 --profile company s3api create-bucket --bucket company_vault
```
Your bucket ARN is:
```
arn:aws:s3:::company-vault
```
### DynamoDB table

Will be created by vault. The example role file containes a policy that supports this.

### KMS Key

Create the Customer Managed Key, its alias, and take note of the ARN:

```
$ aws --region us-east-1 --profile company kms create-key --policy file://aws_files/kms_key_policy.json
$ aws --region us-east-1 --profile company kms create-alias --alias-name alias/k8s_vault --target-key-id 1234abcd-12ab-34cd-56ef-1234567890ab
$ aws --region us-east-1 --profile company kms describe-key --key-id alias/k8s_vault
```

### kiam role

Update the file `vault_role_trust_relationship.json` with your data and create the role:
```
$ aws --profile company iam create-role --role-name k8s_vault --assume-role-policy-document file://aws_files/vault_role_trust_relationship.json
```
Update the file `vault_policy.json` and deploy it:
```
$ aws --profile company iam put-role-policy --role-name k8s_vault --policy-name k8s_vault --policy-document file://aws_files/vault_policy.json
```

### Vault install

Make sure bucket and dynamodb table names in your values.yaml match the ones you created

```
$ kubectl create ns vault
$ kubectl edit ns vault
```
add the following to the namespace metadata
```
  annotations:
    iam.amazonaws.com/permitted: vault
```
install the chart
```
$ source vault_sandbox.sh
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
