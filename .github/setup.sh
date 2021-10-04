#!/bin/sh

echo "$IMAGEJA_DEPLOY_KEY" > github_deploy_key
ssh-add github_deploy_key
