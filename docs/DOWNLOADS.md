# APK Downloads

HeadLog supports APK distribution through GitHub Releases and an optional Cloudflare Worker.

## Option 1: GitHub Release assets

Each tagged release publishes an APK directly to GitHub Releases.

Best for:

- internal testing
- direct developer sharing
- simple manual distribution

## Option 2: Cloudflare Worker proxy

The Worker in `/headlog` can proxy APK files from a private GitHub repository.

This allows stable URLs such as:

- `/download`
- `/download/stable`
- `/download/latest`
- `/download/v1.1`

## Worker behavior

The Worker:

1. looks up the release through the GitHub API
2. selects the configured APK asset, defaulting to `app-release.apk`
3. downloads the asset from the private release
4. returns it as a downloadable APK response

## Required configuration

In `headlog/wrangler.jsonc`:

- `GITHUB_OWNER`
- `GITHUB_REPO`
- `APK_ASSET_NAME`
- `DEFAULT_TAG`
- `STABLE_TAG`

As a Wrangler secret:

- `GITHUB_TOKEN`

## Local development

Use a local `.dev.vars` file in `headlog/`:

```env
GITHUB_TOKEN=YOUR_GITHUB_TOKEN_HERE
```

Then run:

```bash
cd headlog
npm run dev
```

## Production deploy

```bash
cd headlog
wrangler secret put GITHUB_TOKEN
wrangler deploy
```

## Notes

- the Worker is for binary delivery only
- it does not process or store user headache data
- for private repos, the GitHub token must have read access to the repository releases
- do not commit `.dev.vars`, `.wrangler/`, or local dependency/cache directories

## Stable channel setup

If you want `/download` to serve a stable release instead of the newest GitHub release:

1. publish the normal app release, for example `v1.1`
2. create a separate stable tag and release, for example `v1.1-stable`
3. set `STABLE_TAG` and `DEFAULT_TAG` in `headlog/wrangler.jsonc` to `v1.1-stable`
4. deploy the Worker again

After that:

- `/download` resolves to the stable tag
- `/download/stable` resolves to the stable tag
- `/download/latest` still resolves to the newest GitHub release
