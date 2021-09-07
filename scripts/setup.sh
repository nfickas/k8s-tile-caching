# !/bin/bash

kubectl apply -k kustomize/install
kubectl -n nate-test wait --for condition=established --timeout=60s crd/postgresclusters.postgres-operator.crunchydata.com
kubectl -n nate-test wait --for condition=available --timeout=60s deployment/pgo
kubectl apply -k kustomize/postgres -n nate-test