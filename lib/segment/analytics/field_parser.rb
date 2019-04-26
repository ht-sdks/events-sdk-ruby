module Segment
  class Analytics
    # Handles parsing fields according to the Segment Spec
    #
    # @see https://segment.com/docs/spec/
    class FieldParser
      class << self
        include Segment::Analytics::Utils

        # In addition to the common fields, track accepts:
        #
        # - "event"
        # - "properties"
        def parse_for_track(fields)
          common = parse_common_fields(fields)

          event = fields[:event]
          properties = fields[:properties] || {}

          check_presence!(event, 'event')
          check_is_hash!(properties, 'properties')

          isoify_dates! properties

          common.merge({
            :type => 'track',
            :event => event.to_s,
            :properties => properties
          })
        end

        # In addition to the common fields, identify accepts:
        #
        # - "traits"
        def parse_for_identify(fields)
          common = parse_common_fields(fields)

          traits = fields[:traits] || {}
          check_is_hash!(traits, 'traits')
          isoify_dates! traits

          common.merge({
            :type => 'identify',
            :traits => traits
          })
        end

        # In addition to the common fields, alias accepts:
        #
        # - "previous_id"
        def parse_for_alias(fields)
          common = parse_common_fields(fields)

          previous_id = fields[:previous_id]
          check_presence!(previous_id, 'previous_id')

          common.merge({
            :type => 'alias',
            :previousId => previous_id
          })
        end

        # In addition to the common fields, group accepts:
        #
        # - "group_id"
        # - "traits"
        def parse_for_group(fields)
          common = parse_common_fields(fields)

          group_id = fields[:group_id]
          traits = fields[:traits] || {}

          check_presence!(group_id, 'group_id')
          check_is_hash!(traits, 'traits')

          isoify_dates! traits

          common.merge({
            :type => 'group',
            :groupId => group_id,
            :traits => traits
          })
        end

        # In addition to the common fields, page accepts:
        #
        # - "name"
        # - "properties"
        def parse_for_page(fields)
          common = parse_common_fields(fields)

          name = fields[:name] || ''
          properties = fields[:properties] || {}

          check_is_hash!(properties, 'properties')

          isoify_dates! properties

          common.merge({
            :type => 'page',
            :name => name.to_s,
            :properties => properties
          })
        end

        # In addition to the common fields, screen accepts:
        #
        # - "name"
        # - "properties"
        # - "category" (Not in spec, retained for backward compatibility"
        def parse_for_screen(fields)
          common = parse_common_fields(fields)

          name = fields[:name]
          properties = fields[:properties] || {}
          category = fields[:category]

          check_presence!(name, 'name')
          check_is_hash!(properties, 'properties')

          isoify_dates! properties

          common.merge({
            :type => 'screen',
            :name => name,
            :properties => properties,
            :category => category
          })
        end

        private

        def parse_common_fields(fields)
          timestamp = fields[:timestamp] || Time.new
          message_id = fields[:message_id].to_s if fields[:message_id]
          context = fields[:context] || {}

          check_user_id! fields
          check_timestamp! timestamp

          add_context! context

          {
            :anonymousId => fields[:anonymous_id],
            :context => context,
            :integrations => fields[:integrations],
            :messageId => message_id,
            :timestamp => datetime_in_iso8601(timestamp),
            :userId => fields[:user_id],
            :options => fields[:options] # Not in spec, retained for backward compatibility
          }
        end

        def check_user_id!(fields)
          unless fields[:user_id] || fields[:anonymous_id]
            raise ArgumentError, 'Must supply either user_id or anonymous_id'
          end
        end

        def check_timestamp!(timestamp)
          raise ArgumentError, 'Timestamp must be a Time' unless timestamp.is_a? Time
        end

        def add_context!(context)
          context[:library] = { :name => 'analytics-ruby', :version => Segment::Analytics::VERSION.to_s }
        end

        # private: Ensures that a string is non-empty
        #
        # obj    - String|Number that must be non-blank
        # name   - Name of the validated value
        def check_presence!(obj, name)
          if obj.nil? || (obj.is_a?(String) && obj.empty?)
            raise ArgumentError, "#{name} must be given"
          end
        end

        def check_is_hash!(obj, name)
          raise ArgumentError, "#{name} must be a Hash" unless obj.is_a? Hash
        end
      end
    end
  end
end
