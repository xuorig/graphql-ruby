# frozen_string_literal: true

module GraphQL
  class Query
    # @api private
    # Sanitizes a {Query} and variables given a scrubbing configuration
    #
    # @param query [Query]
    # @param whitelist
    # @param blacklist
    # @param mutations
    class Sanitizer
      def initialize(query, whitelist: [], blacklist: [], mutations: false)
        @query = query
        @whitelist = whitelist ? whitelist.map(&:to_s).to_set  : nil
        @blacklist = blacklist ? blacklist.map(&:to_s).to_set : nil

        if @whitelist && @blacklist
          raise ArgumentError, "#{self.class.name} supports whitelist: _or_ blacklist:, but not both."
        end

        @mutations = mutations
      end

      # Sanitize a variables hash for the given query
      # @param variables [Hash]
      # @return [Hash]
      def sanitize_variables(variables)
        {}
      end

      # Returns the sanitized query for the given query
      # @return [String]
      def sanitized
        query.document.to_query_string(printer: printer)
      end

      private

      def printer
        GraphQL::Query::Sanitizer::Printer.new(
          whitelist: whitelist,
          blacklist: blacklist,
        )
      end
    end

      class Printer < GraphQL::Language::Printer
        def initialize(whitelist: [], blacklist: [], mutations: false)
        end

        def print_argument(arg)

        end
      end
    end
  end
end
