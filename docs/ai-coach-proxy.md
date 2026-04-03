# AI Coach Backend

The premium `Coach` tab in the iOS app needs a backend. The app should never call OpenAI directly because the API key must stay server-side.

Firebase Functions is a reasonable low-ops choice here, but as of April 3, 2026 Firebase’s docs say production deployment of Cloud Functions requires the Blaze plan. In practice, a small-volume proxy can still stay very cheap because usage is pay-as-you-go with free-tier allowances.

Sources:

- [Firebase Functions getting started](https://firebase.google.com/docs/functions/get-started)
- [Firebase Functions HTTP triggers](https://firebase.google.com/docs/functions/http-events)
- [Firebase Functions config and secrets](https://firebase.google.com/docs/functions/config-env)
- [OpenAI GPT-5.4 model docs](https://developers.openai.com/api/docs/models/gpt-5.4)

## What Was Added

- [firebase.json](/Users/james/Dev/iOS%20Health%20Bridge/firebase.json)
- [functions/package.json](/Users/james/Dev/iOS%20Health%20Bridge/functions/package.json)
- [functions/index.js](/Users/james/Dev/iOS%20Health%20Bridge/functions/index.js)
- [.firebaserc.example](/Users/james/Dev/iOS%20Health%20Bridge/.firebaserc.example)

The function is named `coach` and expects the same request shape already used by the iOS app.

## One-Time Setup

1. Create a Firebase project in the console.
2. Upgrade it to Blaze so Functions can be deployed.
3. The repo now includes [.firebaserc](/Users/james/Dev/iOS%20Health%20Bridge/.firebaserc) pointed at `forma-health-exports`.
4. Install the function dependencies:

```bash
cd "/Users/james/Dev/iOS Health Bridge/functions"
npm install
```

5. Set the OpenAI secret:

```bash
firebase functions:secrets:set OPENAI_API_KEY
```

6. Optionally set a default model parameter:

```bash
firebase functions:params:set OPENAI_MODEL="gpt-5.4"
```

## Local Development

Run the emulator:

```bash
cd "/Users/james/Dev/iOS Health Bridge"
firebase emulators:start --only functions
```

Your local function URL will look like:

```text
http://127.0.0.1:5001/forma-health-exports/europe-west2/coach
```

Use that as `FORMA_AI_PROXY_URL` in the iOS app while developing.

## Deploy

```bash
cd "/Users/james/Dev/iOS Health Bridge"
firebase deploy --only functions
```

After deploy, Firebase will print the HTTPS endpoint for `coach`.

Set that value in [Info.plist](/Users/james/Dev/iOS%20Health%20Bridge/iOS%20Health%20Bridge/Info.plist):

- `FORMA_AI_PROXY_URL`
- `FORMA_AI_MODEL` if you want to override the backend default

Current deployed endpoint:

- `https://coach-pdyq54lgpa-nw.a.run.app`

## Request Contract

The app sends:

```json
{
  "model": "gpt-5.4",
  "messages": [
    { "role": "user", "content": "How does my recovery look?" }
  ],
  "context": {
    "generatedAt": "2026-04-03T12:00:00Z",
    "measurementSystem": "metric",
    "disclaimer": "Health coaching only. Never diagnose, prescribe, or present medical advice.",
    "weeklyMetrics": [],
    "monthlyMetrics": [],
    "weeklyInsights": [],
    "monthlyInsights": []
  }
}
```

The function returns:

```json
{
  "reply": "Your recovery looks stable overall...",
  "model": "gpt-5.4"
}
```

## Security Notes

This implementation is enough for development and small private testing, but it is not hardened yet.

- The OpenAI secret stays on the server.
- The function is still a public HTTPS endpoint unless you add auth.
- For production, add Firebase Auth or App Check before you ship this broadly.
- Add budget alerts on the Firebase or Google Cloud side before exposing the endpoint.
