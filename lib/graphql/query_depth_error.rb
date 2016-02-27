module GraphQL
  # Raised when the query depth reaches the maximum depth
  # set by max_depth on the query
  class QueryDepthError < RuntimeError
  end
end
