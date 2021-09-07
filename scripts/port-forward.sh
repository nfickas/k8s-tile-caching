export PG_CLUSTER_PRIMARY_POD=$(kubectl get pod -n nate-test -o name -l postgres-operator.crunchydata.com/cluster=hippo,postgres-operator.crunchydata.com/role=master)

kubectl -n nate-test port-forward "${PG_CLUSTER_PRIMARY_POD}" 5432:5432