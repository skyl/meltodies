#!/bin/bash

# do not run this without outstanding changes!

git checkout master
git pull
git checkout gh-pages
git pull
git merge --no-edit master
bower install
./update_songs.py
git add .
git commit -m "update gh-pages"
git push
git checkout master
# angulartics gets blown away, for some reason
# @pdh wth?
rm -rf lib/angulartics/
bower install
./update_songs.py
