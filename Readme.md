# Intercom Webhook Extra Winmail.dat
![](/docs/screenshot.png)

- This is [Intercom webhook](https://docs.intercom.io/integrations/webhooks) processing code to 
   - automatically extra winmail.dat files that end up in the Intercom 
   - and adds links to the extracted files as a note in the conversation
- Manual extract of winmail.dat files can be done via
   - Online services e.g. https://www.winmaildat.com/
   - 3rd party tools e.g. https://github.com/verdammelt/tnef , https://itunes.apple.com/us/app/winmail-dat-viewer-letter-opener-9/id411897373?mt=12
- This webhook helps automate the process
- This setup just uploads files to a public directory that hosts this webhook processing code. 

## Setup - Environment Variable Configuration
- lists all variables needed for this script to work
- `TOKEN`
	- A standard access token should be fine here
	- Apply for an access token  https://app.intercom.io/developers/_
	- Read more about access tokens https://developers.intercom.com/reference#personal-access-tokens-1 
- `bot_admin_id`
	- the ID of the admin that adds the note to the conversation
- `SERVER_URL`
    - public server URL that is used when linking attachments: e.g. `http://intercomwebhookprocessing.yourdomain.com/`
- `UPLOAD_DIRECTORY`
    - the upload directory relative to the root of the app e.g. `public`
    - the server that runs will allow all files in the `public` folder to be readable so a file at APP_PATH/public/test.txt will be readable at `http://intercomwebhookprocessing.yourdomain.com/test.txt`
- For development just rename `.env.sample` to `.env` and modify values appropriately
- Install [tnef](https://github.com/verdammelt/tnef) on server that will run the webhook code

## Running this locally

```
gem install bundler # install bundler
bundle install      # install dependencies
ruby app.rb         # run the code
ngrok http 4567     # uses https://ngrok.com/ to give you a public URL to your local code to process the webhooks
```

- Create a new webhook in the [Intercom Developer Hub](https://app.intercom.io/developers/_) > Webhooks page
- Listen on the following notification: 
   - "New message from a user or lead" / `conversation.user.created`
   - "Reply from a user or lead" / `conversation.user.replied` 
   - "Reply from your teammates" / `conversation.admin.replied`   
- In webhook URL specify the ngrok URL

