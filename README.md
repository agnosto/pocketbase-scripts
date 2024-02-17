# pocketbase-scripts

A collection of shell scripts used with my [fansly-recorder](https://github.com/agnosto/fansly-recorder) and [ctbrec](https://mastodon.cloud/@ctbrec) to upload recorded stream VODs to a pocketbase instance to be used for viewing on a selfhosted frontend using something like [tailscale](https://tailscale.com/) to give access on any other device.

⚠ Due to initially being recorded as .ts there may be some issues with VODs not playing in browser, in ctbrec you can go to `settings > recorder > file extension` and change it to mp4 and change the ffmpeg parameters to the following

```
-c copy -movflags use_metadata_tags -map_metadata 0 -timeout 300 -reconnect 300 -reconnect_at_eof 300 -reconnect_streamed 300 -reconnect_delay_max 300 -rtmp_live live
```

For the fansly-recorder, you can change all reference to .ts files to mp4, there might be some other minor tweaks needed, I'll probably a version that records straight to mp4 or edit the script to allow the user to choose a file format to record in.

## Dependencies

- [mt](https://github.com/mutschler/mt) - used to generate contact sheets of VODs
- [discord.sh](https://github.com/fieu/discord.sh) - used to send webhooks that the VOD was uploaded (in theory, didn't actually impliment checking the upload response to see if it was uploaded or not before sending)
- [libnotify](https://gitlab.gnome.org/GNOME/libnotify) (optional) - for desktop notifications when VOD is being processed and uploaded (will have to uncomment the notify-send lines in the upload script.)

## Setup

### Pocketbase

The upload script assumes there are 2 collections in the pocketbase instance, with the corresponding fields
_platform on both collections is kinda redundant ik_

1. models

- id, platform(text), username(text), account_id(text)

2. videos

- id, model(relation), platform(text), video(file, single), thumbnail(file, single)

#### Pocketbase token

1. After logging in to pocketbase dashboard, press `F12` and go to `Network`
2. Click on one of the collections
3. Click one of the requests that show up in the Network tab and go to the Request Headers
4. Copy the value from `Authorization`

### Ctbrec

Using the [ctbrec-upload.sh](./ctbrec-upload.sh) script in ctbrec.

- In ctbrec settings, go to post-processing and press `+` to add a step
- Select `execute a script`
- In the script field add the path to the script ex: `/home/user/Documents/scripts/ctbrec-upload.sh`
- In the parameters field add the following: `${modelName}, $lower(${siteName}), ${absolutePath}`
- Make sure it's enabled by checking the box and after a stream is recorded, it should begin being processed and uploaded

### Fansly recorder

Using the [fansly-upload.sh](./fansly-upload.sh) script with the [fansly-recorder](https://github.com/agnosto/fansly-recorder) script.

#### Requirements

- [Python-dotenv](https://pypi.org/project/python-dotenv/) - `pip install python-dotenv`
- Add the following to the imports:

```python
from dotenv import load_dotenv
```

- Replace the rclone with the following:

```python
load_dotenv()

pb_url = os.getenv("PUBLIC_POCKETBASE_URL")
pb_token = os.getenv("ADMIN_TOKEN")
```

- Change the [uploadRecording](https://github.com/agnosto/fansly-recorder/blob/main/fansly-recorder.py#L159) function to the following:

```python

async def uploadRecording(mp4_filename, contact_sheet_filename, user_Data):
    # Fetch the user record from PocketBase
    url = f'{pb_url}/api/collections/models/records?filter=username="{user_Data["response"][0]["username"]}"'
    headers = {"Authorization": pb_token}

    async with aiohttp.ClientSession() as session:
        async with session.get(url, headers=headers) as response:
            user_record = await response.json()

    # Extract the id from the user record
    user_id = user_record["items"][0]["id"]

    command = f"./fansly-upload.sh -i {user_id} -p fansly -v {mp4_filename} -t {contact_sheet_filename}"
    subprocess.run(command, shell=True, check=True)

    if config.webhooks.enabled:
        webhook_url = config.webhooks.info_webhook
        if webhook_url is not None:
            webhook = DiscordWebhook(url=webhook_url, rate_limit_retry=True)
            mp4_name = os.path.basename(mp4_filename)
            sheet_name = os.path.basename(contact_sheet_filename)
            mention = config.webhooks.webhook_mention

            # create discordembed object
            embed = DiscordEmbed(
                title="Stream Recording Uploaded",
                description=f"Uploaded {mp4_name} with contact sheet {sheet_name}",
                color="03b2f8",
            )
            embed.set_image(url=f"attachment://{sheet_name}")
            embed.set_timestamp()

            # Add message and embed to webhook
            webhook.content = f"{mention} Vod Uploaded"
            webhook.add_file(
                file=open(contact_sheet_filename, "rb"), filename=sheet_name
            )
            webhook.add_embed(embed)

            # Send webhook message
            response = webhook.execute()
            if response.status_code == 200:
                print(f"[info] Sent Discord notification that {mp4_name} was uploaded")
            else:
                print(
                    f"[warning] Failed to send webhook notification: {response.status_code} {response.reason}"
                )

```

- In the [startRecording](https://github.com/agnosto/fansly-recorder/blob/main/fansly-recorder.py#L191) function, add `user_Data` to the uploadRecording function calls

```python
  if config.upload is True and config.mt is True:
    await uploadRecording(mp4_filename, contact_sheet_filename, user_Data)
  elif config.upload is True:
    await uploadRecording(mp4_filename, user_Data)
```
