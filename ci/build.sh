#!/bin/sh

echo "Starting build process in: `pwd`"
set -e

VERSION="${TRAVIS_TAG:=0.0.0}"
echo "Building for tag $VERSION, modify .gemspec file..."
sed -i.bak "s/0.0.0/$VERSION/g" ./fluent-plugin-sumologic_output.gemspec
rm -f ./fluent-plugin-sumologic_output.gemspec.bak

echo "Install bundler..."
bundle install

echo "Run unit tests..."
bundle exec rake

echo "DONE"
