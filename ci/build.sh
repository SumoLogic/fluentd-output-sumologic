#!/bin/bash

echo "Starting build process in: `pwd`"
set -e

if [! -z "${TRAVIS_TAG}" ]; then
    echo "Building for tag ${TRAVIS_TAG}, modify .gemspec file..."
    sed -i '' "s/0.0.0/${TRAVIS_TAG}/g" ./fluent-plugin-sumologic_output.gemspec
fi

echo "Install bundler..."
bundle install

echo "Run unit tests..."
bundle exec rake

echo "DONE"
