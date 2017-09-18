# frozen_string_literal: true
require "spec_helper"

describe GraphQL::Language::InlineFragments do
  let(:query_string) {%|
    query getCheese {
      cheese {
        ... cheeseFields
      }
    }

    fragment cheeseFields on Cheese { flavor }
  |}

  let(:document) {
    GraphQL.parse(query_string)
  }

  let(:inliner) {
    GraphQL::Language::InlineFragments.new(document)
  }

  describe "#simplified" do
    it "returns a simplified document with fragments inlined and variables inlined" do
      inlined = inliner.inlined
      expected = GraphQL.parse(%|
        query getCheese {
          cheese {
            flavor
          }
        }
      |)

      assert_equal expected.to_query_string, inlined.to_query_string
    end
  end
end
