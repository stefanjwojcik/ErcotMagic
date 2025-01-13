#!/bin/bash

# Authenticate using the service account
gcloud auth activate-service-account --key-file=/home/juliauser/.gcloud/key.json

# Execute the Julia command
exec "$@"