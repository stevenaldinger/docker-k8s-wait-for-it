# ==================== [START] Global Variable Declaration =================== #
SHELL := /bin/bash
# 'shell' removes newlines
BASE_DIR := $(shell pwd)

UNAME_S := $(shell uname -s)

# exports all variables
export
# ===================== [END] Global Variable Declaration ==================== #

# usage:
# make build dockerhub_user='stevenaldinger' version='latest'
build:
	@docker build -f "${BASE_DIR}/Dockerfile" -t "$$dockerhub_user/docker-k8s-wait-for-it:$$version" "${BASE_DIR}"

# usage:
# make push dockerhub_user='stevenaldinger' version='latest'
push:
	@docker push "$$dockerhub_user/docker-k8s-wait-for-it:$$version"
