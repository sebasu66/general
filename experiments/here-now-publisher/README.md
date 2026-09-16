# Here.now Publisher Bridge

Small persistent HTTP bridge used by agent environments that cannot directly perform Here.now's signed upload flow.

## Runtime role

The bridge is transport only. It does not host Seven Citadel, own narrative state, or participate in browser gameplay. The fast path is: agent-generated files -> this API -> Here.now publish API / signed object uploads -> existing Here.now site.

`GET /health` checks availability. `POST /publish` accepts a target site, optional Here.now claim token, and files encoded as base64. The service hashes files, requests a Here.now publish, uploads required files in parallel, and finalizes the version.

Set `PUBLISHER_API_KEY` in Render and send it as a Bearer token. Here.now credentials are supplied per request rather than stored in the repository.

The bridge should remain stable; normal Seven Citadel iterations should not require code changes or Git commits to this service.
