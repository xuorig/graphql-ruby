# frozen_string_literal: true
module GraphQL
  module Language
    class InlineFragments
      def initialize(document)
        @fragment_definitions = {}
        @operation_definitions = {}

        document.definitions.each do |definition|
          case definition
          when GraphQL::Language::Nodes::FragmentDefinition
            @fragment_definitions[definition.name] = definition
          when GraphQL::Language::Nodes::OperationDefinition
            @operation_definitions[definition.name] = definition
          end
        end
      end

      def inlined
        operations = @operation_definitions.values.map do |operation|
          inlined_operation(operation)
        end

        GraphQL::Language::Nodes::Document.new(definitions: operations)
      end

      private

      def inlined_operation(operation)
        GraphQL::Language::Nodes::OperationDefinition.new(
          operation_type: operation.operation_type,
          name: operation.name,
          variables: operation.variables.dup,
          directives: operation.directives.dup,
          selections: inlined_selections(operation.selections)
        )
      end

      def inlined_selections(selections)
        selections.flat_map { |selection| inlined_selection(selection) }
      end

      def inlined_selection(selection)
        case selection
        when GraphQL::Language::Nodes::FragmentSpread
          fragment_definition = @fragment_definitions[selection.name]
          inlined_selections(fragment_definition.selections)
        when GraphQL::Language::Nodes::Field
          GraphQL::Language::Nodes::Field.new(
            name: selection.name,
            alias: selection.alias,
            arguments: selection.arguments.dup,
            directives: selection.directives.dup,
            selections: inlined_selections(selection .selections)
          )
        when GraphQL::Language::Nodes::InlineFragment
          GraphQL::Language::Nodes::InlineFragment.new(
            type: selection.type,
            directives: selection.directives.dup,
            selections: inlined_selections(selection.selections)
          )
        end
      end
    end
  end
end
