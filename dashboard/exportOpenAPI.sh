#!/bin/sh -e

cd /usr/local/apisix-dashboard

USER=admin
CONF_FILE=exportOpenAPI.conf
LOGIN_JSON=logs/apisix-login.json
ROUTE_JSON=logs/apisix-route.json
ROUTE_YAML=html/swagger/APISIX_routes.yaml

## Check configuration file
if [ ! -e "$CONF_FILE" ] ; then
    echo "SCHEME=http" >> $CONF_FILE
    echo "HOST=10.50.0.22" >> $CONF_FILE
    echo "PORT=30003" >> $CONF_FILE
fi
source $CONF_FILE

## Get admin's password
PASS=`yq eval ".authentication.users[] | select(.username == \"$USER\").password" /usr/local/apisix-dashboard/conf/conf.yaml`
if [ "$PASS" = "" ] ; then
    PASS=admin
fi

## Get login token
CMDSTR=`printf 'curl -s -o %s --request POST --header "Content-Type: application/json" --data %s{"username":"%s","password":"%s"}%s http://127.0.0.1:9000/apisix/admin/user/login' $LOGIN_JSON "'" $USER $PASS "'"`
echo $CMDSTR > tmp.sh
/bin/sh tmp.sh
TOKEN=`jq -r ".data.token" $LOGIN_JSON`
rm tmp.sh

## Export all routes
curl -s -o $ROUTE_JSON --request GET --header "Content-Type: application/json" --header "Authorization: $TOKEN" http://127.0.0.1:9000/apisix/admin/export/routes

## Transfer JSON to YAML
CODE=`jq -r ".code" $ROUTE_JSON`
if [ ! "$CODE" = "0" ] ; then
    echo '{ "data":{ "components":{ "securitySchemes":{ "api_key": { "in": "header", "name": "X-XSRF-TOKEN", "type": "apiKey" } } }, "info":{ "title":"RoutesExport", "version":"3.0.0" }, "openapi":"3.0.0", "paths":{} } }' > $ROUTE_JSON
fi

echo "servers:
  - url: $SCHEME://{hostName}:{portNum}
    variables:
      hostName:
        default: $HOST
        description: APISIX Gateway's IP/Name
      portNum:
        default: $PORT" > $ROUTE_YAML
jq -r ".data" $ROUTE_JSON | yq -p=json -o=yaml . | grep -v "requestBody: {}" >> $ROUTE_YAML
