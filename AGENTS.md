# Agent Instructions

This file provides instructions for AI agents working on this Ruby gem repository.

## Project Overview

- **Language**: Ruby (>= 2.0)
- **Package Manager**: Bundler (via `Gemfile` / `gemspec`)
- **Testing**: RSpec
- **Linting**: RuboCop
- **Build**: `gem build`
- **CI**: GitHub Actions (`.github/workflows/ruby.yml`)

### Project Structure

```
lib/
  hightouch.rb                          # Top-level require entry point
  hightouch/
    analytics.rb                        # Main Analytics class
    analytics/
      backoff_policy.rb                 # Exponential backoff for retries
      client.rb                         # Core client implementation
      defaults.rb                       # Default configuration values
      field_parser.rb                   # Validates and parses message fields
      logging.rb                        # Logger configuration
      message_batch.rb                  # Batches messages for transport
      response.rb                       # HTTP response wrapper
      test_queue.rb                     # In-memory queue for testing
      transport.rb                      # HTTP transport layer
      utils.rb                          # Shared utility methods
      version.rb                        # VERSION constant
      worker.rb                         # Background worker for async sends

spec/
  spec_helper.rb                        # Test setup and shared fixtures
  hightouch/
    analytics_spec.rb                   # Integration-level specs
    analytics/
      backoff_policy_spec.rb
      client_spec.rb
      message_batch_spec.rb
      response_spec.rb
      test_queue_spec.rb
      transport_spec.rb
      worker_spec.rb
  isolated/                             # Isolated tests for JSON library compat
    json_example.rb                     # Shared example for JSON tests
    with_oj.rb                          # Tests with Oj gem
    with_active_support.rb              # Tests with ActiveSupport
    with_active_support_and_oj.rb       # Tests with both

bin/
  analytics                             # CLI executable for manual testing

.buildscript/
  e2e.sh                                # End-to-end test script (optional, requires $RUN_E2E_TESTS)
```

### Key Files

- **`events-sdk-ruby.gemspec`** — Gem specification with metadata and dependencies
- **`Gemfile`** — Points to the gemspec (`gemspec` directive)
- **`Rakefile`** — Defines default Rake tasks: RSpec tests, isolated specs, and RuboCop
- **`Makefile`** — Convenience targets: `bootstrap`, `dependencies`, `check`, `build`, `install`
- **`lib/hightouch/analytics/version.rb`** — Single source of truth for the gem version

---

## Updating Dependencies

### 1. Pre-flight Checks

```bash
# Check Ruby version
ruby --version

# Ensure Bundler is installed
bundler --version

# Ensure you're at the repository root
pwd  # Should be: /path/to/events-sdk-ruby
```

### 2. Establish Test Baseline

```bash
# Install dependencies
bundle install

# Run all tests, isolated specs, and RuboCop (the default Rake task)
bundle exec rake
```

Record the number of passing tests and any pre-existing failures before making changes. This ensures you can verify nothing new broke after upgrading.

### 3. Check for Security Advisories

```bash
# Install bundler-audit if not already present
gem install bundler-audit

# Update the advisory database and run audit
bundle-audit check --update
```

Review any flagged CVEs. If a vulnerable gem has a patched version within the current semver constraint, `bundle update <gem>` may resolve it automatically.

### 4. Check Outdated Packages

```bash
bundle outdated
```

This shows:
- **Current**: Installed version
- **Latest**: Newest available version
- **Requested**: Version constraint from gemspec / Gemfile

### 5. Upgrade Dependencies

#### Option A: Safe Updates (within semver range)

```bash
# Update all gems to the latest within their current constraints
bundle update

# Update a specific gem
bundle update <gem-name>
```

#### Option B: Major Version Updates

For major version bumps, edit the version constraint in `events-sdk-ruby.gemspec`:

```ruby
# Example: bump rspec from ~> 3.0 to ~> 4.0
spec.add_development_dependency 'rspec', '~> 4.0'
```

Then reinstall:

```bash
rm -f Gemfile.lock
bundle install
```

#### Option C: Interactive Updates (recommended for reviewing all changes)

Use `bundle outdated` to review, then selectively update:

```bash
# See what's outdated
bundle outdated

# Update specific gems you want to bump
bundle update rspec rubocop rake

# Or update everything at once
bundle update
```

### 6. Rebuild and Test

```bash
# Run the full test suite (specs + isolated tests + RuboCop)
bundle exec rake

# Optionally build the gem to verify packaging
gem build events-sdk-ruby.gemspec

# Optionally run RuboCop separately
bundle exec rubocop lib/ spec/
```

Compare test results to your baseline. Fix any failures before proceeding.

### 7. Verify CI Would Pass

CI runs on Ruby versions 2.4, 2.5, 2.6, 2.7, 3.0, 3.1, and 3.2. The CI workflow steps are:

