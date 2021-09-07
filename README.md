# Caching PostGIS Vector Tiles on Kubernetes

In a previous blog post, Paul Ramsey discusses how to increase the performance of serving dynamic vector tiles via adding a caching layer in between pg_tileserv and your users.

Let’s take this one step further by deploying this caching layer, along with a high availability PostGIS-enabled database to Kubernetes.

First off pull down this repo: https://github.com/nfickas/k8s-tile-caching	
It contains all of the necessary resources to be able to run this demonstration.

## Deploy a PostGIS Database

Deploy the open-sourced Postgres operator:
```bash
kubectl apply -k kustomize/operator
```

Now let’s deploy our Postgres cluster, the operator will detect this custom resource and spin up a PostGIS-enabled Postgres cluster with two replicas:
```bash
kubectl apply -k kustomize/postgres
```


## Load Data

Next we need some sample data to be able to show off our solution, let’s utilize the Natural Earth countries data: https://www.naturalearthdata.com/downloads/50m-cultural-vectors/

Port-forward the database:
```bash
export PG_CLUSTER_PRIMARY_POD=$(kubectl get pod -n default -o name -l postgres-operator.crunchydata.com/cluster=hippo,postgres-operator.crunchydata.com/role=master)
kubectl -n default port-forward "${PG_CLUSTER_PRIMARY_POD}" 5432:5432
```

Then to load the data and give our tileserv user permissions to select on the new table:
```bash
export PG_CLUSTER_SUPERUSER_SECRET_NAME=hippo-pguser-postgres
export PGSUPERPASS=$(kubectl get secrets -n default "${PG_CLUSTER_SUPERUSER_SECRET_NAME}" -o go-template='{{.data.password | base64decode}}')
export PGSUPERUSER=$(kubectl get secrets -n default "${PG_CLUSTER_SUPERUSER_SECRET_NAME}" -o go-template='{{.data.user | base64decode}}')
PGPASSWORD=$PGSUPERPASS psql -h localhost -U $PGSUPERUSER -d postgres < ./data/postgis.sql
shp2pgsql -D -s 4326 ./data/ne_50m_admin_0_countries/ne_50m_admin_0_countries.shp | PGPASSWORD=$PGSUPERPASS psql -d postgres -h localhost -U $PGSUPERUSER
PGPASSWORD=$PGSUPERPASS psql -h localhost -U $PGSUPERUSER -d postgres < ./data/perms.sql
```


## Deploy pg_tileserv

After the Postgres cluster is ready to serve data, let’s spin up pg_tileserv to dynamically serve our vector tiles:
```bash
kubectl apply -k kustomize/pg_tileserv
```

As you can see from the `kustomize/pg_tileserv/deployment.yaml` file we are pulling the DATABASE_URL environment variable from the tileserv user’s secret credential information that the operator created for us.


## Deploy varnish

Next we need to enable our caching layer, for this example we are going to utilize Varnish and specifically we will be using IBM’s Varnish Operator. To install the Varnish Operator: https://ibm.github.io/varnish-operator/quick-start.html
```bash
helm repo add varnish-operator https://raw.githubusercontent.com/IBM/varnish-operator/main/helm-releases
helm install varnish-operator --namespace default varnish-operator/varnish-operator
```

Then use the following to deploy a VarnishCluster:
```bash
cat <<EOF | kubectl create -f -
apiVersion: caching.ibm.com/v1alpha1
kind: VarnishCluster
metadata:
  name: varnishcluster-example
  namespace: default # the namespace we've created above
spec:
  varnish:
    args: ["-p", "default_ttl=600"]
  vcl:
    configMapName: vcl-config # name of the config map that will store your VCL files. Will be created if doesn't exist.
    entrypointFileName: entrypoint.vcl # main file used by Varnish to compile the VCL code.
  replicas: 2 # run 3 replicas of Varnish
  backend:
   # pod selector to identify the pods being cached
   selector:
     app: tileserv
   port: 7800
  service:
    port: 80 # Varnish pods will be exposed on that port
EOF
```


## Test it Out

We now have a fully functioning caching layer, but let’s test it out just to make sure. We will utilize the below provided html file containing an OpenLayers map to ensure that everything is functioning as expected.

Our openlayers map is expecting our tile server to be served over `localhost:8080`. So port-forward the varnish service to port 8080 using the following command:
```bash
kubectl port-forward -n default svc/varnishcluster-example 8080:80
```

Open the `openlayers.html` file located in the root directory in your browser of choice.

Now mess around with the map by zooming in and out or whatever type of actions you would like to take, after a few actions you will see the tileserver logs go quiet since Varnish has successfully cached the recently used tiles from pg_tileserv.
