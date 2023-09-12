# Events SDK Ruby

## Installation

Install to Gemfile from rubygems.org:

```ruby
gem 'events-sdk-ruby'
```

Install to environment gems from rubygems.org:

```
gem install 'events-sdk-ruby'
```

## Usage

Create an instance of the Analytics object:

```ruby
require 'hightouch'

analytics = Hightouch::Analytics.new(write_key: 'YOUR_WRITE_KEY')
```

### Identify

```ruby
analytics.identify(user_id: 42,
                   traits: {
                     email: 'name@example.com',
                     first_name: 'Foo',
                     last_name: 'Bar'
                   })
```

### Alias

```ruby
analytics.alias(user_id: 41)
```

### Track

```ruby
analytics.track(user_id: 42, event: 'Created Account')
```

Other methods include `group`, `page`, and `screen`.

### Test Queue

You can use the `test: true` option to Hightouch::Analytics.new to cause all requests to be saved to a test queue until manually reset. All events will process as specified by the configuration, and they will also be stored in a separate queue for inspection during testing.

A test queue can be used as follows:

```ruby
client = Hightouch::Analytics.new(test: true)

client.test_queue # => #<Hightouch::Analytics::TestQueue:0x00007f88d454e9a8 @messages={}>

client.track(user_id: 'foo', event: 'bar')

client.test_queue.all
# [
#     {
#            :context => {
#             :library => {
#                    :name => "events-sdk-ruby",
#                 :version => "2.2.8.pre"
#             }
#         },
#          :messageId => "e9754cc0-1c5e-47e4-832a-203589d279e4",
#          :timestamp => "2021-02-19T13:32:39.547+01:00",
#             :userId => "foo",
#               :type => "track",
#              :event => "bar",
#         :properties => {}
#     }
# ]

client.test_queue.track
# [
#     {
#            :context => {
#             :library => {
#                    :name => "events-sdk-ruby",
#                 :version => "2.2.8.pre"
#             }
#         },
#          :messageId => "e9754cc0-1c5e-47e4-832a-203589d279e4",
#          :timestamp => "2021-02-19T13:32:39.547+01:00",
#             :userId => "foo",
#               :type => "track",
#              :event => "bar",
#         :properties => {}
#     }
# ]

# Other available methods
client.test_queue.alias # => []
client.test_queue.group # => []
client.test_queue.identify # => []
client.test_queue.page # => []
client.test_queue.screen # => []

client.test_queue.reset!

client.test_queue.all # => []
```

Note: It is recommended to call `reset!` before each test to ensure your test queue is empty. For example, in rspec you may have the following:

```ruby
RSpec.configure do |config|
  config.before do
    Analytics.test_queue.reset!
  end
end
```

It is also recommended to stub actions use `stub: true` along with `test: true` so that it doesn't send any real calls during specs.
