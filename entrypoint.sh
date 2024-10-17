#!/usr/bin/env bash

set -x

# Compulsory env vars
: "${USER_ID:?Environment variable must be set}"
: "${GROUP_ID:?Environment variable must be set}"
: "${USER_NAME:?Environment variable must be set}"

groupadd -g "${GROUP_ID}" "${USER_NAME}"
adduser --uid "${USER_ID}" --gid "${GROUP_ID}" --shell /bin/bash --disabled-password --gecos "" "${USER_NAME}"
chmod a+rw /var/run/docker.sock
echo "User set up done, sleeping now!..."
sleep infinity
