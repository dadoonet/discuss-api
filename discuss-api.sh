#!/usr/bin/env bash

[ -f .env ] && source .env
source logger.sh

# Read the list of solved topics given a page number. It will retry automatically
# if we get from the API a rate_limit error.
# Usage:
#   read_topics_page page
# Parameters:
#   page: page number (starts from 1)
# Return:
#   the json result from the API
# Example:
# read_user_page 10
read_topics_page () {
  page=$1
  response=$(curl -s -X POST "https://discuss.elastic.co/admin/plugins/explorer/queries/36/run" \
    -H "Content-Type: multipart/form-data;" \
    -H "Api-Key: $DISCUSS_API_KEY" \
    -H "Api-Username: $DISCUSS_API_USERNAME" \
    -F "params={\"page\":\"$page\", \"limit\": \"$PAGE_SIZE\"}" \
    -F "download=true");

  error_type=$(echo "$response" | jq '.error_type')
  if [ "$error_type" != "null" ];
  then
    if [ "$error_type" = "\"rate_limit\"" ];
    then
      wait_time=$(echo "$response" | jq '.extras.wait_seconds')
      log_info "sleeping for $wait_time seconds"
      sleep "$wait_time"
      read_topic "$topic_id" "$bulk_file"
    else
      log_error "Unknown error $error_type. See below."
      log_error "$response"
      return 1
    fi
  else
    result_count=$(echo "$response" | jq '.result_count')
    if ((result_count > 0));
    then
      echo "$response" | jq '.rows[][]'
    else
      log_info "No topics found on page $page"
      return 0
    fi
  fi
}

