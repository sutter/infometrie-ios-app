# Integration

How this system integrates with external/third-party services. The map of every tool around the
project, this one included, lives in the ecosystem memory.

## External services

- Yacast InfoMétrie API, `https://hls-test.yacast.fr`, the only server known (no production URL has been verified, so none is used). Contract: [Swagger](https://hls-test.yacast.fr/swagger/). Local copy with its hash: `Docs/API/openapi.yaml`. Routes and choices: `Docs/API/README.md`.
  - JSON routes: `Infometrie/Core/APIClient.swift`.
  - HLS playlists and segments (`/rest/v1/hls/{id}/{file}`): `Infometrie/Services/HLSRelay.swift`.
- X / Twitter: HTTPS `x.com` / `twitter.com` links in a publication open in the system browser. No request from the app, no token sent.

## Calling conventions

- Private routes need `Authorization: Bearer <JWT>`. `/auth` is for Yacast admins only and is never called.
- Ephemeral URLSession, no cache, 25-second request timeout (30 seconds in the relay), same-origin redirects only.
- Status mapping (`APIError`): 401 / 403 end the session, except on login, where they mean wrong credentials and inactive subscription. 404 means content gone. 409 on login means device quota. Any other code shows a French "try again" message.
- The 409 body has `error` as a boolean. Only `max_devices` and `devices` are decoded. An incomplete body is an explicit error, never an invented quota.
- No automatic retry: the user retries. The feed polls every 30 seconds while the app is active and signed in.
- HLS `margin`: 10 for a sequence, 0 in the podcast, clamped to 0–60.
- `/rest/v1/sequences/{id}/words` answering 404 or 502 means "no timings": the media plays with estimated highlighting.
- When the Swagger changes, compare it with `Docs/API/openapi.yaml`, then update the contract tests (`SwaggerContractTests`) and `Docs/API/README.md`.
- The agent may call the API with `curl`. `/healthz` and `/readiness` need no auth. Private routes need a session of the real account. Never send a device replacement, never revoke a device, and never commit a token or credential: the repository is public.
