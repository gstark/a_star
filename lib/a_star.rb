# frozen_string_literal: true

require_relative "a_star/version"
require_relative "a_star/result"
require_relative "a_star/priority_queue"

module AStar
  ##
  # This is a generalized implementation of A*
  #
  # You must provide a starting element of any data type you wish.
  #
  # To guide the algorithm you must provide a `neighbors` proc/lambda to indicate, for any given node, that node's neighbors. This should return an array of neighbors, likely of the same data type as the starting node as these values will be passed as `node` to subsequent calls.
  #
  # You may also supply a `weight` to indicate the cost of traveling from one node to another. Useful if the graph has non-equal costs from traversing from node to node.
  #
  # The heuristic gives an estimate of the cost of traveling from the current element to the goal. For instance in 2-D space this may be the [cartesian distance](https://en.wikipedia.org/wiki/Cartesian_coordinate_system). In a maze this may be the [manhattan distance](https://en.wikipedia.org/wiki/Taxicab_geometry) from the current node to the goal location.
  #
  # The `visit` callable provide helpful debugging methods.
  #
  # The `goal` callable provides a way to customize the detection of the end of the path traversal.
  #
  # @param [Object] start   an initial value for the starting node. (Required)
  # @param [Proc] goal      a callable that takes keyword `node` representing the current node being visited. Returns `true` if this node is the end goal state. (Required)
  # @param [Proc] neighbors a callable that takes keywords `node` and `path`. `node` is the node being visited. This callable must returns an array of its neighbors to be visited. NOTE: these values will become future `node` values. (Required)
  # @param [Proc] heuristic a callable that takes keyword `node` representing the node being visited current and returns a floating point value estimating the cost to the goal. (Optional)
  # @param [Proc] weight    a callable that takes keywords `node` and `neighbor` representing the node being visited and the neighbor and returns a floating point cost of traveling from the node to the neighbor. (Optional)
  # @param [Proc] visit     a callable that takes keywords `node` and `path` representing the current node and the current travel path. No return value. Useful for debugging. (Optional)
  #
  # @return [Result] contains the total `score` (cost), an array containing the nodes in the `path`, and all the `visited` nodes
  #
  # @example
  #
  # # hash of node to an array of neighbors
  # graph = {
  #   a: [:b, :astray],
  #   b: [:c],
  #   c: [:d],
  #   astray: []
  # }
  #
  # results = AStar.traverse(
  #   # Provide a starting node
  #   start: :a,
  #   # Test if this is the desired ending node `:d`
  #   goal: proc { |node:| node == :d },
  #   # Given a `node` fetch the neighbors, return an empty array
  #   # for unknown nodes. Note that we don't use the path keyword
  #   # so we ignore it with `**` (captures the rest of kwargs)
  #   neighbors: proc { |node:, **| graph.fetch(node, []) }
  # )
  #
  # p results.path
  # # => [:a, :b, :c, :d]
  #
  # @see # https://en.wikipedia.org/wiki/A*_search_algorithm
  #
  def self.traverse(start:, goal:, neighbors:, heuristic: nil, weight: nil, visit: nil)
    # This is a priority queue that stores the entry and it's cost and gives us an ordering of the lowest cost
    open_set = PriorityQueue.new { |a, b| a.cost < b.cost }

    # A hash containing keys of visited nodes and values of the prior node
    came_from = {}

    # A hash containing keys of nodes and values of the g_score
    g_score = Hash.new { Float::INFINITY }
    g_score[start] = 0

    # A hash containing keys of nodes and values of the f_score
    f_score = {}
    f_score[start] = heuristic&.call(start) || 0

    # Initialize the priority queue of nodes with the current node and it's heuristic value
    open_set.push(OpenSet.new(node: start, cost: f_score[start]))

    # Instantiate `node` here so that it is in the closure
    # formed by the Enumerator below. This allows us to
    # create the Enumerator *once* and reuse the object
    # instead of creating it for each iteration of the
    # algorithm's main processing. A hack, I know, but
    # one that may give us a performance boost.
    node = nil

    # Reconstruct the path up to this point.
    #
    # NOTE: this is an enumerator so the receiver must
    #       either use `each` or `to_a` or any other
    #       enumerable to inspect the contents.
    #
    # NOTE: This allows us to pass the enumerator itself
    #       without actually constructing the path. The
    #       path is only created _if_ the caller iterates.
    path = Enumerator.new do |yielder|
      # Don't reuse `node` here since it
      # would impact the outer context
      current_node = node

      full_path = [current_node]
      while came_from[current_node]
        current_node = came_from[current_node]
        full_path.unshift(current_node)
      end

      full_path.each do |current_node|
        yielder << current_node
      end
    end

    # While we still have somewhere to explore
    until open_set.empty?
      # Get (and remove) the element with the lowest cost and retrieve the node
      node = open_set.pop.node

      # Call the visit callback providing the the current node, and the path
      visit&.call(node, path)

      # If we received `true` from the goal proc, construct and return results
      if goal.call(node)
        return Result.new(score: f_score[node], path:, visited: came_from.keys)
      end

      # For each neighbor of the current node
      neighbors.call(node, path).each do |neighbor|
        # Compute the weight from start to the neighbor through the current node
        tentative_g_score = g_score[node] + (weight&.call(node, neighbor) || 0)

        # If this path to neighbor is better than any previous one. Record it!
        if tentative_g_score < g_score[neighbor]
          # Store that we went from node => neighbor
          came_from[neighbor] = node

          # Store the cumulative weight
          g_score[neighbor] = tentative_g_score

          # Store the cumulative weight plus the heuristic of traveling to this neighbor
          f_score[neighbor] = tentative_g_score + (heuristic&.call(neighbor) || 0)

          # Store this entry in the open set of nodes if it isn't already present
          unless open_set.include?(neighbor)
            open_set.push(OpenSet.new(node: neighbor, cost: f_score[neighbor]))
          end
        end
      end
    end

    # There was no path so return a result indicating no path was found
    Result.new(score: nil, path: Enumerator.new {}, visited: came_from.keys)
  end

  private

  OpenSet = Data.define(:node, :cost)
end
