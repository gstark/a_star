##
#
# Result type to return score, path and visited
#
# result = a_star(...)
#
# result.score   # Returns total weight of traversing the path or `nil` if no path
# result.path    # Array of found path containing nodes or empty if no path
# result.visited # Array of nodes visited during traversal
class Result < Data.define(:score, :path, :visited)
end