# Read the list of posts given a topic id. It will retry automatically
# if we get from the API a rate_limit error.
# Usage:
#   read_topic topic_id
# Parameters:
#   topic_id: topic id
#   bulk_file: the file where to append the bulk commands
# Return:
#   the json result from the API
# Example:
# read_topic 12345 bulk.ndjson
read_topic () {
  topic_id=$1
  bulk_file=$2
  log_debug "## Read topic $topic_id"

  url="https://discuss.elastic.co/t/$topic_id.json"
  response=$(curl -s -X GET "$url" \
    -H "Api-Key: $DISCUSS_API_KEY" \
    -H "Api-Username: $DISCUSS_API_USERNAME");
  log_trace "$response"
  # Even though we don't have an error, we might have an error in the json document
  # returned by the API. For example, if the topic has been deleted, the json will
  # contain an error_type field.
  error_type=$(echo "$response" | jq '.error_type')
  if [ "$error_type" != "null" ];
  then
    if [ "$error_type" = "\"rate_limit\"" ];
    then
      wait_time=$(echo "$response" | jq '.extras.wait_seconds')
      log_info "sleeping for $wait_time seconds"
      sleep "$wait_time"
      read_topic "$topic_id" "$bulk_file"
    else
      log_error "Unknown error $error_type. See below."
      log_error "$response"
      return 1
    fi
  else
    log_debug "No error in the response. We continue."
    is_accepted_solution=$(jq '.post_stream.posts[] | select(.accepted_answer).accepted_answer' <<< "$response")
    log_debug "is_accepted_solution: $is_accepted_solution"
    if [ "$is_accepted_solution" != "true" ];
    then
      log_debug "Topic $topic_id has no accepted_answer."
      # Test if the topic has more than 20 elements in the post_stream.posts array
      # If so, we need to fetch the remaining posts
      post_count=$(jq '.post_stream.stream | length' <<< "$response")
      if ((post_count > 20));
      then
        echo "Topic $topic_id has $post_count posts. Fetching all the posts."
        # Append the list of post ids to the url
        url_args="?post_ids[]="
        url_args+=$(echo $response | jq '.post_stream.stream | join("&post_ids[]=")')
        url="https://discuss.elastic.co/t/$topic_id/posts.json?$url_args"
        response=$(curl -s -X GET "$url" \
          -H "Api-Key: $DISCUSS_API_KEY" \
          -H "Api-Username: $DISCUSS_API_USERNAME");

        # Even though we don't have an error, we might have an error in the json document
        # returned by the API. For example, if the topic has been deleted, the json will
        # contain an error_type field.
        error_type=$(echo "$response" | jq '.error_type')
        if [ "$error_type" != "null" ];
        then
          if [ "$error_type" = "\"rate_limit\"" ];
          then
            wait_time=$(echo "$response" | jq '.extras.wait_seconds')
            log_info "sleeping for $wait_time seconds"
            sleep "$wait_time"
            read_topic "$topic_id" "$bulk_file"
          else
            log_error "Unknown error $error_type. See below."
            log_error "$response"
            return 1
          fi
        fi
      else
        log_info "Topic $topic_id is not solved. Skipping."
        return 0
      fi
    fi

    if (("$DEBUG_LEVEL" > 1));
    then  
      # Parse the json and generate the final document we want to have in Elasticsearch
      echo "$response" | jq '.' > "topics/topic-$topic_id.json"
    fi
    
    # We need to double check that the topic is really solved as discuss is not always
    # returning the solved topics only.
    # Update 2023-10-16: This should not cause any issue anymore as it has been fixed in the API
    is_accepted_solution=$(jq '.post_stream.posts[] | select(.accepted_answer)' <<< "$response")
    if [ "$is_accepted_solution" = "null" ];
    then
      log_info "Topic $topic_id is not solved. Skipping."
      return 0
    fi

    echo "$response" | jq -c '{ index : { _id: .id }},
({
  "topic": .id,
  "title": .fancy_title,
  "category_name": (({
"31":"Security Announcements",
"26":"Community Ecosystem",
"6":"Elasticsearch",
"7":"Kibana",
"28":"Beats",
"14":"Logstash",
"91":"Elastic Agent",
"16":"Discussions en français",
"15":"Вопросы на русском языке",
"18":"日本語による質問・議論はこちら",
"24":"Elastic en Español",
"38":"한국어 질문 및 토론",
"46":"中文提问与讨论",
"76":"Elastic em Português - Brasil",
"62":"advent-staging",
"61":"Advent Calendar",
"56":"Elastic Training",
"47":"Community Leaders",
"63":"Google Summer of Code",
"65":"Elastic Stream",
"71":"International Communities",
"86":"Elastic Tips and Common Fixes",
"39":"Elastic Cloud",
"4":"Moderators",
"58":"APM",
"69":"Logs",
"68":"Metrics",
"92":"Profiling",
"75":"Synthetics",
"87":"User Experience",
"80":"Endpoint Security",
"78":"SIEM",
"54":"Elastic Cloud Enterprise (ECE)",
"79":"Elastic Cloud on Kubernetes (ECK)",
"96":"slack-test"
} | with_entries({key: .key, value: .value})) as $lookup
| $lookup[.category_id|tostring]),
  "question": {
    "text": .post_stream.posts[0].cooked,
    "author": {
      "username": .post_stream.posts[0].username,
      "name": .post_stream.posts[0].name,
      "avatar_template": .post_stream.posts[0].avatar_template
    },
    "date": .post_stream.posts[0].created_at,
    "reads": .post_stream.posts[0].reads
  },
  "solution": {
    "text": .post_stream.posts[] | select(.accepted_answer) | .cooked,
    "post_number": .post_stream.posts[] | select(.accepted_answer) | .post_number,
    "author": {
      "username": .post_stream.posts[] | select(.accepted_answer) | .username,
      "name": .post_stream.posts[] | select(.accepted_answer) | .name,
      "avatar_template": .post_stream.posts[] | select(.accepted_answer) | .avatar_template
    },
    "date": .post_stream.posts[] | select(.accepted_answer) | .created_at,
    "reads": .post_stream.posts[] | select(.accepted_answer) | .reads
  },
  "duration": (((.post_stream.posts[] | select(.accepted_answer) | .created_at | split(".") | .[0] + "Z" | fromdate)-(.post_stream.posts[0].created_at | split(".") | .[0] + "Z" | fromdate))/60 | round)
})' >> "$bulk_file"
  fi
}

#if [ "$1" != "" ];
#then
#  read_topic "$1" "bulk-$1.ndjson"
#  # open https://discuss.elastic.co/t/$TOPIC
#  exit 0
#fi
