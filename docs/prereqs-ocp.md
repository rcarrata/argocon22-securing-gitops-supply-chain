## Pre Requisites for run the demo in OpenShift

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

## TBD

```
oc adm policy add-scc-to-user -n argo -z default anyuid
```

* Export the token for the GitHub Registry / ghcr.io:

```bash
export PAT_TOKEN="xxx"
export EMAIL="xxx"
export USERNAME="rcarrata"
export NAMESPACE="workshop"
```

* Generate a docker-registry secret with the credentials for GitHub Registry to push/pull the images and signatures:

```bash
kubectl create secret docker-registry regcred --docker-server=ghcr.io --docker-username=${USERNAME} --docker-email=${EMAIL} --docker-password=${PAT_TOKEN} -n ${NAMESPACE}
```

* Add proper permissions to run the pipeline

```
oc adm policy add-role-to-user -n argo -z default admin
```


## Adding regcred to kyverno to read the signatures

```
kubectl get deploy kyverno -n kyverno -o yaml | grep containers -A5
--
      containers:
      - args:
        - --imagePullSecrets=regcred
        env:
        - name: INIT_CONFIG
          value: kyverno
```

```
kubectl create secret docker-registry regcred --docker-server=ghcr.io --docker-username=${USERNAME} --docker-email=${EMAIL} --docker-password=${PAT_TOKEN} -n kyverno
```

## Add regcreds to the pullsecret

```
export NAMESPACE=argo
export SERVICE_ACCOUNT_NAME=argo
kubectl patch serviceaccount $SERVICE_ACCOUNT_NAME \
  -p "{\"imagePullSecrets\": [{\"name\": \"regcred\"}]}" -n $NAMESPACE
kubectl patch serviceaccount default \
 -p "{\"imagePullSecrets\": [{\"name\": \"regcred\"}]}" -n $NAMESPACE
 oc secrets link default regcred -n argo
```




## Adding Slack to Argo Notifications

```
https://github.com/argoproj/argo-workflows/blob/master/examples/exit-handler-slack.yaml
```