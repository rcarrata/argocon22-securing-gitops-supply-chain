# Sign Images with Sigstore

## Install ArgoCD / OpenShift GitOps:

* Install ArgoCD / OpenShift GitOps

```sh
until kubectl apply -k bootstrap/argocd/; do sleep 2; done
```

* After couple of minutes check the OpenShift GitOps and Pipelines:

```sh
ARGOCD_ROUTE=$(kubectl get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}{"\n"}')

curl -ks -o /dev/null -w "%{http_code}" https://$ARGOCD_ROUTE
```

## Deploy Tekton Tasks and Kyverno using GitOps

First, let's install Kyverno with GitOps using Helm chart.

* To do that, let's deploy an ArgoCD Application with the Helm chart and the targetRevision for Kyverno:

```sh
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kyverno
  namespace: openshift-gitops
spec:
  destination:
    namespace: kyverno
    server: https://kubernetes.default.svc
  project: default
  source:
    helm:
    chart: kyverno
    repoURL: https://kyverno.github.io/kyverno/
    targetRevision: v2.3.1
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

* Let's apply it in our K8S/OCP cluster:

```sh
kubectl apply -f argocd/kyverno-app.yaml
```

* After a couple of minutes, our Kyverno components are deployed in the Kubernetes clusters, and all are in sync:

[![](/images/signing2.png "signing2.png")]({{site.url}}/images/signing2.png)

NOTE: remember that you need to patch the Kyverno Deployment to add the registry credentials as we showed in the first part of this blog post:

```sh
kubectl get deploy kyverno -n kyverno -o yaml | grep containers -A5
      containers:
      - args:
        - --imagePullSecrets=regcred
        env:
        - name: INIT_CONFIG
          value: kyverno
```

Once we have Kyverno installed let's install the Tekton Tasks and Pipelines into the namespace selected.

## Deploy Tekton Pipeline and Tasks

* Export the token for the GitHub Registry / ghcr.io:

```bash
export PAT_TOKEN="xxx"
export EMAIL="xxx"
export USERNAME="rcarrata"
export NAMESPACE="workshop"
```

* Generate a docker-registry secret with the credentials for GitHub Registry to push/pull the images and signatures:

```bash
kubectl create secret docker-registry ghcr-auth-secret --docker-server=ghcr.io --docker-username=${USERNAME} --docker-email=${EMAIL}--docker-password=${PAT_TOKEN} -n ${NAMESPACE}
```

* Deploy all the Tekton Tasks and Pipelines for run this demo:

```bash
kubectl apply -k pipelines/
```

## Generate Sigstore KeyPairs

* Generate a pki key-pair for signing with cosign:

```bash
export COSIGN_PASSWORD=redhat
cosign generate-key-pair k8s://${NAMESPACE}/cosign
```

* Generate a docker-registry secret with the credentials for GitHub Registry to allow the Kyverno to download the signature from GitHub registry in order to verify the image:

```bash
kubectl create secret docker-registry regcred --docker-server=ghcr.io --docker-username=${USERNAME} --docker-email=${EMAIL}--docker-password=${PAT_TOKEN} -n kyverno
```

* Update the kyverno imagepullsecrets to include the registry creds:

```bash
kubectl get deploy kyverno -n kyverno -o yaml | grep containers -A5
      containers:
      - args:
        - --imagePullSecrets=regcred
        env:
        - name: INIT_CONFIG
          value: kyverno
```

## Run Signed Pipeline

* Run the pipeline for build the image, push to the GitHub registry, sign the image with cosign, push the signature of the image to the GitHub registry:

```bash
kubectl create -f run/sign-images-pipelinerun.yaml
```

* This pipeline will deploy the signed image and also will be validated against kyverno cluster policy:

```bash
k get deploy -n workshop pipelines-vote-api
NAME                 READY   UP-TO-DATE   AVAILABLE   AGE
pipelines-vote-api   1/1     1            1           29h
```

<img align="center" width="570" src="assets/signed-1.png">

## Run Unsigned Pipeline

* Run the pipeline for build the image and push to the GitHub registry, but this time without sign with cosign private key:

```bash
kubectl create -f run/unsigned-images-pipelinerun.yaml
```

* The pipeline will fail because, in the last step the pipeline will try to deploy the image, and the Kyverno Cluster Policy will deny the request because it's not signed with the cosign step using the same private key as the pipeline before:

<img align="center" width="970" src="assets/unsigned-1.png">

* As we can see the error that the pipeline outputs it's due to the Kyverno Cluster Policy with the image signature mismatch error:

<img align="center" width="570" src="assets/unsigned-2.png">
