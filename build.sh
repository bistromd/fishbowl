#!/usr/bin/env bash

git add -A .
git commit -m "Add More Code"

rm fishbowl-1.0.0.gem
gem uninstall fishbowl

gem build fishbowl.gemspec
gem install fishbowl-1.0.0.gem

ruby fishbowl_test.rb