# Demo Commands for the demo 

kubectl create -f run/securing-gitops-demo-workflow-normal.yaml

sleep 10000

kubectl create -f run/securing-gitops-demo-workflow-hacked.yaml

kubectl apply -k policy

kubectl get clusterpolicy check-image -n kyverno -o yaml

kubectl create -f run/securing-gitops-demo-workflow-signed.yaml

kubectl create -f run/securing-gitops-demo-workflow-hacked.yaml

kubectl apply -f run/securing-gitops-demo-argocd-hacked.yaml
