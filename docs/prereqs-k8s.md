## Install all prerequisites for the demo in k8s

### Install K8s Kind Cluster

```
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install docker-ce --nobest 
sudo systemctl enable --now docker
```

```
CLUSTER_NAME="gitops"
cat <<EOF | kind create cluster --name $CLUSTER_NAME --wait 200s --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
```

### Install Nginx Ingress

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
```

### Install Test App

* https://kind.sigs.k8s.io/docs/user/ingress/

```
kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/usage.yaml
curl localhost/foo
curl localhost/bar
```

```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Accessing from outside

```
kcli  ssh -L 8443:localhost:443 centos8
kcli  ssh -L 8080:localhost:80 centos8
```

or 

```
ssh -L 8443:localhost:443 nuc
ssh -L 8443:localhost:8080 nuc
```

```
kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/usage.yaml
```

```
curl localhost:8080/foo
```


### Install Argocd

https://github.com/mvazquezc/opensourcesummit2020/blob/main/deploy-demo-env.md#create-a-cluster-with-kind

```
kubectl create ns argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

```
kubectl -n ingress-nginx patch deployment ingress-nginx-controller -p '{"spec":{"template":{"spec":{"$setElementOrder/containers":[{"name":"controller"}],"containers":[{"args":["/nginx-ingress-controller","--election-id=ingress-controller-leader","--ingress-class=nginx","--configmap=ingress-nginx/ingress-nginx-controller","--validating-webhook=:8443","--validating-webhook-certificate=/usr/local/certificates/cert","--validating-webhook-key=/usr/local/certificates/key","--publish-status-address=localhost","--enable-ssl-passthrough"],"name":"controller"}]}}}}'
```

```
cat <<EOF | kubectl -n argocd apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: argocd-server-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  rules:
  - host: argocd.rober.lab
    http:
      paths:
      - backend:
          serviceName: argocd-server
          servicePort: https
EOF
```


In local
```
cat /etc/hosts | grep argo
127.0.0.1 argocd.rober.lab
```

```
argoPass=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login --insecure --grpc-web argocd.rober.lab --username admin --password $argoPass
```

### Test an Argo App inside of the Kind cluster

```
argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace default
```

## Deploy argo workflows

```
kubectl create ns argo
kubectl apply -n argo -f https://raw.githubusercontent.com/argoproj/argo-workflows/master/manifests/quick-start-postgres.yaml

kubectl get pod -n argo
```

NOTE: For OpenShift:

```
oc adm policy add-scc-to-user -n argo -z default privileged
```


```
cat <<EOF | kubectl -n argo apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: argo-server-workflow-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  rules:
  - host: argo-workflows.rober.lab
    http:
      paths:
      - backend:
          serviceName: argo-server
          servicePort: 2746
EOF
```

```
kubectl create -f https://raw.githubusercontent.com/argoproj/argo-workflows/master/examples/ci.yaml -n argo
```