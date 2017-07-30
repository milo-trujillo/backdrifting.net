#!/usr/bin/env bash

# This script isn't part of the website code, but should be run before
# committing anything to the repo so we don't accidentally post login creds
DIR=$(dirname "$SCRIPT")

sed -i -e 's/^PreviewPassword.*$/PreviewPassword = ""/' $DIR/backdrifting.rb
