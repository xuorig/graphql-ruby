module GraphQL
  module Analysis
    class Analyzer
      def initialize(query)
        @query = query
      end

      def analyze?
        true
      end

      def result
        raise NotImplementedError
      end

      def on_enter_argument(node, parent, visitor)
      end

      def on_leave_argument(node, parent, visitor)
      end

      def on_enter_directive(node, parent, visitor)
      end

      def on_leave_directive(node, parent, visitor)
      end

      def on_enter_directive_definition(node, parent, visitor)
      end

      def on_leave_directive_definition(node, parent, visitor)
      end

      def on_enter_directive_location(node, parent, visitor)
      end

      def on_leave_directive_location(node, parent, visitor)
      end

      def on_enter_document(node, parent, visitor)
      end

      def on_leave_document(node, parent, visitor)
      end

      def on_enter_field(node, parent, visitor)
      end

      def on_leave_field(node, parent, visitor)
      end

      alias :on_document :todo
      alias :on_enum :todo
      alias :on_enum_type_definition :todo
      alias :on_enum_type_extension :todo
      alias :on_enum_value_definition :todo
      alias :on_fragment_definition :todo
      alias :on_fragment_spread :todo
      alias :on_inline_fragment :todo
      alias :on_input_object :todo
      alias :on_input_object_type_definition :todo
      alias :on_input_object_type_extension :todo
      alias :on_input_value_definition :todo
      alias :on_interface_type_definition :todo
      alias :on_interface_type_extension :todo
      alias :on_list_type :todo
      alias :on_non_null_type :todo
      alias :on_null_value :todo
      alias :on_object_type_definition :todo
      alias :on_object_type_extension :todo
      alias :on_operation_definition :todo
      alias :on_scalar_type_definition :todo
      alias :on_scalar_type_extension :todo
      alias :on_schema_definition :todo
      alias :on_schema_extension :todo
      alias :on_type_name :todo
      alias :on_union_type_definition :todo
      alias :on_union_type_extension :todo
      alias :on_variable_definition :todo
      alias :on_variable_identifier :todo

      def todo
        # TODO: probably convert all these aliases to actual methods
      end

      protected

      attr_reader :query, :visitor
    end
  end
end
