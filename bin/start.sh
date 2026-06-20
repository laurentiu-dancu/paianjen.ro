#!/bin/sh
set -e

echo "Starting paianjen with DATABASE_URL=$DATABASE_URL"
exec bin/paianjen start
