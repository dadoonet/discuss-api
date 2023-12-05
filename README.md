# Discuss Elastic exporter

TODO Description

## Prerequisites

You need to have a [discuss API Key](https://discuss.elastic.co/admin/api/keys) and the username which will call the API.
And you must enter it in a `.env` file or as a `DISCUSS_API_KEY` system property before starting the script.

Here is an example of the `.env` file:

```txt
# Discuss API Key. Generate it from: https://discuss.elastic.co/admin/api/keys
DISCUSS_API_KEY=YOUR_KEY
# Discuss API Username. It needs to be a valid username. The one the key belongs to.
DISCUSS_API_USERNAME=dadoonet
```

## Start the script

Run:

```sh
./export-topics.sh
```

This script does:

* call https://discuss.elastic.co/search.json?expanded=true&page=1&q=status%3Asolved%20%23elastic-stack%3Aelasticsearch%20order%3Alatest
* iterate over the topic_list.topics array to fetch the documents.
* For each topic, get all the posts (https://discuss.elastic.co/t/343007.json)
* iterate over the post_stream.posts array

We generate a document which looks like this:

```json
{
  "topic": 343309,
//  "url": "https://discuss.elastic.co/t/343309",
  "title": "&ldquo;Failed to decode response&rdquo; error from Java Client 8.8.0",
  "question": {
    "text": "Full question here",
    "author": {
      "username": "foobar",
      "name": "Mr Foo",
      "avatar_template": "https://discuss.elastic.co/user_avatar/discuss.elastic.co/foobar/{size}/63832_2.png"
    },
    "date": "2023-09-19T03:55:55.006Z",
    "reads": 10
  },
  "solution": {
    "text": "Full answer here",
    "post_number": 8,
//    "url": "https://discuss.elastic.co/t/343309/8",
    "author": {
      "username": "foobar",
      "name": "Mr Foo",
      "avatar_template": "https://discuss.elastic.co/user_avatar/discuss.elastic.co/foobar/{size}/63832_2.png"
    },
    "date": "2023-09-20T00:26:00.375Z",
    "reads": 10
  }
}
```

JSON From discuss:


JQ code:

```js
{ index : { _id: .id }},
({
  "topic": .id,
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
})
```
