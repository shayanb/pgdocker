# pgdocker — convenience targets around docker compose.
#
#   make build                     build the image
#   make login                     interactive `pg login` (scan QR once)
#   make shell                     interactive bash in the container
#   make deploy APP=<dir>          deploy ./apps/<dir> (dev signer, --no-build)
#   make deploy APP=<dir> FLAGS=.. pass extra flags to `pg deploy`
#   make deploy-moonless           clone/pull + deploy ibeezhan/moonless-market (moddable)
#   make deploy-moonless MOD=0     deploy non-moddable (private/no public origin)

COMPOSE := docker compose
RUN     := $(COMPOSE) run --rm pg

# Moddable deploys publish the public repo URL so others can `pg mod` it.
# Requires the app's git origin to be a PUBLIC GitHub repo. On (default).
MOD ?= 1
MODFLAGS := $(if $(filter 1 yes true on,$(MOD)),--playground --moddable,)

# Domain for moonless. The `dev` signer is NoStatus, so the label must be
# NoStatus-compatible: base >= 9 chars + exactly two trailing digits.
# Override if taken: make deploy-moonless DOMAIN=moonlessmkt42
DOMAIN ?= moonlessmarket00

.PHONY: build login shell deploy deploy-moonless

build:
	$(COMPOSE) build

login:
	$(RUN) pg login

shell:
	$(RUN) bash

# Deploy an app dropped in ./apps. Single-file/static apps work out of the box
# with --no-build (buildDir points at the app dir). Override or extend via FLAGS=.
deploy:
	@test -n "$(APP)" || { echo "Usage: make deploy APP=<dir> [FLAGS='--env paseo-next-v2']"; exit 1; }
	$(RUN) pg deploy \
		--dir /work/apps/$(APP) \
		--buildDir /work/apps/$(APP) \
		--no-build \
		--signer dev \
		--suri //Alice \
		$(FLAGS)

# One-shot for MOONLESS MARKET: fetch (or update) the repo into ./apps, then
# deploy its single index.html as a static site with the dev signer.
deploy-moonless:
	@if [ ! -d apps/moonless-market ]; then \
		git clone https://github.com/ibeezhan/moonless-market.git apps/moonless-market; \
	else \
		git -C apps/moonless-market pull; \
	fi
	@# moddable requires origin = public GitHub https URL (fetched via codeload)
	git -C apps/moonless-market remote set-url origin https://github.com/ibeezhan/moonless-market.git
	$(RUN) pg deploy \
		--dir /work/apps/moonless-market \
		--buildDir /work/apps/moonless-market \
		--no-build \
		--signer dev \
		--suri //Alice \
		--domain $(DOMAIN) \
		$(MODFLAGS)
