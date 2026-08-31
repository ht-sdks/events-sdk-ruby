# Agent Instructions

This file provides guidance for AI agents updating dependencies in this Ruby gem repository.

## Project Overview

- **Language**: Ruby (>= 2.0)
- **Package Manager**: Bundler (via `Gemfile` / `events-sdk-ruby.gemspec`)
- **Testing**: RSpec + isolated specs
- **Linting**: RuboCop
- **Build**: `gem build`
- **CI**: GitHub Actions (`.github/workflows/ruby.yml`) — Ruby 2.4, 2.5, 2.6, 2.7, 3.0, 3.1, 3.2

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

Record the number of passing tests before making changes. This ensures you can verify nothing new broke after upgrading.

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

## Common Issues When Updating Dependencies

### Bundler Permission Errors

If you see `Gem::FilePermissionError` when running `bundle install`, use a local path:

```bash
bundle config set --local path 'vendor/bundle'
bundle install
```

### ActiveSupport Compatibility

The gemspec pins `activesupport` to `~> 5.2.0`. This is a development dependency used only in specs for `ActiveSupport::TimeWithZone` testing. Major version bumps may require spec updates.

### Oj Gem (C Extension)

The `oj` gem (`~> 3.17.6`) requires native compilation and MRI Ruby >= 2.7. Ensure you have build tools installed:

```bash
# Ubuntu/Debian
sudo apt-get install build-essential ruby-dev

# macOS
xcode-select --install
```

The `oj` gem is excluded on JRuby (`RUBY_PLATFORM != 'java'`) and on MRI Ruby < 2.7.

### RuboCop Version Warnings

The `.rubocop.yml` uses the old `Naming/PredicateName` cop name which has been renamed to `Naming/PredicatePrefix`. RuboCop handles this automatically with a warning but the config file should eventually be updated.

---

## Quick Reference

| Task | Command |
|------|---------|
| Install dependencies | `bundle install` |
| Run all tests + lint | `bundle exec rake` |
| Build gem | `gem build events-sdk-ruby.gemspec` |
| Check outdated gems | `bundle outdated` |
| Security audit | `bundle-audit check --update` |
| Update all gems | `bundle update` |
| Update specific gem | `bundle update <gem-name>` |