```bash
bundle install       # via bundler-cache in CI
bundle exec rake     # runs RSpec + isolated specs + RuboCop
```

If you have `rbenv` or `rvm` available, test across multiple Ruby versions:

```bash
rbenv shell 2.7.8 && bundle install && bundle exec rake
rbenv shell 3.0.7 && bundle install && bundle exec rake
rbenv shell 3.2.3 && bundle install && bundle exec rake
```

---

## CI/CD

### Test Workflow (`.github/workflows/ruby.yml`)

- **Trigger**: Push to `main`, pull requests targeting `main`
- **Matrix**: Ruby 2.4, 2.5, 2.6, 2.7, 3.0, 3.1, 3.2
- **Steps**: `bundle install` (with caching), `bundle exec rake`

### Gem Publish Workflow (`.github/workflows/gem-push.yml`)

- **Trigger**: GitHub Release published
- **Steps**: Build gem, push to RubyGems.org, notify Slack
- **Secrets required**: `RUBYGEMS_AUTH_TOKEN`, `SLACK_BOT_TOKEN`, `SLACK_RELEASE_CHANNEL_ID`

---

## Rake Tasks

The default `bundle exec rake` runs all of the following in order:

1. **`:spec`** — RSpec tests matching `spec/hightouch/**/*_spec.rb`
2. **Isolated tests** — Each file in `spec/isolated/` runs as a separate Rake task (testing JSON library compatibility in isolated processes)
3. **`:rubocop`** — RuboCop lint (only if RuboCop >= 1.30.0)

Run individual tasks:

```bash
# Only RSpec tests
bundle exec rake spec

# Only RuboCop
bundle exec rubocop

# A specific spec file
bundle exec rspec spec/hightouch/analytics/client_spec.rb

# A specific isolated test
bundle exec rake spec/isolated/with_oj.rb
```

---

## Version Bumping

### Semantic Versioning

- **PATCH** (0.0.2 → 0.0.3): Bug fixes, dependency updates, no new features
- **MINOR** (0.0.2 → 0.1.0): New backwards-compatible features
- **MAJOR** (0.0.2 → 1.0.0): Breaking API changes

Dependency updates are typically **PATCH** bumps.

### Files to Update

1. **`lib/hightouch/analytics/version.rb`** — The `VERSION` constant is the single source of truth:

```ruby
module Hightouch
  class Analytics
    VERSION = '0.0.3'
  end
end
```

2. **`events-sdk-ruby.gemspec`** — Reads `VERSION` automatically via `Hightouch::Analytics::VERSION`

No other files need version changes.

---

## Publishing to RubyGems

Publishing is automated via GitHub Actions when a GitHub Release is created.

### Release Process

1. Update `VERSION` in `lib/hightouch/analytics/version.rb`
2. Commit and push to `main`
3. Create a GitHub Release (this triggers `.github/workflows/gem-push.yml`)
4. The workflow builds and pushes the gem to RubyGems.org

---

## Common Issues

### RuboCop Version Warnings

The `.rubocop.yml` uses the old `Naming/PredicateName` cop name which has been renamed to `Naming/PredicatePrefix`. RuboCop handles this automatically with a warning but the config file should eventually be updated.

### Bundler Permission Errors

If you see `Gem::FilePermissionError` when running `bundle install`, use a local path:

```bash
bundle config set --local path 'vendor/bundle'
bundle install
```

Or prefix with `sudo` for system-wide installation (not recommended for development).

### ActiveSupport Compatibility

The gemspec pins `activesupport` to `~> 5.2.0`. If upgrading, be aware this is a development dependency used only in specs for `ActiveSupport::TimeWithZone` testing. Major version bumps may require spec updates.

### Oj Gem (C Extension)

The `oj` gem (`~> 3.6.2`) requires native compilation. Ensure you have build tools installed:

```bash
# Ubuntu/Debian
sudo apt-get install build-essential ruby-dev

# macOS
xcode-select --install
```

The `oj` gem is excluded on JRuby (`RUBY_PLATFORM != 'java'`).

---

## Quick Reference

| Task | Command |
|------|---------|
| Install dependencies | `bundle install` |
| Run all tests + lint | `bundle exec rake` |
| Run RSpec only | `bundle exec rake spec` |
| Run specific spec | `bundle exec rspec spec/hightouch/analytics/client_spec.rb` |
| Run RuboCop | `bundle exec rubocop` |
| Auto-fix RuboCop | `bundle exec rubocop -a` |
| Build gem | `gem build events-sdk-ruby.gemspec` |
| Install gem locally | `gem install events-sdk-ruby-*.gem` |
| Check outdated gems | `bundle outdated` |
| Security audit | `bundle-audit check --update` |
| Update all gems | `bundle update` |
| Update specific gem | `bundle update <gem-name>` |
