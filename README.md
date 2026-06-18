# pgdocker

Run [`paritytech/playground-cli`](https://github.com/paritytech/playground-cli)
(`playground` / `pg`) inside Docker — **deploy apps to the Polkadot Playground
without installing Node, the IPFS (Kubo) CLI, or the playground binary on your
host.** Auth and toolchain persist across runs in named volumes; drop any app
into `./apps/` and deploy it.

The image bakes in:

- **Node 22** (`node:22-bookworm`) — for frontend builds.
- **Kubo (`ipfs`) CLI** — `pg deploy` requires it to pin content to Polkadot
  Bulletin. It's on `PATH` already; you don't install anything.
- **playground-cli** — installed via the official `install.sh`, so `pg` /
  `playground` are ready in the container.

---

## Quickstart

```bash
make build                 # 1. build the image (Node + ipfs + pg baked in)
./pg login                 # 2. scan the QR once with the Polkadot mobile app
# 3. drop an app dir into ./apps/ , then:
./pg deploy --dir /work/apps/<your-app> --buildDir /work/apps/<your-app> \
            --no-build --signer dev --suri //Alice
# ...or use the Makefile helper:
make deploy APP=<your-app>
```

That's it. No host installs beyond Docker.

---

## The `./pg` wrapper

`./pg` proxies straight into the container — anything you'd type after
`playground`/`pg` works:

```bash
./pg --help
./pg login
./pg deploy --dir /work/apps/myapp --buildDir /work/apps/myapp --no-build \
            --signer dev --suri //Alice
```

Under the hood it runs `docker compose run --rm pg pg "$@"` from the repo dir,
so it works no matter where you invoke it from.

## Makefile targets

| Target | What it does |
| --- | --- |
| `make build` | `docker compose build` |
| `make login` | interactive `pg login` (QR scan, persists) |
| `make shell` | interactive `bash` inside the container |
| `make deploy APP=<dir>` | deploy `./apps/<dir>` with dev signer + `--no-build` |
| `make deploy APP=<dir> FLAGS='…'` | same, plus extra flags passed to `pg deploy` |
| `make deploy-moonless` | clone/pull **MOONLESS MARKET** and deploy it |

---

## Login: QR + TTY (one time)

`pg login` prints a QR code you scan with the **Polkadot mobile app**. This
needs an **interactive TTY**, which is why the compose service sets
`stdin_open: true` + `tty: true`. Run it via:

```bash
./pg login          # or: make login
```

The session and keys are written under `~/.polkadot-apps/` **inside the
container**, which is a **named volume** — so you log in **once** and it
persists across `docker compose run` invocations and rebuilds.

> `pg login --yes` skips the QR (installs dependencies, creates **no**
> session). The image already runs this at build time to pre-bake deps; for an
> actual signing session you still need the QR scan above.

## Persistence (named volumes)

Two named volumes keep state across runs:

| Volume | Mounted at | Holds |
| --- | --- | --- |
| `polkadot-bin` | `/root/.polkadot` | the `pg` binary + toolchain |
| `polkadot-apps` | `/root/.polkadot-apps` | auth/session + keys from `pg login` |

On the **first** run Docker seeds these (empty) named volumes from the image
contents baked at build time, then reuses them afterwards. Your `./apps`
directory is a normal bind mount, so apps live on the host.

## The IPFS (Kubo) requirement

`pg deploy` uploads to Polkadot Bulletin via IPFS and **requires the `ipfs`
(Kubo) CLI on `PATH`**. pgdocker downloads the official Kubo release for your
architecture (`amd64`/`arm64`) at build time and installs it to
`/usr/local/bin/ipfs` — already satisfied, nothing to do.

## Deploying: `--env`, signer, and the summit caveat

- **Dev signer** — `--signer dev --suri //Alice` uses a fast development signer
  (0–1 phone taps), ideal for testing. Drop these flags (use `--signer phone`)
  for a real phone-signed deploy.
- **`--no-build`** — skip the frontend build. Use it for static / single-file
  sites; point `--buildDir` at the directory that already contains the built
  files (often the app dir itself).
- **`--env`** — defaults to **`paseo-next-v2`**, the only fully-wired public
  environment. **`summit` is not supported here**: it needs a custom build, so
  it's out of scope for this generic setup — use `paseo-next-v2`.
- **Private-repo apps** deploy fine, but as **non-moddable** sites (no public
  source to remix from).

## Deploy any app

```bash
# 1. put your app in ./apps/<name>/  (a frontend project, or a static dir)
# 2. deploy it:
make deploy APP=<name>
# equivalently:
./pg deploy --dir /work/apps/<name> --buildDir /work/apps/<name> \
            --no-build --signer dev --suri //Alice
```

For a frontend that needs building, drop `--no-build` (and adjust `--buildDir`,
default `dist/`) so `pg` runs the build first — Node is in the image.

`pg deploy-all --manifest apps.json` batch-deploys multiple apps; mount the
manifest under `/work/apps` and call it via `./pg deploy-all --manifest …`.

---

## Deploy MOONLESS MARKET

[`ibeezhan/moonless-market`](https://github.com/ibeezhan/moonless-market) is a
single-file `index.html` game. The Makefile clones (or pulls) it into
`./apps/moonless-market` and deploys it as a static site:

```bash
make build            # once
make login            # once (scan QR)
make deploy-moonless
```

Equivalent explicit commands:

```bash
git clone git@github.com:ibeezhan/moonless-market.git apps/moonless-market
./pg deploy --dir /work/apps/moonless-market \
            --buildDir /work/apps/moonless-market \
            --no-build --signer dev --suri //Alice
```

> The moonless-market repo also ships its **own** self-contained `deploy/`
> helper (Docker + compose wired to that repo). pgdocker is the **generic**
> alternative for deploying *any* app.
