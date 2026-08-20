#!/bin/bash
# Fetch latest changes from upstream Kiwi (if ever un-archived)
# For NextKiwi, this also rebases our patches on top

git fetch && git pull --rebase