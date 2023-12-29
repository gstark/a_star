# frozen_string_literal: true

require "test_helper"

describe AStar do
  it "has a version number" do
    refute_nil ::AStar::VERSION
  end

  it "solves a simple graph without a path" do
    graph = {
      a: [:b],
      b: [:c],
      c: [:d],
      e: []
    }

    results = AStar.traverse(
      start: :a,
      goal: proc { |node:| node == :e },
      neighbors: proc { |node:, **| graph.fetch(node, []) }
    )

    assert_equal [], results.path
    assert_nil results.score
    refute_empty results.visited
  end

  it "solves a simple graph with a path" do
    graph = {
      a: [:b, :astray],
      b: [:c],
      c: [:d],
      astray: []
    }

    results = AStar.traverse(
      start: :a,
      goal: proc { |node:| node == :d },
      neighbors: proc { |node:, **| graph.fetch(node, []) }
    )

    assert_equal [:a, :b, :c, :d], results.path
    assert_equal results.score, 0
    refute_empty results.visited
  end

  it "calls the visit proc for each node visited" do
    visited_nodes = []
    paths = []

    graph = {
      a: [:b, :astray],
      b: [:c],
      c: [:d],
      astray: []
    }

    AStar.traverse(
      start: :a,
      goal: proc { |node:| node == :d },
      neighbors: proc { |node:, **| graph.fetch(node, []) },
      visit: proc do |node:, path:|
        visited_nodes << node
        paths << path
      end
    )

    # The algorithm will explore a => b, then a => astray.
    # Seeing there is nowhere to explore, returns to b. Then a => b,
    # and following b => c, then finally c => d
    assert_equal [[:a], [:a, :b], [:a, :astray], [:a, :b, :c], [:a, :b, :c, :d]], paths

    # See above about the ordering of path traversal.
    assert_equal [:a, :b, :astray, :c, :d], visited_nodes
  end

  it "computes a score for the path when given a consistent weight" do
    graph = {
      a: [:b, :astray],
      b: [:c],
      c: [:d],
      astray: []
    }

    results = AStar.traverse(
      start: :a,
      goal: proc { |node:| node == :d },
      neighbors: proc { |node:, **| graph.fetch(node, []) },
      # Assign a weight of 1 for each node
      weight: proc { 1 }
    )

    assert_equal [:a, :b, :c, :d], results.path
    # The score is three since we traversed three edges, each with a weight of 1
    # a => b, b => c, c => d
    assert_equal results.score, 3
    refute_empty results.visited
  end

  it "follows a path with a lower weight" do
    #
    # Here is the graph we represent with
    # nodes and their weights
    #
    # Even though the a => b => c => e path
    # is shorter, it has a higher total cost (9)
    # than taking the path a => x => y => z =>e with
    # a lower total cost (4)
    #
    #    [a] --3--> [b ----3----> [c] --3---> [e]
    #     |                                    ^
    #     |                                    |
    #     |                                    |
    #     v--1-> [x] --1-> [y] --1-> [z] ---1--^
    #
    #
    #
    graph = {
      a: {b: 3, x: 1},
      b: {c: 3},
      c: {e: 3},
      x: {y: 1},
      y: {z: 1},
      z: {e: 1}
    }

    results = AStar.traverse(
      start: :a,
      goal: proc { |node:| node == :e },
      neighbors: proc { |node:, **| graph.fetch(node, {}).keys },

      # Look up the node in the graph and then find the neighbor, returning it's weight
      weight: proc { |node:, neighbor:| graph.fetch(node, {}).fetch(neighbor, 0) }
    )

    assert_equal [:a, :x, :y, :z, :e], results.path
    # The score is four since a => x => y => z => e totals 4
    assert_equal results.score, 4
    refute_empty results.visited
  end

  it "can solve a small maze" do
    maze = <<~EOL
      :::::::::::::::::::::
      :S  :   : :   : :   :
      ::: : : : : ::: : :::
      :   : : : : :     : :
      ::: : ::: : : ::::: :
      :     : :   :     : :
      : ::: : ::: ::: : : :
      :   :   :   :   :   :
      : ::::: ::: : : :::::
      : : : :   : : :     :
      : : : : : : ::: ::: :
      :   :   : :       : :
      ::: ::: : : ::: : : :
      :   :   :   : : : : :
      : ::::::: ::: : ::: :
      :     : :     :   : :
      : : ::: : ::::: ::: :
      : : : : : :     : : :
      ::::: : ::::: ::: : :
      :                 :E:
      :::::::::::::::::::::
    EOL

    # Turn our ascii maze into a 2d array
    maze_as_2d_grid = maze.split("\n").map(&:chars)

    # The start is at 0-based offset row 1, column 1
    start = [1, 1]

    goal = proc do |node:|
      row, col = node
      maze_as_2d_grid[row][col] == "E"
    end

    # No cost to go any direction
    weight = proc { 1 }

    neighbors = proc do |node:, **|
      # decompose the row/col
      row, col = node

      # Generate a set of new row/col neighbors
      all_neighbors = manhattan_directions.map { |delta_row, delta_col| [row + delta_row, col + delta_col] }

      # We can go anywhere that isn't a wall (":")
      all_neighbors.select { |row, col| maze_as_2d_grid[row][col] != ":" }
    end

    results = AStar.traverse(start:, goal:, weight:, neighbors:)

    expected_path = [[1, 1], [1, 2], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [5, 4], [5, 5], [6, 5], [7, 5], [7, 6], [7, 7],
      [8, 7], [9, 7], [9, 8], [9, 9], [10, 9], [11, 9], [12, 9], [13, 9], [13, 10], [13, 11], [12, 11], [11, 11], [11, 12], [11, 13],
      [11, 14], [11, 15], [10, 15], [9, 15], [9, 16], [9, 17], [9, 18], [9, 19], [10, 19], [11, 19], [12, 19], [13, 19], [14, 19],
      [15, 19], [16, 19], [17, 19], [18, 19], [19, 19]]

    assert_equal expected_path, results.path
    assert_equal results.score, expected_path.length - 1 # Score is one less than the length since this counts edges, not nodes
    refute_empty results.visited

    # Make a copy of the maze and then place an "●"
    # everywhere we traveled in the maze
    solved_maze = maze_as_2d_grid.map(&:dup)
    expected_path.each do |(row, col)|
      solved_maze[row][col] = "●"
    end

    expected_solved_maze = <<~EOL
      :::::::::::::::::::::
      :●●●:   : :   : :   :
      :::●: : : : ::: : :::
      :  ●: : : : :     : :
      :::●: ::: : : ::::: :
      :  ●●●: :   :     : :
      : :::●: ::: ::: : : :
      :   :●●●:   :   :   :
      : :::::●::: : : :::::
      : : : :●●●: : :●●●●●:
      : : : : :●: :::●:::●:
      :   :   :●:●●●●●  :●:
      ::: ::: :●:●::: : :●:
      :   :   :●●●: : : :●:
      : ::::::: ::: : :::●:
      :     : :     :   :●:
      : : ::: : ::::: :::●:
      : : : : : :     : :●:
      ::::: : ::::: ::: :●:
      :                 :●:
      :::::::::::::::::::::
    EOL

    assert_equal expected_solved_maze, solved_maze.map(&:join).join("\n") + "\n"
  end

  it "can solve a maze" do
    maze = <<~EOL
      :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      :S    :       :       :   : :                       :       : :       :     :   :
      ::: ::::: : : ::::: ::: : : : ::::: ::: ::::::: : : : : ::::: : : ::: ::::: : : :
      : :   : : : :     :     :       :     :   :   : : :   :   :   : :   :   :     : :
      : ::: : : : : ::: ::: ::::::::::: : ::::::: ::::::::: ::::::: ::: ::::: : :::::::
      : :       : :   : :   :     :   : :   : : :       : : :   :       :   :   :     :
      : : : : ::: : : ::::::::: : : ::: ::: : : : : : : : : : ::: : : : : ::: : : ::: :
      : : : :   : : :   :   :   :   : : :   :     : : : : : :     : : :   :   :   :   :
      : : ::::: ::::: : ::: : : ::: : : : ::::::: ::::: : : : ::::::: : ::: ::::::::: :
      :   :     : : : : :     :   : : : : :   :     :       : :       :   :       :   :
      : ::: : ::: : : ::: : ::: ::::: ::: ::: : : ::: : ::::::: : : : : ::: ::::: ::: :
      : : : :   :         : :         : : : :   : : : :   :   : : : : :   :     : :   :
      : : ::::: ::::: ::::: ::::: ::::: ::: ::::::: ::: ::: ::: ::::::: ::::::: ::::: :
      :   : :     :   :         : : :               :   :         :   : :   :   :     :
      ::: : : ::::: ::::::::::: : : ::: ::::: : ::::: ::::::::::::::: : ::: : ::: ::: :
      :   :     : : : :   :   : : :     :   : :   :     :     :   :         :   : : : :
      ::::::::: : ::: : ::::: : ::::::: ::: ::::::: : : : ::: ::: : ::: ::::: ::::: : :
      :     : : : :     : : : :   :   :       :   : : : : : :     : :       :   :     :
      ::: ::: : : ::: : : : : : ::: : : : ::: : ::::: ::::: ::::: ::::: ::: ::::::::: :
      :     : :   :   : :           : : : :     :     :             :   :   : :   :   :
      ::: ::: ::::::::: ::::::::: ::: ::: : ::: ::: ::::: ::::: ::: ::: ::::: ::: : :::
      : :       :             : : : :   : : :   :       :     :   :     :           : :
      : : ::: : : ::::: ::::: : : : : : : : ::::::::: ::: ::: ::: ::::::::::: : ::: : :
      :   :   : :   :       : :     : : : : :   :   :   :   : :   : :     :   : :     :
      : : ::: ::: : : : ::: : : ::::::::: : : ::::: : ::::: ::::::: ::::: ::::::: :::::
      : : : :     : : : :   :       :     : :   : :         : :         : :     :     :
      ::::: ::::: ::: : ::::: : ::: : ::::: ::: : : : ::::: : ::::: ::: : ::::: ::: :::
      :     :     : : :   :   : :   : : :   : : :   :   : : :   :   :       :     : : :
      : ::::::::: : ::::::: : : : ::::: : : : : ::::: : : : : : ::::: : ::::::: ::: : :
      :       : :   :     : : : :   :   : :   : :     : :     : : :   :         :   : :
      : : : ::: : ::: ::: ::: : ::::::: ::::: : : ::::: ::::: ::: : ::: ::::: ::::::: :
      : : :   : :     :   :   :     : : :     :   :   :   :   :   :   :   :       :   :
      : : ::: : ::::: : ::: ::::: ::: : ::: : ::::: ::::::::: : ::: : ::::::::::::: :::
      : : : :         : : :   :   :         :     : : : : :     :   :     :   :     : :
      ::: : ::::::::: ::: : ::::::::::::: : : ::: : : : : : : ::: ::: ::::: : : : ::: :
      : :   : :   :   : : :   : :   : : : : :   :     :   : : :     :   :   :   : :   :
      : : ::: : ::: : : : : : : ::: : : ::::: : ::: : : : ::: ::: ::::::::: ::::::::: :
      :       :   : : :     : :     : :     : :   : : : :   : : :             : : :   :
      : : ::: ::: ::::: ::::::::: ::: : ::::: ::::: ::: : ::: : ::: ::: ::::::: : ::: :
      : :   :     :   :   :       : :       : :         :         :   :   :   : : :   :
      : ::: ::::::: ::::: : ::::::: ::::: ::: : ::::::::: : : ::::: ::::: : ::: : ::: :
      :   : : :   : :   :           :       : :   :   :   : :   : :     : : : : : :   :
      : ::::: ::: : : ::::::: : ::::: ::::: : ::::::: ::::: : ::: : ::: ::: : : : : :::
      :       : :       : :   :     : :       : :       : : : :     : :   :     : :   :
      ::: : : : ::: ::: : ::::: : : ::: : : : : : : ::: : ::: ::::: : : : : ::: : : :::
      : : : :   : : :         : : : : : : : : : : :   :     : :   :   : :     :     : :
      : ::::: ::: ::::::::: ::::::: : ::: ::::: ::::::: ::: : : ::: : : : ::: ::: : : :
      :       : :     :     :     : :   : :     : : : : :     : :   : : : : :   : :   :
      ::: ::::: : ::::::::: : ::::: : : : ::: ::: : : : ::::: : ::: ::::: : : ::: :::::
      : :   :         : : :   :   :   :     :     : : : :   : :   : :     :   :   : : :
      : ::: ::::: : ::: : : ::: ::::: : ::: ::: : : : ::: : : : ::::: ::::::: ::::: : :
      :         : :   : :         : : :   :     :   :     : :         : : :       : : :
      ::: ::::: : : ::: ::::::: ::: ::::::::: : ::: ::: ::: : ::::::::: : ::::::::: : :
      :     : :   : :           :         : : :   :     : : :       :                 :
      ::: ::: ::::::: : : : ::: ::: ::: ::: : : : ::: : : ::::::::::::::::::: : ::::: :
      : :   : :   :   : : :   :       : :   : : :   : :   : :   :     :   :   : :   : :
      : : : : : : : ::::::::::: ::::::::::: ::::::: ::: : : : ::::: : ::: ::::: : :::::
      :   : :   : : :     :   :     : :       :     : : : :   :     : : :   :       : :
      : ::::: : ::: ::::: ::: : ::: : ::: ::::::: ::: ::: ::: ::: : ::: : ::::: ::: : :
      : :   : : :   :     :   : :     : :               : : :     : : :   :   : : :   :
      : : ::: ::::: ::: ::: : ::::::: : : ::::: : : ::::::: : : ::: : : ::: ::: : ::: :
      :     :       :       :   :   :   :     : : :     :   : : :     :         :     :
      ::: : ::: ::::: ::: ::: : : ::::::::::::: ::::::::: ::::: : ::::::::::: :::::::::
      :   : : :     :   : :   :   : :   : :     :               :   :     : :     :   :
      : : ::: : : ::: ::::: ::::::: ::: : ::: : : ::::::::: ::: : ::: ::::: ::: : : :::
      : :       : :       :     :       :   : :       :     :   : : :   :     : :     :
      : ::::::: : : ::::::::::::::: ::: ::: ::::: ::::::: ::::: ::: : ::: : ::::::: :::
      : :     : :           :   :   :   :   :   :   : : :   : :   :   :   :   :       :
      : : ::::::::: : ::::: ::: : ::: ::: : ::: : ::: : : ::: : ::::: ::: : ::::: :::::
      :     :       :   : : :       :     : : : : :   : :   : :     :     :   :       :
      : : ::::: ::::::::: ::::::::: ::::::: : : : : ::: : : : ::::: ::: : : ::: : :::::
      : :     : : :   : :     :   : :   :       :     :   : :   :     : : : : : :   : :
      ::: ::: ::: : : : ::: ::: : : : : ::::: ::::: ::::: : : ::: ::: : : ::: ::: ::: :
      : :   : : :   : :   :     : : : :   :           :   :     :   :   : :         : :
      : ::::: : ::: ::: : ::::: ::::: ::: ::::: ::::::: : ::::: ::: : : ::::: ::::: : :
      :       : :   : : : : : :         : :     : : :   : : : :   : : :   : :   : : : :
      ::: : ::: : ::: ::: : : : ::::: : : ::: ::: : : : ::: : : : ::::: ::: ::::: : : :
      :   :     :   : : : :       :   : :   :       : : :       : :   :               :
      : ::: : : : : : : : : ::::: : ::::::: ::::: ::: ::: ::::: ::::: : : ::: : : : :::
      :   : : :   :             : :   :     :     :   :     :     :     : :   : : :  E:
      :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    EOL

    # Turn our ascii maze into a 2d array
    maze_as_2d_grid = maze.split("\n").map(&:chars)

    # The start is at 0-based offset row 1, column 1
    start = [1, 1]

    goal = proc do |node:|
      row, col = node
      maze_as_2d_grid[row][col] == "E"
    end

    # No cost to go any direction
    weight = proc { 1 }

    neighbors = proc do |node:, **|
      # decompose the row/col
      row, col = node

      # Generate a set of new row/col neighbors
      all_neighbors = manhattan_directions.map { |delta_row, delta_col| [row + delta_row, col + delta_col] }

      # We can go anywhere that isn't a wall (":")
      all_neighbors.select { |row, col| maze_as_2d_grid[row][col] != ":" }
    end

    results = AStar.traverse(start:, goal:, weight:, neighbors:)

    expected_path = [[1, 1], [1, 2], [1, 3], [2, 3], [3, 3], [3, 4], [3, 5], [4, 5], [5, 5], [5, 6], [5, 7], [5, 8], [5, 9],
      [4, 9], [3, 9], [2, 9], [1, 9], [1, 10], [1, 11], [1, 12], [1, 13], [2, 13], [3, 13], [4, 13], [5, 13], [5, 14], [5, 15],
      [6, 15], [7, 15], [8, 15], [9, 15], [10, 15], [11, 15], [11, 16], [11, 17], [11, 18], [11, 19], [10, 19], [9, 19], [9, 20],
      [9, 21], [10, 21], [11, 21], [12, 21], [13, 21], [13, 22], [13, 23], [13, 24], [13, 25], [14, 25], [15, 25], [16, 25],
      [17, 25], [18, 25], [19, 25], [19, 26], [19, 27], [20, 27], [21, 27], [22, 27], [23, 27], [23, 26], [23, 25], [24, 25],
      [25, 25], [25, 24], [25, 23], [26, 23], [27, 23], [28, 23], [29, 23], [30, 23], [31, 23], [31, 22], [31, 21], [32, 21],
      [33, 21], [34, 21], [35, 21], [36, 21], [37, 21], [37, 20], [37, 19], [37, 18], [37, 17], [38, 17], [39, 17], [39, 18],
      [39, 19], [40, 19], [41, 19], [41, 20], [41, 21], [41, 22], [41, 23], [41, 24], [41, 25], [42, 25], [43, 25], [43, 26],
      [43, 27], [43, 28], [43, 29], [44, 29], [45, 29], [46, 29], [47, 29], [48, 29], [49, 29], [49, 30], [49, 31], [48, 31],
      [47, 31], [47, 32], [47, 33], [48, 33], [49, 33], [49, 34], [49, 35], [49, 36], [49, 37], [50, 37], [51, 37], [51, 38],
      [51, 39], [51, 40], [51, 41], [52, 41], [53, 41], [53, 42], [53, 43], [54, 43], [55, 43], [55, 44], [55, 45], [56, 45],
      [57, 45], [57, 44], [57, 43], [58, 43], [59, 43], [59, 42], [59, 41], [60, 41], [61, 41], [62, 41], [63, 41], [64, 41],
      [65, 41], [65, 42], [65, 43], [64, 43], [63, 43], [63, 44], [63, 45], [63, 46], [63, 47], [63, 48], [63, 49], [63, 50],
      [63, 51], [63, 52], [63, 53], [63, 54], [63, 55], [63, 56], [63, 57], [64, 57], [65, 57], [66, 57], [67, 57], [68, 57],
      [69, 57], [69, 58], [69, 59], [69, 60], [69, 61], [70, 61], [71, 61], [71, 62], [71, 63], [72, 63], [73, 63], [73, 64],
      [73, 65], [74, 65], [75, 65], [76, 65], [77, 65], [77, 66], [77, 67], [77, 68], [77, 69], [77, 70], [77, 71], [77, 72],
      [77, 73], [77, 74], [77, 75], [77, 76], [77, 77], [78, 77], [79, 77], [79, 78], [79, 79]]

    assert_equal expected_path, results.path
    assert_equal results.score, expected_path.length - 1 # Score is one less than the length since this counts edges, not nodes
    refute_empty results.visited

    # Make a copy of the maze and then place an "●"
    # everywhere we traveled in the maze
    solved_maze = maze_as_2d_grid.map(&:dup)
    expected_path.each do |(row, col)|
      solved_maze[row][col] = "●"
    end

    expected_solved_maze = <<~EOL
      :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      :●●●  :  ●●●●●:       :   : :                       :       : :       :     :   :
      :::●:::::●: :●::::: ::: : : : ::::: ::: ::::::: : : : : ::::: : : ::: ::::: : : :
      : :●●●: :●: :●    :     :       :     :   :   : : :   :   :   : :   :   :     : :
      : :::●: :●: :●::: ::: ::::::::::: : ::::::: ::::::::: ::::::: ::: ::::: : :::::::
      : :  ●●●●●: :●●●: :   :     :   : :   : : :       : : :   :       :   :   :     :
      : : : : ::: : :●::::::::: : : ::: ::: : : : : : : : : : ::: : : : : ::: : : ::: :
      : : : :   : : :●  :   :   :   : : :   :     : : : : : :     : : :   :   :   :   :
      : : ::::: :::::●: ::: : : ::: : : : ::::::: ::::: : : : ::::::: : ::: ::::::::: :
      :   :     : : :●: :●●●  :   : : : : :   :     :       : :       :   :       :   :
      : ::: : ::: : :●:::●:●::: ::::: ::: ::: : : ::: : ::::::: : : : : ::: ::::: ::: :
      : : : :   :    ●●●●●:●:         : : : :   : : : :   :   : : : : :   :     : :   :
      : : ::::: ::::: :::::●::::: ::::: ::: ::::::: ::: ::: ::: ::::::: ::::::: ::::: :
      :   : :     :   :    ●●●●●: : :               :   :         :   : :   :   :     :
      ::: : : ::::: :::::::::::●: : ::: ::::: : ::::: ::::::::::::::: : ::: : ::: ::: :
      :   :     : : : :   :   :●: :     :   : :   :     :     :   :         :   : : : :
      ::::::::: : ::: : ::::: :●::::::: ::: ::::::: : : : ::: ::: : ::: ::::: ::::: : :
      :     : : : :     : : : :●  :   :       :   : : : : : :     : :       :   :     :
      ::: ::: : : ::: : : : : :●::: : : : ::: : ::::: ::::: ::::: ::::: ::: ::::::::: :
      :     : :   :   : :      ●●●  : : : :     :     :             :   :   : :   :   :
      ::: ::: ::::::::: :::::::::●::: ::: : ::: ::: ::::: ::::: ::: ::: ::::: ::: : :::
      : :       :             : :●: :   : : :   :       :     :   :     :           : :
      : : ::: : : ::::: ::::: : :●: : : : : ::::::::: ::: ::: ::: ::::::::::: : ::: : :
      :   :   : :   :       : :●●●  : : : : :   :   :   :   : :   : :     :   : :     :
      : : ::: ::: : : : ::: : :●::::::::: : : ::::: : ::::: ::::::: ::::: ::::::: :::::
      : : : :     : : : :   :●●●    :     : :   : :         : :         : :     :     :
      ::::: ::::: ::: : :::::●: ::: : ::::: ::: : : : ::::: : ::::: ::: : ::::: ::: :::
      :     :     : : :   :  ●: :   : : :   : : :   :   : : :   :   :       :     : : :
      : ::::::::: : ::::::: :●: : ::::: : : : : ::::: : : : : : ::::: : ::::::: ::: : :
      :       : :   :     : :●: :   :   : :   : :     : :     : : :   :         :   : :
      : : : ::: : ::: ::: :::●: ::::::: ::::: : : ::::: ::::: ::: : ::: ::::: ::::::: :
      : : :   : :     :   :●●●:     : : :     :   :   :   :   :   :   :   :       :   :
      : : ::: : ::::: : :::●::::: ::: : ::: : ::::: ::::::::: : ::: : ::::::::::::: :::
      : : : :         : : :●  :   :         :     : : : : :     :   :     :   :     : :
      ::: : ::::::::: ::: :●::::::::::::: : : ::: : : : : : : ::: ::: ::::: : : : ::: :
      : :   : :   :   : : :●  : :   : : : : :   :     :   : : :     :   :   :   : :   :
      : : ::: : ::: : : : :●: : ::: : : ::::: : ::: : : : ::: ::: ::::::::: ::::::::: :
      :       :   : : :●●●●●: :     : :     : :   : : : :   : : :             : : :   :
      : : ::: ::: :::::●::::::::: ::: : ::::: ::::: ::: : ::: : ::: ::: ::::::: : ::: :
      : :   :     :   :●●●:       : :       : :         :         :   :   :   : : :   :
      : ::: ::::::: :::::●: ::::::: ::::: ::: : ::::::::: : : ::::: ::::: : ::: : ::: :
      :   : : :   : :   :●●●●●●●    :       : :   :   :   : :   : :     : : : : : :   :
      : ::::: ::: : : ::::::: :●::::: ::::: : ::::::: ::::: : ::: : ::: ::: : : : : :::
      :       : :       : :   :●●●●●: :       : :       : : : :     : :   :     : :   :
      ::: : : : ::: ::: : ::::: : :●::: : : : : : : ::: : ::: ::::: : : : : ::: : : :::
      : : : :   : : :         : : :●: : : : : : : :   :     : :   :   : :     :     : :
      : ::::: ::: ::::::::: :::::::●: ::: ::::: ::::::: ::: : : ::: : : : ::: ::: : : :
      :       : :     :     :     :●:●●●: :     : : : : :     : :   : : : : :   : :   :
      ::: ::::: : ::::::::: : :::::●:●:●: ::: ::: : : : ::::: : ::: ::::: : : ::: :::::
      : :   :         : : :   :   :●●●:●●●●●:     : : : :   : :   : :     :   :   : : :
      : ::: ::::: : ::: : : ::: ::::: : :::●::: : : : ::: : : : ::::: ::::::: ::::: : :
      :         : :   : :         : : :   :●●●●●:   :     : :         : : :       : : :
      ::: ::::: : : ::: ::::::: ::: ::::::::: :●::: ::: ::: : ::::::::: : ::::::::: : :
      :     : :   : :           :         : : :●●●:     : : :       :                 :
      ::: ::: ::::::: : : : ::: ::: ::: ::: : : :●::: : : ::::::::::::::::::: : ::::: :
      : :   : :   :   : : :   :       : :   : : :●●●: :   : :   :     :   :   : :   : :
      : : : : : : : ::::::::::: ::::::::::: :::::::●::: : : : ::::: : ::: ::::: : :::::
      :   : :   : : :     :   :     : :       :  ●●●: : : :   :     : : :   :       : :
      : ::::: : ::: ::::: ::: : ::: : ::: :::::::●::: ::: ::: ::: : ::: : ::::: ::: : :
      : :   : : :   :     :   : :     : :      ●●●      : : :     : : :   :   : : :   :
      : : ::: ::::: ::: ::: : ::::::: : : :::::●: : ::::::: : : ::: : : ::: ::: : ::: :
      :     :       :       :   :   :   :     :●: :     :   : : :     :         :     :
      ::: : ::: ::::: ::: ::: : : :::::::::::::●::::::::: ::::: : ::::::::::: :::::::::
      :   : : :     :   : :   :   : :   : :    ●:●●●●●●●●●●●●●●●:   :     : :     :   :
      : : ::: : : ::: ::::: ::::::: ::: : ::: :●:●::::::::: :::●: ::: ::::: ::: : : :::
      : :       : :       :     :       :   : :●●●    :     :  ●: : :   :     : :     :
      : ::::::: : : ::::::::::::::: ::: ::: ::::: ::::::: :::::●::: : ::: : ::::::: :::
      : :     : :           :   :   :   :   :   :   : : :   : :●  :   :   :   :       :
      : : ::::::::: : ::::: ::: : ::: ::: : ::: : ::: : : ::: :●::::: ::: : ::::: :::::
      :     :       :   : : :       :     : : : : :   : :   : :●●●●●:     :   :       :
      : : ::::: ::::::::: ::::::::: ::::::: : : : : ::: : : : :::::●::: : : ::: : :::::
      : :     : : :   : :     :   : :   :       :     :   : :   :  ●●●: : : : : :   : :
      ::: ::: ::: : : : ::: ::: : : : : ::::: ::::: ::::: : : ::: :::●: : ::: ::: ::: :
      : :   : : :   : :   :     : : : :   :           :   :     :   :●●●: :         : :
      : ::::: : ::: ::: : ::::: ::::: ::: ::::: ::::::: : ::::: ::: : :●::::: ::::: : :
      :       : :   : : : : : :         : :     : : :   : : : :   : : :●  : :   : : : :
      ::: : ::: : ::: ::: : : : ::::: : : ::: ::: : : : ::: : : : :::::●::: ::::: : : :
      :   :     :   : : : :       :   : :   :       : : :       : :   :●●●●●●●●●●●●●  :
      : ::: : : : : : : : : ::::: : ::::::: ::::: ::: ::: ::::: ::::: : : ::: : : :●:::
      :   : : :   :             : :   :     :     :   :     :     :     : :   : : :●●●:
      :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    EOL

    assert_equal expected_solved_maze, solved_maze.map(&:join).join("\n") + "\n"
  end

  it "can find any of multiple optimal paths (with heuristics)" do
    # From: https://github.com/networkx/networkx/blob/main/networkx/algorithms/shortest_paths/tests/test_astar.py

    heuristic_values = {a: 1.35, b: 1.18, c: 0.67, d: 0}

    edges_and_weights = {
      a: {b: 0.18, c: 0.68},
      b: {c: 0.50},
      c: {d: 0.67}
    }

    results = AStar.traverse(
      start: :a,
      goal: proc { |node:| node == :d },
      neighbors: proc { |node:, **| edges_and_weights.fetch(node, {}).keys },
      weight: proc { |node:, neighbor:| edges_and_weights.fetch(node, {}).fetch(neighbor, 0) },
      heuristic: proc { |node:| heuristic_values.fetch(node, 0) }
    )

    assert_equal [:a, :c, :d], results.path
    assert_equal 0.68 + 0.67, results.score # (a=>c 0.68) + (c=>d 0.67)
    refute_empty results.visited
  end

  it "Tests that A* finds correct path when multiple paths exist and the best one is not expanded first" do
    heuristic_values = {n5: 36, n2: 4, n1: 0, n0: 0}

    edges_and_weights = {
      n5: {n1: 11, n2: 9},
      n2: {n1: 1},
      n1: {n0: 32}
    }

    results = AStar.traverse(
      start: :n5,
      goal: proc { |node:| node == :n0 },
      neighbors: proc { |node:, **| edges_and_weights.fetch(node, {}).keys },
      weight: proc { |node:, neighbor:| edges_and_weights.fetch(node, {}).fetch(neighbor, 0) },
      heuristic: proc { |node:| heuristic_values.fetch(node, 0) }
    )

    assert_equal [:n5, :n2, :n1, :n0], results.path
  end

  def manhattan_directions
    [
      [+0, -1], # left
      [+0, +1], # right
      [-1, +0], # up
      [+1, +0]  # down
    ]
  end
end
