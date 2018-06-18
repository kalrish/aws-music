#!/usr/bin/bash


set -ex

cd "$1"
mkdir {.overlayfs,builds}
cd builds
tup init
