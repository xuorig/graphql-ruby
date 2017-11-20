# frozen_string_literal: true
require "spec_helper"

describe GraphQL::Language::Nodes::DocumentFromSchema do
  let(:schema) {
    node_type = GraphQL::InterfaceType.define do
      name "Node"

      field :id, !types.ID
    end

    choice_type = GraphQL::EnumType.define do
      name "Choice"

      value "FOO", value: :foo
      value "BAR", value: :bar
      value "BAZ", deprecation_reason: 'Use "BAR".'
      value "WOZ", deprecation_reason: GraphQL::Directive::DEFAULT_DEPRECATION_REASON
    end

    sub_input_type = GraphQL::InputObjectType.define do
      name "Sub"
      description "Test"
      input_field :string, types.String, 'Something'
      input_field :int, types.Int, 'Something'
    end

    variant_input_type = GraphQL::InputObjectType.define do
      name "Varied"
      input_field :id, types.ID
      input_field :int, types.Int
      input_field :float, types.Float
      input_field :bool, types.Boolean
      input_field :enum, choice_type, default_value: :foo
      input_field :sub, types[sub_input_type]
    end

    comment_type = GraphQL::ObjectType.define do
      name "Comment"
      description "A blog comment"
      interfaces [node_type]

      field :id, !types.ID
    end

    post_type = GraphQL::ObjectType.define do
      name "Post"
      description "A blog post"

      field :id, !types.ID
      field :title, !types.String
      field :body, !types.String
      field :comments, types[!comment_type]
      field :comments_count, !types.Int, deprecation_reason: 'Use "comments".'
    end

    audio_type = GraphQL::ObjectType.define do
      name "Audio"

      field :id, !types.ID
      field :name, !types.String
      field :duration, !types.Int
    end

    image_type = GraphQL::ObjectType.define do
      name "Image"

      field :id, !types.ID
      field :name, !types.String
      field :width, !types.Int
      field :height, !types.Int
    end

    media_union_type = GraphQL::UnionType.define do
      name "Media"
      description "Media objects"

      possible_types [image_type, audio_type]
    end

    query_root = GraphQL::ObjectType.define do
      name "Query"
      description "The query root of this schema"

      field :post do
        type post_type
        argument :id, !types.ID, 'Post ID'
        argument :varied, variant_input_type, default_value: { id: "123", int: 234, float: 2.3, enum: :foo, sub: [{ string: "str" }] }
        argument :variedWithNulls, variant_input_type, default_value: { id: nil, int: nil, float: nil, enum: nil, sub: nil }
        resolve ->(obj, args, ctx) { Post.find(args["id"]) }
      end
    end

    create_post_mutation = GraphQL::Relay::Mutation.define do
      name "CreatePost"
      description "Create a blog post"

      input_field :title, !types.String
      input_field :body, !types.String

      return_field :post, post_type

      resolve ->(_, _, _) { }
    end

    mutation_root = GraphQL::ObjectType.define do
      name "Mutation"

      field :createPost, field: create_post_mutation.field
    end

    subscription_root = GraphQL::ObjectType.define do
      name "Subscription"

      field :post do
        type post_type
        argument :id, !types.ID
        resolve ->(_, _, _) { }
      end
    end

    GraphQL::Schema.define(
      query: query_root,
      mutation: mutation_root,
      subscription: subscription_root,
      resolve_type: ->(a,b,c) { :pass },
      orphan_types: [media_union_type]
    )
  }

  describe "#document" do
    let(:subject) { GraphQL::Language::Nodes::DocumentFromSchema.new(schema) }

    let(:document) { subject.document }

    it "returns an AST from a GraphQL::Schema object" do
      binding.pry

      expected = <<-IDL
# The query root of this schema
type Query {
  post(id: ID!, varied: Varied, variedWithNulls: Varied): Post
}

# A blog post
type Post {
  id: ID!
  title: String!
  body: String!
  comments: [Comment!]
  comments_count: Int!
}

# A blog comment
type Comment implements Node {
  id: ID!
}

interface Node {
  id: ID!
}

input Varied {
  id: ID
  int: Int
  float: Float
  bool: Boolean
  enum: Choice
  sub: [Sub]
}

enum Choice {
  FOO
  BAR
  BAZ
  WOZ
}

# Test
input Sub {
  # Something
  string: String

  # Something
  int: Int
}

type Mutation {
  # Create a blog post
  createPost(input: CreatePostInput!): CreatePostPayload
}

# Autogenerated return type of CreatePost
type CreatePostPayload {
  # A unique identifier for the client performing the mutation.
  clientMutationId: String
  post: Post
}

# Autogenerated input type of CreatePost
input CreatePostInput {
  # A unique identifier for the client performing the mutation.
  clientMutationId: String
  title: String!
  body: String!
}

type Subscription {
  post(id: ID!): Post
}

# Media objects
union Media = Image | Audio

type Image {
  id: ID!
  name: String!
  width: Int!
  height: Int!
}

type Audio {
  id: ID!
  name: String!
  duration: Int!
}
      IDL

      assert_equal expected.chomp, document.to_query_string
    end
  end
end
