#!/usr/bin/env bash

[ -f .env ] && source .env

# Debug level: 1=INFO, 2=DEBUG, 3=TRACE
DEBUG_LEVEL=2
INDEX=bytes-discuss

page=$1

# Utility functions
log_info() {
  if [ "$DEBUG_LEVEL" -gt 0 ];
  then
    echo "[INFO ] $1"
  fi
}

# Bulk insert
BULK_FILE=bulks/bulk-$page.ndjson

NB_LINES=`expr $(wc -l < "$BULK_FILE") / 2`
log_info "# Bulk insert $NB_LINES lines"
echo "#################################### " >> debug.log
echo "#### BULK INSERT for page $page #### " >> debug.log
response=$(curl -s -XPOST "$ELASTICSEARCH_URL/$INDEX/_bulk" -H "Authorization: ApiKey $ELASTIC_API_KEY" -H 'Content-Type: application/x-ndjson' --data-binary "@$BULK_FILE")
error_type=$(echo "$response" | jq '.status')
if (("$error_type" > 299));
then
  jq '.' <<< "$response"
  exit 1
fi
echo "##### BULK DONE for page $page ##### " >> debug.log
echo "#################################### " >> debug.log
jq '{ "took": .took, "errors": [.items[] | select(.index.status>299)] }' <<< "$response"
