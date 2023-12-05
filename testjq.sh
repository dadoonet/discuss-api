#jq -n --slurpfile dict categories.json '
#  (INDEX($dict[]; .id) | map_values(.name)) as $d
#  | inputs
#  | .category_name = ($d[.category_id|tostring] // .name)
#' topics/topic-59861.json


jq -c '{ index : { _id: .id }},
{
  "topic": .id,
  "category_name": (({
      "6": "Elasticsearch",
      "7": "Logstash"
   } | with_entries({key: .key, value: .value})) as $lookup
| $lookup[.category_id|tostring]),
  "title": .fancy_title,
  "question": {
    "text": .post_stream.posts[0].cooked,
    "author": {
      "username": .post_stream.posts[0].username,
      "name": .post_stream.posts[0].name,
      "avatar_template": .post_stream.posts[0].avatar_template
    },
    "date": .post_stream.posts[0].created_at,
    "reads": .post_stream.posts[0].reads
  }
}' < "topics/topic-59861.json"


