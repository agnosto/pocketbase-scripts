#!/bin/bash

source /home/user/Documents/scripts/.env

model_name=$1
site=$2
video_path=$3

#notify-send -a CTBrec -i camera-video "$model_name from $site is being processed and uploaded"
sleep 5

# Generate contact sheet to store in variable
# get directorty of the file

dir=$(dirname "${video_path}")
base=$(basename "${video_path}")

filename="${base%.mp4}.jpg"
contact_sheet="${dir}/${filename}"

'/home/user/Documents/scripts/mt' \
	--columns=4 \
	--numcaps=24 \
	--header-meta \
	--fast \
	--comment=" Archive - $site VODs" \
	--output="${contact_sheet}" \
	"${video_path}"

sleep 5

# Get model id from pocketbase
response=$(curl -X GET "$PUBLIC_POCKETBASE_URL/api/collections/models/records?filter=username=\"$model_name\"")
id=$(echo $response | jq '.items[0].id')

sleep 5

# Upload files to pocketbase
uploaded_file=$(curl -X POST $PUBLIC_POCKETBASE_URL/api/collections/videos/records \
	-H "Authorization:$ADMIN_TOKEN" \
	-F "video=@$video_path" \
	-F "platform=$site" \
	-F "thumbnail=@$contact_sheet" \
	-F "model=$id")

#notify-send -a CTBrec -i camera-video "uploaded file: '$uploaded_file'"
sleep 5

# Use discord.sh to send webhook

'/home/user/Documents/scripts/discord.sh' \
	--webhook-url=$WEBHOOK_URL \
	--text '<@!1234567890> \n Uploaded file: '$base' with  contact sheet: '$filename'' \
	--file "$contact_sheet"
