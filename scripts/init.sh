export PG_CLUSTER_SUPERUSER_SECRET_NAME=hippo-pguser-postgres
export PGSUPERPASS=$(kubectl get secrets -n nate-test "${PG_CLUSTER_SUPERUSER_SECRET_NAME}" -o go-template='{{.data.password | base64decode}}')
export PGSUPERUSER=$(kubectl get secrets -n nate-test "${PG_CLUSTER_SUPERUSER_SECRET_NAME}" -o go-template='{{.data.user | base64decode}}')
shp2pgsql -D -s 4326 ./data/ne_50m_admin_0_countries/ne_50m_admin_0_countries.shp | PGPASSWORD=$PGSUPERPASS psql -d naturalearth -h localhost -U postgres

PGPASSWORD=$PGSUPERPASS psql -h localhost -U $PGSUPERUSER -d uscounties < ./data/postgis.sql
PGPASSWORD=$PGSUPERPASS pg_restore -h localhost -U $PGSUPERUSER -d uscounties ./data/census.sql
PGPASSWORD=$PGSUPERPASS psql -h localhost -U $PGSUPERUSER -d uscounties < ./data/perms.sql

kubectl apply -k kustomize/pg_tileserv
sleep 10
kubectl -n nate-test port-forward svc/tileserv 7800:7800