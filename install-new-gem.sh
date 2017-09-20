#!/bin/bash

rm -rf wraith*.gem
gem build wraith.gemspec
GEMFILE=`ls wraith*.gem`

echo "Now install $GEMFILE"
gem install $GEMFILE
