# frozen_string_literal: true
module GraphQL
  module Language
    module Nodes
      # {AbstractNode} is the base class for all nodes in a GraphQL AST.
      #
      # It provides some APIs for working with ASTs:
      # - `children` returns all AST nodes attached to this one. Used for tree traversal.
      # - `scalars` returns all scalar (Ruby) values attached to this one. Used for comparing nodes.
      # - `to_query_string` turns an AST node into a GraphQL string

      class AbstractNode
        attr_reader :line, :col, :filename

        # Initialize a node by extracting its position,
        # then calling the class's `initialize_node` method.
        # @param options [Hash] Initial attributes for this node
        def initialize(options={})
          if options.key?(:position_source)
            position_source = options.delete(:position_source)
            @line, @col = position_source.line_and_column
          end

          @filename = options.delete(:filename)

          initialize_node(options)
        end

        # Value equality
        # @return [Boolean] True if `self` is equivalent to `other`
        def eql?(other)
          return true if equal?(other)
          other.is_a?(self.class) &&
            other.scalars.eql?(self.scalars) &&
            other.children.eql?(self.children)
        end

        # @return [Array<GraphQL::Language::Nodes::AbstractNode>] all nodes in the tree below this one
        def children
          []
        end

        # @return [Array<Integer, Float, String, Boolean, Array>] Scalar values attached to this node
        def scalars
          []
        end
        # @return [Symbol] the method to call on {Language::Visitor} for this node
        def visit_method
          raise NotImplementedError, "#{self.class.name}#visit_method shold return a symbol"
        end

        # @return [Symbol] the method to call on {Language::Visitor} for this node
        def visit_method
          raise NotImplementedError, "#{self.class.name}#visit_method shold return a symbol"
        end

        def position
          [line, col]
        end

        def to_query_string(printer: GraphQL::Language::Printer.new)
          printer.print(self)
        end

      # Base class for non-null type names and list type names
      class WrapperType < AbstractNode
        attr_reader :of_type
        scalar_attributes :of_type

        # TODO DRY with `replace_child`
        def delete_child(previous_child)
          # Figure out which list `previous_child` may be found in
          method_name = previous_child.children_method_name
          # Copy that list, and delete previous_child
          new_children = public_send(method_name).dup
          new_children.delete(previous_child)
          # Copy this node, but with the new list of children:
          copy_of_self = merge(method_name => new_children)
          # Return the copy:
          copy_of_self
        end

        class << self
          # Add a default `#visit_method` and `#children_method_name` using the class name
          def inherited(child_class)
            super
            name_underscored = child_class.name
              .split("::").last
              .gsub(/([a-z])([A-Z])/,'\1_\2') # insert underscores
              .downcase # remove caps

            child_class.module_eval <<-RUBY
              def visit_method
                :on_#{name_underscored}
              end

              def children_method_name
                :#{name_underscored}s
              end
            RUBY
          end

          private

          # Name accessors which return lists of nodes,
          # along with the kind of node they return, if possible.
          # - Add a reader for these children
          # - Add a persistent update method to add a child
          # - Generate a `#children` method
          def children_methods(children_of_type)
            if @children_methods
              raise "Can't re-call .children_methods for #{self} (already have: #{@children_methods})"
            else
              @children_methods = children_of_type
            end

            if children_of_type == false
              @children_methods = {}
              # skip
            else

              children_of_type.each do |method_name, node_type|
                module_eval <<-RUBY, __FILE__, __LINE__
                  # A reader for these children
                  attr_reader :#{method_name}
                RUBY

                if node_type
                  # Only generate a method if we know what kind of node to make
                  module_eval <<-RUBY, __FILE__, __LINE__
                    # Singular method: create a node with these options
                    # and return a new `self` which includes that node in this list.
                    def merge_#{method_name.to_s.sub(/s$/, "")}(node_opts)
                      merge(#{method_name}: #{method_name} + [#{node_type.name}.new(node_opts)])
                    end
                  RUBY
                end
              end

              if children_of_type.size == 1
                module_eval <<-RUBY, __FILE__, __LINE__
                  alias :children #{children_of_type.keys.first}
                RUBY
              else
                module_eval <<-RUBY, __FILE__, __LINE__
                  def children
                    @children ||= (#{children_of_type.keys.map { |k| "@#{k}" }.join(" + ")}).freeze
                  end
                RUBY
              end
            end

            if defined?(@scalar_methods)
              generate_initialize_node
            else
              raise "Can't generate_initialize_node because scalar_methods wasn't called; call it before children_methods"
            end
          end

          # These methods return a plain Ruby value, not another node
          # - Add reader methods
          # - Add a `#scalars` method
          def scalar_methods(*method_names)
            if @scalar_methods
              raise "Can't re-call .scalar_methods for #{self} (already have: #{@scalar_methods})"
            else
              @scalar_methods = method_names
            end

            if method_names == [false]
              @scalar_methods = []
              # skip it
            else
              module_eval <<-RUBY, __FILE__, __LINE__
                # add readers for each scalar
                attr_reader #{method_names.map { |m| ":#{m}"}.join(", ")}

                def scalars
                  @scalars ||= [#{method_names.map { |k| "@#{k}" }.join(", ")}].freeze
                end
              RUBY
            end
          end

          def generate_initialize_node
            scalar_method_names = @scalar_methods
            # TODO: These probably should be scalar methods, but `types` returns an array
            [:types, :description].each do |extra_method|
              if method_defined?(extra_method)
                scalar_method_names += [extra_method]
              end
            end

            all_method_names = scalar_method_names + @children_methods.keys
            if all_method_names.include?(:alias)
              # Rather than complicating this special case,
              # let it be overridden (in field)
              return
            else
              arguments = scalar_method_names.map { |m| "#{m}: nil"} +
                @children_methods.keys.map { |m| "#{m}: []" }

              assignments = scalar_method_names.map { |m| "@#{m} = #{m}"} +
                @children_methods.keys.map { |m| "@#{m} = #{m}.freeze" }

              module_eval <<-RUBY, __FILE__, __LINE__
                def initialize_node #{arguments.join(", ")}
                  #{assignments.join("\n")}
                end
              RUBY
            end
          end
        end
      end

      # Base class for non-null type names and list type names
      class WrapperType < AbstractNode
        scalar_methods :of_type
        children_methods(false)
      end

      # Base class for nodes whose only value is a name (no child nodes or other scalars)
      class NameOnlyNode < AbstractNode
        attr_reader :name
        scalar_attributes :name

        def initialize_node(name: nil)
          @name = name
        end

        def children
          [].freeze
        end
      end

      # A key-value pair for a field's inputs
      class Argument < AbstractNode
        attr_reader :name, :value
        scalar_attributes :name, :value

        # @!attribute name
        #   @return [String] the key for this argument

        # @!attribute value
        #   @return [String, Float, Integer, Boolean, Array, InputObject] The value passed for this key

        def children
          [value].flatten.select { |v| v.is_a?(AbstractNode) }
        end

        def visit_method
          :on_argument
        end
      end

      class Directive < AbstractNode
        attr_reader :name, :arguments
        scalar_attributes :name
        child_attributes :arguments

        attr_accessor :name, :arguments
        alias :children :arguments

        def initialize_node(name: nil, arguments: [])
          @name = name
          @arguments = arguments
        end

        def visit_method
          :on_directive
        end
      end

      class DirectiveDefinition < AbstractNode
        attr_reader :name, :arguments, :locations, :description
        scalar_attributes :name
        child_attributes :arguments, :locations

        def initialize_node(name: nil, arguments: [], locations: [], description: nil)
          @name = name
          @arguments = arguments
          @locations = locations
          @description = description
        end

        def children
          arguments + locations
        end

        def visit_method
          :on_directive_definition
        end
      end

      class DirectiveLocation < NameOnlyNode
        def visit_method
          :on_directive_location
        end
      end

      # This is the AST root for normal queries
      #
      # @example Deriving a document by parsing a string
      #   document = GraphQL.parse(query_string)
      #
      # @example Creating a string from a document
      #   document.to_query_string
      #   # { ... }
      #
      # @example Creating a custom string from a document
      #  class VariableScrubber < GraphQL::Language::Printer
      #    def print_argument(arg)
      #      "#{arg.name}: <HIDDEN>"
      #    end
      #  end
      #
      #  document.to_query_string(printer: VariableSrubber.new)
      #
      class Document < AbstractNode
        attr_reader :definitions
        child_attributes :definitions

        # @!attribute definitions
        #   @return [Array<OperationDefinition, FragmentDefinition>] top-level GraphQL units: operations or fragments

        def slice_definition(name)
          GraphQL::Language::DefinitionSlice.slice(self, name)
        end

        def visit_method
          :on_document
        end
      end

      # An enum value. The string is available as {#name}.
      class Enum < NameOnlyNode
        def visit_method
          :on_enum
        end
      end

      # A null value literal.
      class NullValue < NameOnlyNode
        def visit_method
          :on_null_value
        end
      end

      # A single selection in a GraphQL query.
      class Field < AbstractNode
        attr_reader :name, :alias, :arguments, :directives, :selections
        scalar_attributes :name, :alias
        child_attributes :arguments, :directives, :selections

        # @!attribute selections
        #   @return [Array<Nodes::Field>] Selections on this object (or empty array if this is a scalar field)

        def initialize_node(name: nil, arguments: [], directives: [], selections: [], **kwargs)
          @name = name
          @arguments = arguments
          @directives = directives
          @selections = selections
          # oops, alias is a keyword:
          @alias = kwargs.fetch(:alias, nil)
        end

        # Override this because default is `:fields`
        def children_method_name
          :selections
        end

        def visit_method
          :on_field
        end
      end

      # A reusable fragment, defined at document-level.
      class FragmentDefinition < AbstractNode
        attr_reader :name, :type, :directives, :selections
        scalar_attributes :name, :type
        child_attributes :directives, :selections

        # @!attribute name
        #   @return [String] the identifier for this fragment, which may be applied with `...#{name}`

        # @!attribute type
        #   @return [String] the type condition for this fragment (name of type which it may apply to)
        def initialize_node(name: nil, type: nil, directives: [], selections: [])
          @name = name
          @type = type
          @directives = directives
          @selections = selections
        end

        def children_method_name
          :definitions
        end

        def visit_method
          :on_fragment_definition
        end
      end

      # Application of a named fragment in a selection
      class FragmentSpread < AbstractNode
        attr_reader :name, :directives
        scalar_attributes :name
        child_attributes :directives

        # @!attribute name
        #   @return [String] The identifier of the fragment to apply, corresponds with {FragmentDefinition#name}

        def initialize_node(name: nil, directives: [])
          @name = name
          @directives = directives
        end

        def visit_method
          :on_fragment_spread
        end
      end

      # An unnamed fragment, defined directly in the query with `... {  }`
      class InlineFragment < AbstractNode
        attr_reader :type, :directives, :selections
        scalar_attributes :type
        child_attributes :directives, :selections

        # @!attribute type
        #   @return [String, nil] Name of the type this fragment applies to, or `nil` if this fragment applies to any type

        def initialize_node(type: nil, directives: [], selections: [])
          @type = type
          @directives = directives
          @selections = selections
        end

        def children
          directives + selections
        end

        def scalars
          [type]
        end

        def visit_method
          :on_inline_fragment
        end
      end

      # A collection of key-value inputs which may be a field argument
      class InputObject < AbstractNode
        attr_reader :arguments
        child_attributes :arguments

        # @!attribute arguments
        #   @return [Array<Nodes::Argument>] A list of key-value pairs inside this input object

        # @return [Hash<String, Any>] Recursively turn this input object into a Ruby Hash
        def to_h(options={})
          arguments.inject({}) do |memo, pair|
            v = pair.value
            memo[pair.name] = serialize_value_for_hash v
            memo
          end
        end

        def visit_method
          :on_input_object
        end
        private

        def serialize_value_for_hash(value)
          case value
          when InputObject
            value.to_h
          when Array
            value.map do |v|
              serialize_value_for_hash v
            end
          when Enum
            value.name
          when NullValue
            nil
          else
            value
          end
        end
      end


      # A list type definition, denoted with `[...]` (used for variable type definitions)
      class ListType < WrapperType
        def visit_method
          :on_list_type
        end
      end

      # A non-null type definition, denoted with `...!` (used for variable type definitions)
      class NonNullType < WrapperType
        def visit_method
          :on_non_null_type
        end
      end

      # A query, mutation or subscription.
      # May be anonymous or named.
      # May be explicitly typed (eg `mutation { ... }`) or implicitly a query (eg `{ ... }`).
      class OperationDefinition < AbstractNode
        attr_reader :operation_type, :name, :variables, :directives, :selections
        scalar_attributes :operation_type, :name
        child_attributes :variables, :directives, :selections

        # @!attribute variables
        #   @return [Array<VariableDefinition>] Variable definitions for this operation

        # @!attribute selections
        #   @return [Array<Field>] Root-level fields on this operation

        # @!attribute operation_type
        #   @return [String, nil] The root type for this operation, or `nil` for implicit `"query"`

        # @!attribute name
        #   @return [String, nil] The name for this operation, or `nil` if unnamed

        def children_method_name
          :definitions
        end

        def visit_method
          :on_operation_definition
        end
      end

      # A type name, used for variable definitions
      class TypeName < NameOnlyNode
        def visit_method
          :on_type_name
        end
      end

      # An operation-level query variable
      class VariableDefinition < AbstractNode
        attr_reader :name, :type, :default_value
        scalar_attributes :name, :type, :default_value

        # @!attribute default_value
        #   @return [String, Integer, Float, Boolean, Array, NullValue] A Ruby value to use if no other value is provided

        # @!attribute type
        #   @return [TypeName, NonNullType, ListType] The expected type of this value

        # @!attribute name
        #   @return [String] The identifier for this variable, _without_ `$`

        def initialize_node(name: nil, type: nil, default_value: nil)
          @name = name
          @type = type
          @default_value = default_value
        end

        def visit_method
          :on_variable_definition
        end

        def scalars
          [name, type, default_value]
        end
      end

      # Usage of a variable in a query. Name does _not_ include `$`.
      class VariableIdentifier < NameOnlyNode
        def visit_method
          :on_variable_identifier
        end
      end

      class SchemaDefinition < AbstractNode
        attr_accessor :query, :mutation, :subscription

        def initialize_node(query: nil, mutation: nil, subscription: nil)
          @query = query
          @mutation = mutation
          @subscription = subscription
        end

        def scalars
          [query, mutation, subscription]
        end

        def visit_method
          :on_schema_definition
        end

        alias :children :directives
      end

      class SchemaExtension < AbstractNode
        attr_reader :query, :mutation, :subscription, :directives

        def initialize_node(query: nil, mutation: nil, subscription: nil, directives: [])
          @query = query
          @mutation = mutation
          @subscription = subscription
          @directives = directives
        end

        def scalars
          [query, mutation, subscription]
        end

        alias :children :directives

        def visit_method
          :on_schema_extension
        end
      end

      class ScalarTypeDefinition < AbstractNode
        attr_reader :name, :directives, :description
        scalar_attributes :name
        child_attributes :directives

        def initialize_node(name:, directives: [], description: nil)
          @name = name
          @directives = directives
          @description = description
        end

        def visit_method
          :on_scalar_type_definition
        end
      end

      class ScalarTypeExtension < AbstractNode
        attr_reader :name, :directives
        alias :children :directives

        def initialize_node(name:, directives: [])
          @name = name
          @directives = directives
        end

        def visit_method
          :on_scalar_type_extension
        end
      end

      class ObjectTypeDefinition < AbstractNode
        attr_reader :name, :interfaces, :fields, :directives, :description
        scalar_attributes :name
        child_attributes :interfaces, :fields, :directives

        def initialize_node(name:, interfaces:, fields:, directives: [], description: nil)
          @name = name
          @interfaces = interfaces || []
          @directives = directives
          @fields = fields
          @description = description
        end

        def children
          interfaces + fields + directives
        end

        def visit_method
          :on_object_type_definition
        end
      end

      class ObjectTypeExtension < AbstractNode
        attr_reader :name, :interfaces, :fields, :directives

        def initialize_node(name:, interfaces:, fields:, directives: [])
          @name = name
          @interfaces = interfaces || []
          @directives = directives
          @fields = fields
        end

        def children
          interfaces + fields + directives
        end

        def visit_method
          :on_object_type_extension
        end
      end

      class InputValueDefinition < AbstractNode
        attr_reader :name, :type, :default_value, :directives,:description
        scalar_attributes :name, :type, :default_value
        child_attributes :directives

        def initialize_node(name:, type:, default_value: nil, directives: [], description: nil)
          @name = name
          @type = type
          @default_value = default_value
          @directives = directives
          @description = description
        end

        def scalars
          [name, type, default_value]
        end

        def visit_method
          :on_input_value_definition
        end
      end

      class FieldDefinition < AbstractNode
        attr_reader :name, :arguments, :type, :directives, :description
        scalar_attributes :name, :type
        child_attributes :arguments, :directives

      class ObjectTypeDefinition < AbstractNode
        attr_reader :description
        scalar_methods :name, :interfaces
        children_methods({
          directives: GraphQL::Language::Nodes::Directive,
          fields: GraphQL::Language::Nodes::FieldDefinition,
        })
      end

        def scalars
          [name, type]
        end

        def visit_method
          :on_field_definition
        end
      end

      class InterfaceTypeDefinition < AbstractNode
        include Scalars::Name

        attr_accessor :name, :fields, :directives, :description

        def initialize_node(name:, fields:, directives: [], description: nil)
          @name = name
          @fields = fields
          @directives = directives
          @description = description
        end

        def children
          fields + directives
        end

        def visit_method
          :on_interface_type_definition
        end
      end

      class InterfaceTypeExtension < AbstractNode
        attr_reader :name, :fields, :directives

        def initialize_node(name:, fields:, directives: [])
          @name = name
          @fields = fields
          @directives = directives
        end

        def children
          fields + directives
        end

        def visit_method
          :on_interface_type_extension
        end
      end

      class UnionTypeDefinition < AbstractNode
        attr_reader :name, :types, :directives, :description
        include Scalars::Name

        def initialize_node(name:, types:, directives: [], description: nil)
          @name = name
          @types = types
          @directives = directives
          @description = description
        end

        def children
          types + directives
        end

        def visit_method
          :on_union_type_definition
        end
      end

      class UnionTypeExtension < AbstractNode
        attr_reader :name, :types, :directives

        def initialize_node(name:, types:, directives: [])
          @name = name
          @types = types
          @directives = directives
        end

        def children
          types + directives
        end

        def visit_method
          :on_union_type_extension
        end
      end

      class EnumTypeDefinition < AbstractNode
        attr_reader :name, :values, :directives, :description
        scalar_attributes :name
        child_attributes :values, :directives

        def initialize_node(name:, values:, directives: [], description: nil)
          @name = name
          @values = values
          @directives = directives
          @description = description
        end

        def children
          values + directives
        end

        def visit_method
          :on_enum_type_extension
        end
      end

      class EnumTypeExtension < AbstractNode
        attr_reader :name, :values, :directives

        def initialize_node(name:, values:, directives: [])
          @name = name
          @values = values
          @directives = directives
        end

        def children
          values + directives
        end

        def visit_method
          :on_enum_type_extension
        end
      end

      class EnumValueDefinition < AbstractNode
        attr_reader :name, :directives, :description
        scalar_attributes :name
        child_attributes :directives

      class EnumTypeDefinition < AbstractNode
        attr_reader :description
        scalar_methods :name
        children_methods({
          directives: GraphQL::Language::Nodes::Directive,
          values: GraphQL::Language::Nodes::EnumValueDefinition,
        })
      end

        def initialize_node(name:, directives: [], description: nil)
          @name = name
          @directives = directives
          @description = description
        end

        def visit_method
          :on_enum_type_definition
        end
      end

      class InputObjectTypeDefinition < AbstractNode
        include Scalars::Name

        attr_accessor :name, :fields, :directives, :description
        alias :children :fields

        def initialize_node(name:, fields:, directives: [], description: nil)
          @name = name
          @fields = fields
          @directives = directives
          @description = description
        end

        def visit_method
          :on_input_object_type_definition
        end

        def children
          fields + directives
        end
      end

      class InputObjectTypeExtension < AbstractNode
        attr_reader :name, :fields, :directives

        def initialize_node(name:, fields:, directives: [])
          @name = name
          @fields = fields
          @directives = directives
        end

        def children
          fields + directives
        end

        def visit_method
          :on_input_object_type_extension
        end
      end
    end
  end
end
