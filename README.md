# Hello World Module
## A Helm Chart for an example Fybrik module

## Introduction

This helm chart defines a common structure to deploy a Kubernetes job for an Fybrik module.

The configuration for the chart is in the values file.

## Prerequisites

- Kubernetes cluster 1.10+
- Helm 3.7.x

## Installation

### Modify values in Makefile

In `Makefile`:
- Change `DOCKER_USERNAME`, `DOCKER_PASSWORD`, `DOCKER_HOSTNAME`, `DOCKER_NAMESPACE`, `DOCKER_TAGNAME`, `DOCKER_NAME`, `HELM_TAG` to your own preferences.

### Build Docker image for Python application
```bash
make docker-build
```

### Push Docker image to your preferred container registry
```bash
make docker-push
```

### Configure the chart
- When testing the chart, configure settings by editing the `values.yaml` directly.
- Modify repository in `values.yaml` to your preferred Docker image. 
- Modify copy/read action as needed with appropriate values.
- At runtime, the `fybrik-manager` will pass in the copy/read values to the module so you can leave them blank in your final chart. 

## Register as a Fybrik module

To register HWM (Hello World Module) as a Fybrik module apply `hello-world-module.yaml` to the fybrik-system namespace of your cluster.

To install the latest release run:

```bash
kubectl apply -f https://github.com/fybrik/hello-world-module/releases/latest/download/hello-world-module.yaml -n fybrik-system
```

### Version compatbility matrix

| Fybrik           | HWM     | Command
| ---              | ---     | ---
| 0.5.x            | 0.5.x   | `https://github.com/fybrik/hello-world-module/releases/download/v0.5.0/hello-world-module.yaml`
| 0.6.x            | 0.6.x   | `https://github.com/fybrik/hello-world-module/releases/download/v0.6.0/hello-world-module.yaml`
| master           | main    | `https://raw.githubusercontent.com/fybrik/hello-world-module/main/hello-world-module.yaml`



### Login to Helm registry
```bash
make helm-login
```

### Lint and install Helm chart
```bash
make helm-verify
```

### Push the Helm chart

```bash
make helm-chart-push
```

## Uninstallation
```bash
make helm-uninstall
```

## Deploy and test Fybrik module

Follow this section to deploy and test the module on a single cluster.

### Before you begin

Install Fybrik using the [Quick Start](https://fybrik.io/dev/get-started/quickstart/) guide. This sample assumes the use of the built-in catalog, Open Policy Agent (OPA) and flight module.

> ***Notice: Please follow `version compatbility matrix` section above for deploying the correct version of Fybrik and this module. 
For deploying older versions of hello-world-module please refer to the `README.md` file in the relevant release. For older version of Fybrik please follow the instructions in Fybrik site which match the release.***

### Deploy DataShim

Deploy [datashim](https://github.com/datashim-io/datashim) on the cluster:

```bash
   kubectl apply --validate=false -f https://raw.githubusercontent.com/datashim-io/datashim/master/release-tools/manifests/dlf.yaml
   kubectl wait --for=condition=ready pod -n dlf --all --timeout=120s
```

### Deploy Fybrik module

Deploy `FybrikModule` in `fybrik-system` namespace:
```bash
kubectl create -f hello-world-module.yaml -n fybrik-system
```
### Test using Fybrik Notebook sample

1. Execute all the sections in [Fybrik Notebook sample](https://fybrik.io/dev/samples/notebook/) until `Define data access policies` section (excluded).

1. Deploy the following `FybrikStorageAccount` and a secret resources. These resources are used by the Fybrik to allocate a new bucket for the copied resource.

```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: bucket-creds
  namespace: fybrik-system
type: Opaque
stringData:
  access_key: "${ACCESS_KEY}"
  accessKeyID: "${ACCESS_KEY}"
  secret_key: "${SECRET_KEY}"
  secretAccessKey: "${SECRET_KEY}"
EOF
```
```bash
cat << EOF | kubectl apply -f -
apiVersion:   app.fybrik.io/v1alpha1
kind:         FybrikStorageAccount
metadata:
  name: storage-account
  namespace: fybrik-system
spec:
  id: theshire
  endpoints:
    theshire: "http://localstack.fybrik-notebook-sample.svc.cluster.local:4566"
  secretRef:  bucket-creds
EOF
```

### Define data access policies

  Define the following [OpenPolicyAgent](https://www.openpolicyagent.org/) policy to allow the write operation:

```bash
package dataapi.authz

description := "allow the write operation"
rule[{}] {
  input.action.actionType == "write"
  true
}
```

  In this sample only the policy above is applied. Copy the policy to a file named sample-policy.rego and then run:

```bash
kubectl -n fybrik-system create configmap sample-policy --from-file=sample-policy.rego
kubectl -n fybrik-system label configmap sample-policy openpolicyagent.org/policy=rego
while [[ $(kubectl get cm sample-policy -n fybrik-system -o 'jsonpath={.metadata.annotations.openpolicyagent\.org/policy-status}') != '{"status":"ok"}' ]]; do echo "waiting for policy to be applied" && sleep 5; done
```
### Deploy Fybrik application which triggers module
Deploy `FybrikApplication` in `default` namespace:
```bash
kubectl apply -f fybrikapplication.yaml -n default
```
3.  Run the following command to wait until the `status` of the `FybrikApplication` is `ready`:
```bash
while [[ $(kubectl get fybrikapplication my-notebook -n default -o 'jsonpath={.status.ready}') != "true" ]]; do echo "waiting for FybrikApplication" && sleep 5; done
```

4.  Check if module was triggered:
```bash
kubectl get blueprint -n fybrik-system
kubectl describe blueprint my-notebook-default -n fybrik-system
kubectl get job -n fybrik-blueprints
kubectl get pods -n fybrik-blueprints
```
If you are using the `hello-world-module` image, you should see this in the `kubectl logs` of your completed Pod:
```
$ kubectl logs my-notebook-default-copy-hello-world-module-chart-xxxx -n fybrik-blueprints

Hello World Module!

Connection name is paysim-csv

Connection format is csv

Vault credential address is http://vault.fybrik-system:8200

Vault credential role is module

Vault credential secret path is /v1/kubernetes-secrets/paysim-csv?namespace=fybrik-notebook-sample

S3 bucket is demo

S3 endpoint is http://localstack.fybrik-notebook-sample.svc.cluster.local:4566

COPY SUCCEEDED
```

## Clean

Run the following command to delete the fybrik application:
```bash
kubectl delete FybrikApplication my-notebook -n default
```

Run the following command to delete the fybrik module:
```bash
kubectl delete fybrikmodule hello-world-module -n fybrik-system
```

Please execute the `Cleanup` section from [Fybrik notebook sample](https://fybrik.io/dev/samples/notebook/)

