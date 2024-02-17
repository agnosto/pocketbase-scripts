#!/bin/bash

# Read the .env file
source .env

# Parse the arguments
while getopts i:v:t:p: flag; do
	case "${flag}" in
	i) id=${OPTARG} ;;
	v) video_path=${OPTARG} ;;
	t) image_path=${OPTARG} ;;
	p) site=${OPTARG} ;;
	esac
done

# Upload the files and link them to the model
curl -X POST $PUBLIC_POCKETBASE_URL/api/collections/videos/records \
	-H "Authorization:$ADMIN_TOKEN" \
	-F "video=@$video_path" \
	-F "platform=$site" \
	-F "thumbnail=@$image_path" \
	-F "model=$id"

echo "[info] Video uploaded to pocketbase. Continuing online check."
