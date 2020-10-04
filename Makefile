.DEFAULT_GOAL := default
SHELL = /usr/bin/env bash -eo pipefail



MKFILE_DIR = $(abspath $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
LOCAL_DIR = $(MKFILE_DIR)/.local

BIN_DIR = $(LOCAL_DIR)/bin
LIB_DIR = $(LOCAL_DIR)/lib
TEMP_DIR = $(LOCAL_DIR)/tmp
DATA_DIR = $(LOCAL_DIR)/data
LOG_DIR = $(LOCAL_DIR)/logs
STACK_DIR = $(MKFILE_DIR)/stack

APP_NODE_MODULE_DIRS = $(foreach dir, client server, $(subst %,$(dir),$(MKFILE_DIR)/app/%/node_modules))



NODEJS_VERSION ?= 12.16.3
NPM_VERSION ?= 6.14.4
MONGODB_VERSION ?= 4.2.6
REACT_APP_VERSION = 3.4.1



PLATFORM := $(shell if echo $$OSTYPE | grep -q darwin; then echo darwin; else echo linux; fi)


NODEJS_URL = https://nodejs.org/dist/v$(NODEJS_VERSION)/node-v$(NODEJS_VERSION)-$(PLATFORM)-x64.tar.gz
NODEJS_ARTIFACT = $(TEMP_DIR)/node-v$(NODEJS_VERSION)-$(PLATFORM)-x64.tar.gz
NODEJS_ARCHIVE = $(patsubst %.tar.gz,%,$(notdir $(NODEJS_ARTIFACT)))
NODEJS_BIN = $(BIN_DIR)/node
NPM_BIN = $(BIN_DIR)/npm
NODEJS_SHA256 ?= $(shell cat $(STACK_DIR)/versions/nodejs.256.sums | grep v$(NODEJS_VERSION)-$(PLATFORM)-x64 | awk '{ print $$ 2 }')


ifeq ($(PLATFORM), darwin)
MONGODB_URL = https://fastdl.mongodb.org/osx/mongodb-macos-x86_64-$(MONGODB_VERSION).tgz
else ifeq ($(PLATFORM), linux)
# NOTE: hard-coded Debian version. Others can be found here: https://www.mongodb.com/download-center/community
MONGODB_URL = https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-debian10-$(MONGODB_VERSION).tgz
else
	fail 'Unknown platform. No condition met'
endif
MONGODB_ARTIFACT = $(TEMP_DIR)/mongodb-$(PLATFORM)-$(MONGODB_VERSION).tar.gz
MONGODB_ARCHIVE = $(patsubst %.tar.gz,%,$(notdir $(MONGODB_ARTIFACT)))
MONGODB_BIN = $(BIN_DIR)/mongod
MONGODB_SHA256 ?= $(shell cat $(STACK_DIR)/versions/mongodb.256.sums | grep $(PLATFORM)-x86_64-$(MONGODB_VERSION) | awk '{ print $$ 2 }')



SERVER_PUBLIC_URL ?= http://localhost:3000
CLIENT_BUILD_PATH ?= $(MKFILE_DIR)/app/server/src/public




default: all

all: install-stack install-deps



install-stack: node npm mongod


install-deps: $(APP_NODE_MODULE_DIRS)



.PHONY: run-db
run-db: export PATH := $(BIN_DIR):$(PATH)
run-db: | $(LOG_DIR)/ $(DATA_DIR)/
	mkdir -p $(DATA_DIR)/db
	mongod --config $(STACK_DIR)/local.mongod.conf


.PHONY: run-local
run-local: export PATH := $(BIN_DIR):$(PATH)
run-local: build
	cd $(MKFILE_DIR)/app/server \
	&& npm run start:dev


.PHONY: test
test: export PATH := $(BIN_DIR):$(PATH)
test: randomString = $(shell LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 32 | head -n 1)
test:
	cd $(MKFILE_DIR)/app/client \
	&& npm run test
	cd $(MKFILE_DIR)/app/server \
	&& \
		PORT=3002 \
		MONGODB_URL=mongodb://localhost:27017/$(randomString) \
		JWT_SECRET=$(randomString) \
	 	npm run test


.PHONY: test-client-local
test-client-local: export PATH := $(BIN_DIR):$(PATH)
test-client-local:
	cd $(MKFILE_DIR)/app/client \
	&& npm run test:dev


.PHONY: build
build: export PATH := $(BIN_DIR):$(PATH)
build:
	rm -rf $(CLIENT_BUILD_PATH)
	cd $(MKFILE_DIR)/app/client \
	&& PUBLIC_URL=$(SERVER_PUBLIC_URL) \
		BUILD_PATH=$(CLIENT_BUILD_PATH) \
		node ./scripts/build.js



.PHONY: clean
clean: clean-stack clean-modules




.PHONY: start
start: export PATH := $(BIN_DIR):$(PATH)
start: SERVER_PUBLIC_URL = http://localhost:3001
start: build
start: | $(DATA_DIR)/ $(LOG_DIR)/
	mkdir -p $(DATA_DIR)/db

	(exec mongod \
		--port 27017 \
		--bind_ip localhost \
		--logpath /dev/stdout \
		--dbpath $(DATA_DIR)/db \
	) & PIDS[1]=$$!; \
	\
	(PORT=3001 \
	MONGODB_URL=mongodb://localhost:27017/todo-app \
	JWT_SECRET=myjwtsecret \
	exec node $(MKFILE_DIR)/app/server/src/index.js \
	) & PIDS[2]=$$!; \
	\
	for PID in $${PIDS[*]}; do wait $${PID}; done;





$(LOCAL_DIR)/%/:
	mkdir -p $(@)


.PHONY: node
node: $(NODEJS_BIN)
$(NODEJS_BIN): | $(NODEJS_ARTIFACT) $(BIN_DIR)/
	@ [ $$(openssl dgst -sha256 "$(NODEJS_ARTIFACT)" | awk '{ print $$ 2 }') == $(NODEJS_SHA256) ] || ( echo "Invalid SHA256." && rm $(NODEJS_ARTIFACT) && exit 1 )
	tar \
		--extract \
		--verbose \
		--strip-components 2 \
		--directory "$(BIN_DIR)" \
		--file "$(NODEJS_ARTIFACT)" \
		$(NODEJS_ARCHIVE)/bin/node
	chmod +x "$@"

$(NODEJS_ARTIFACT): | $(TEMP_DIR)/
	curl \
		--silent --show-error \
		--location \
		$(NODEJS_URL) \
		> $(NODEJS_ARTIFACT)

.PHONY: npm
npm: $(NPM_BIN)
npm: export PATH := $(BIN_DIR):$(PATH)
$(NPM_BIN): | $(NODEJS_BIN)
	mkdir -p $(LIB_DIR)
	tar \
		--extract \
		--verbose \
		--strip-components 2 \
		--directory "$(LIB_DIR)" \
		--file "$(NODEJS_ARTIFACT)" \
		$(NODEJS_ARCHIVE)/lib/node_modules
	chmod +x $(LIB_DIR)/node_modules/npm/bin/npm-cli.js
	ln -s $(LIB_DIR)/node_modules/npm/bin/npm-cli.js $(NPM_BIN)
	npm install -g npm@$(NPM_VERSION)


.PHONY: mongod
mongod: $(MONGODB_BIN)
$(MONGODB_BIN): | $(MONGODB_ARTIFACT) $(BIN_DIR)/
	@ [ $$(openssl dgst -sha256 "$(MONGODB_ARTIFACT)" | awk '{ print $$ 2 }') == $(MONGODB_SHA256) ] || ( echo "Invalid SHA256." && rm $(MONGODB_ARTIFACT) && exit 1 )
	mkdir -p $(TEMP_DIR)/$(MONGODB_ARCHIVE)
	tar \
		--extract \
		--verbose \
		--strip-components 2 \
		--directory "$(TEMP_DIR)/$(MONGODB_ARCHIVE)" \
		--file "$(MONGODB_ARTIFACT)"
	mv $(TEMP_DIR)/$(MONGODB_ARCHIVE)/mongod "$@"
	chmod +x "$@"
	rm -rf $(TEMP_DIR)/$(MONGODB_ARCHIVE)

$(MONGODB_ARTIFACT): | $(TEMP_DIR)/
	curl \
		--silent --show-error \
		--location \
		$(MONGODB_URL) \
		> $(MONGODB_ARTIFACT)


.PHONY: clean-stack
clean-stack:
	rm -rf \
		$(LOCAL_DIR)



.PHONY: $(APP_NODE_MODULE_DIRS)
$(APP_NODE_MODULE_DIRS): export PATH := $(BIN_DIR):$(PATH)
$(APP_NODE_MODULE_DIRS): $(MKFILE_DIR)/app/%/node_modules:
	cd $(@D) \
	&& npm install

.PHONY: clean-modules
clean-modules:
	for nodeModulesDir in $(APP_NODE_MODULE_DIRS); do \
		rm -rf "$${nodeModulesDir}"; \
	done





.PHONY: update-react-app-template
update-react-app-template: export PATH := $(BIN_DIR):$(PATH)
update-react-app-template:
	rm -rf $(TEMP_DIR)/npm-project-scope
	mkdir -p $(TEMP_DIR)/npm-project-scope
	cd $(TEMP_DIR)/npm-project-scope \
		&& npm install --save-dev react-scripts@$(REACT_APP_VERSION) \
		&& npm init react-app $(TEMP_DIR)/npm-project-scope/cra
	cp \
		$(TEMP_DIR)/npm-project-scope/cra/src/* \
		$(MKFILE_DIR)/app/client/src/
	cp \
		$(TEMP_DIR)/npm-project-scope/cra/public/* \
		$(MKFILE_DIR)/app/client/public/
	cp \
		$(TEMP_DIR)/npm-project-scope/cra/package.json \
		$(MKFILE_DIR)/app/client/
	rm -rf \
		$(MKFILE_DIR)/app/client/src/logo.svg
