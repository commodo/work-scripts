#!/bin/sh
set -e

git log --format="%aN,%ae" | sort | uniq -c | sort -nr
