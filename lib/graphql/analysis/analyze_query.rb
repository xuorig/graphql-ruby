# frozen_string_literal: true
module GraphQL
  module Analysis
    module_function

    # @return [void]
    def analyze_multiplex(multiplex, analyzers)
      multiplex_analyzers = analyzers.map { |analyzer| analyzer.new(multiplex) }

      multiplex.trace("analyze_multiplex", { multiplex: multiplex }) do
        query_results = multiplex.queries.map do |query|
          if query.valid?
            analyze_query(
              query,
              query.analyzers,
              multiplex_analyzers: multiplex_analyzers
            )
          else
            []
          end
        end

        multiplex_results = analyzers.map(&:result)
        multiplex_errors = analysis_errors(multiplex_results)

        multiplex.queries.each_with_index do |query, idx|
          query.analysis_errors = multiplex_errors + analysis_errors(query_results[idx])
        end
      end
      nil
    end

    # Visit `query`'s internal representation, calling `analyzers` along the way.
    #
    # - First, query analyzers are filtered down by calling `.analyze?(query)`, if they respond to that method
    # - Then, query analyzers are initialized by calling `.initial_value(query)`, if they respond to that method.
    # - Then, they receive `.call(memo, visit_type, irep_node)`, where visit type is `:enter` or `:leave`.
    # - Last, they receive `.final_value(memo)`, if they respond to that method.
    #
    # It returns an array of final `memo` values in the order that `analyzers` were passed in.
    #
    # @param query [GraphQL::Query]
    # @param analyzers [Array<#call>] Objects that respond to `#call(memo, visit_type, irep_node)`
    # @return [Array<Any>] Results from those analyzers
    def analyze_query(query, analyzers, multiplex_analyzers: [])
      query.trace("analyze_query", { query: query }) do
        analyzers_to_run = analyzers
          .map { |analyzer| analyzer.new(query) }
          .select { |analyzer| analyzer.analyze? }

        analyzers_to_run = analyzers_to_run + multiplex_analyzers
        return unless analyzers_to_run.any?

        visitor = GraphQL::Analysis::Visitor.new(
          query: query,
          analyzers: analyzers_to_run
        )

        visitor.visit

        analyzers.map(&:result)
      end
    end

    private

    module_function

    def analysis_errors(results)
      results.flatten.select { |r| r.is_a?(GraphQL::AnalysisError) }
    end
  end
end
