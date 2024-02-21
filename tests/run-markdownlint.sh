#!/bin/bash

# please install node.js runtime for your OS ( https://nodejs.org/ )
# then run `npm install -g markdownlint-cli` (maybe with sudo)

npx markdownlint-cli -p .gitignore .
