# !/bin/bash

kubectl apply -k kustomize/install
kubectl -n default wait --for condition=established --timeout=60s crd/postgresclusters.postgres-operator.crunchydata.com
kubectl -n default wait --for condition=available --timeout=60s deployment/pgo
kubectl apply -k kustomize/postgres -n default