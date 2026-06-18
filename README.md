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

## Quick usage

```bash
git clone https://github.com/ibeezhan/pgdocker.git && cd pgdocker
make build          # build the image (Node + ipfs + pg baked in)
make login          # scan the QR once with the Polkadot mobile app

# drop your app in ./apps/<name>, then deploy it:
docker compose run --rm pg pg deploy \
  --dir /work/apps/<name> \
  --buildDir /work/apps/<name> \
  --no-build \
  --signer phone \
  --domain yourappname00 \
  --playground --moddable
```

<details>
<summary>Sample run (deploying MOONLESS MARKET)</summary>

```
 playground deploy · moonlessmarket00 · summit v0.44.1
 ────────────────────────────────────────────────────────────────────────

 frontend

 · build skipped
 ✓ upload + dotns

 ✓ publish to playground

 ✓ deploy complete

 url https://moonlessmarket00.dot.li
 domain moonlessmarket00.dot
 app cid bafybeibkmcjxrv454auauv543l74q2nfsahmjql4dhd4kelg2ajybfgtea
 ipfs cid bafybeiac2jito74alpygsvg6bndt6zuvgz6hvd3bwpurqzsuwdesv2vdbe
 metadata cid bafk2bzacecqdqiyuu6rggphsldd4mjx2q4lcuaggxyvnowyw3g7drjvlt6v3w
```

</details>

> **Domain rule:** the `dev` signer is `NoStatus`, so its label must be
> **base ≥ 9 chars + exactly two trailing digits** (e.g. `myapphere00`).
> Signing with `--signer phone` (your personhood account) lifts that.
> If a deploy fails with *"Bulletin storage … not authorized"*, switch to
> `--signer phone`, or get the account authorized at the event faucet / `pg drip`.

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
| `make deploy-moonless` | clone/pull **MOONLESS MARKET** and deploy it (moddable) |

Flags (override on any deploy target):

| Var | Default | Meaning |
| --- | --- | --- |
| `SIGNER` | `dev` | `dev` (fast, 0–1 taps) or `phone` (your personhood account, 3–4 taps) |
| `DOMAIN` | `moonlessmarket00` | `.dot` label (NoStatus rule: base ≥9 + two trailing digits) |
| `MOD` | `1` | `1` = moddable (`--playground --moddable`); `MOD=0` to opt out |

```bash
make deploy-moonless SIGNER=phone DOMAIN=mygame00 MOD=1
```

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
- **`--env`** — the binary targets whatever network its build is wired to. The
  public release defaults to **`paseo-next-v2`**; event builds (e.g. the
  **Web3 Summit `summit`** chain) target their own — the CLI shows it in the
  deploy header. You normally don't pass `--env`.
- **Bulletin authorization** — uploads go to the Polkadot Bulletin chain. The
  shared `dev` signer's storage pool can lose authorization on busy event
  chains (*"… not authorized"*); switch to `--signer phone` or get the account
  authorized (event faucet / `pg drip`).
- **Moddable / private repos** — `--moddable` publishes the repo URL so others
  can `pg mod` it, and **requires a public GitHub origin**. Private-repo apps
  still deploy fine as non-moddable sites.

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

---

## Acknowledgements

Built at **[Web3 Summit 2026, Berlin](https://web3summit.com/)** 🐻

Huge thanks to the Web3 Summit crew for organizing **`playground.dot`** — the
chill, hands-on space to build and ship decentralized apps to a live network in
minutes — and to the **Parity / [playground-cli](https://github.com/paritytech/playground-cli)
devs** for making the tooling that does the heavy lifting. pgdocker is just a
thin Docker wrapper around their work so you can deploy without touching your
host. ✨

Made by **[Shayan Eskandari](https://shayan.es)** · [shayan.es](https://shayan.es) · [@sbetamc](https://x.com/sbetamc)

## License

MIT — see [LICENSE](LICENSE).
