#!/usr/bin/env bash

[ -f .env ] && source .env
source logger.sh
source discuss-api.sh

INDEX=bytes-discuss

# Check the settings
if [ "$DISCUSS_API_KEY" = "" ];
then
  echo "You must define DISCUSS_API_KEY in the .env file. Create a new key if needed from https://discuss.elastic.co/admin/api/keys."
  exit 1
fi
# Init the bulk file and the error file
echo "" > debug.log

# START

if [ "$1" != "" ];
then
  START_PAGE=$1
fi

## Delete Elasticsearch Index
#log_info "# Delete Elasticsearch Index"
#curl -s -XDELETE "$ELASTICSEARCH_URL/$INDEX" -H "Authorization: ApiKey $ELASTIC_API_KEY" -H 'Content-Type: application/json' | jq ; echo

## Update Elasticsearch Template
log_info "# Update Elasticsearch Template"
curl -s -XPUT "$ELASTICSEARCH_URL/_index_template/$INDEX" -H "Authorization: ApiKey $ELASTIC_API_KEY" -H 'Content-Type: application/json' --data-binary "@discuss-template.json" | jq ; echo

## Welcome message
log_info "# Reading topics from page $START_PAGE."

## Init output files
[ -f "$ERROR_FILE" ] && rm "$ERROR_FILE"

## Read the list of topics
for ((page=$START_PAGE; ; page++)); do
    # Clean the bulk file
    BULK_FILE=bulks/bulk-$page.ndjson
    echo "" > "$BULK_FILE"

    log_info "# Reading page $page"
    if ! topics=$(read_topics_page "$page");
    then
      echo "Error caugth: $topics"
      break
    else
      if jq -e '. | length == 0' >/dev/null; then 
        break
      else
        # Read the solution topic id from the topics
        while read topic_id; do
          log_debug "## Read topic $topic_id"
          read_topic "$topic_id" "$BULK_FILE"
        done <<< "$topics"
      fi <<< "$topics"
    fi

    # Bulk insert
    ./manual_bulk.sh "$page"
done

