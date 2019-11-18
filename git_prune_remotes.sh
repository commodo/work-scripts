#!/bin/bash

for remote in $(git remote) ; do
	git remote prune $remote &
done

