# Contributing

## How to release

1. Create a pull request named `chore: release x.y.z` with the following changes:

   - Set `gem.version` to `"x.y.z"` in [fluent-plugin-sumologic_output.gemspec](fluent-plugin-sumologic_output.gemspec).
   - Add new version to [CHANGELOG.md](./CHANGELOG.md).

   Example PR: [#92](https://github.com/SumoLogic/fluentd-output-sumologic/pull/92)

2. Create and push the release tag:

   ```bash
   git checkout main
   git pull
   export VERSION=x.y.z
   git tag -a "${VERSION}" -m "Release ${VERSION}"
   git push origin "${VERSION}"
   ```

   This will trigger the GitHub Actions [publish](./.github/workflows/publish.yaml) action to pubilsh the gem in Ruby Gems.

3. Go to https://github.com/SumoLogic/fluentd-output-sumologic/releases and create a new release for the tag.
   Copy the changes from Changelog and publish the release.
