# pgdocker — convenience targets around docker compose.
#
#   make build                     build the image
#   make login                     interactive `pg login` (scan QR once)
#   make shell                     interactive bash in the container
#   make deploy APP=<dir>          deploy ./apps/<dir> (dev signer, --no-build)
#   make deploy APP=<dir> FLAGS=.. pass extra flags to `pg deploy`
#   make deploy-moonless           clone/pull + deploy ibeezhan/moonless-market

COMPOSE := docker compose
RUN     := $(COMPOSE) run --rm pg

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
		git clone git@github.com:ibeezhan/moonless-market.git apps/moonless-market; \
	else \
		git -C apps/moonless-market pull; \
	fi
	$(RUN) pg deploy \
		--dir /work/apps/moonless-market \
		--buildDir /work/apps/moonless-market \
		--no-build \
		--signer dev \
		--suri //Alice
