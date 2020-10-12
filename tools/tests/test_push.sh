#!/usr/bin/env bash

# Some doc
# https://firebase.google.com/docs/cloud-messaging/android/first-message
# http://bulkpush.com/pushnotification/guidedetail/s-4/android-gcm-api-configuration
# http://www.feelzdroid.com/2016/02/android-google-cloud-messaging-push-notifications-gcm-tutorial.html

# Ask for parameter
read -p "Enter the server API key: " SERVER_KEY

echo
echo "Check validity of API key, InvalidRegistration error is OK"
# https://developers.google.com/cloud-messaging/http

curl -H "Authorization: key=$SERVER_KEY" \
     -H Content-Type:"application/json" \
     -d "{\"registration_ids\":[\"ABC\"]}" \
     -s \
     https://fcm.googleapis.com/fcm/send \
     | python -m json.tool

# should obtain something like this:
# {"multicast_id":5978845027639121780,"success":0,"failure":1,"canonical_ids":0,"results":[{"error":"InvalidRegistration"}]}

read -p "Enter the FCM token: " FCM_TOKEN

# content of the notification
DATA='{"event_id":"$THIS_IS_A_FAKE_EVENT_ID"}'

echo
echo
echo "Send a push, you should see success:1..."

curl -H "Authorization: key=$SERVER_KEY" \
     -H Content-Type:"application/json" \
     -d "{ \"data\" : $DATA, \"to\":\"$FCM_TOKEN\" }" \
     -s \
     https://fcm.googleapis.com/fcm/send \
     | python -m json.tool

echo
echo

# should obtain something like this:
# {"multicast_id":7967233883611790812,"success":1,"failure":0,"canonical_ids":0,"results":[{"message_id":"0:1472636210339069%84ac25d9f9fd7ecd"}]}

