require "forwardable"

module AStar
  # Simple priority queue to use with the `traverse` method.
  #
  # This is not terribly efficient, but it is not horribly inefficient
  # either. It implements only the bare minimum required to support our
  # priority queue needs.
  class PriorityQueue # :nodoc:
    extend Forwardable

    # Note, #include? may be very slow for large queues since it performs
    # a linear search. Without adding a secondary index (say defining a
    # set of all queue elements) we cannot speed this up.
    def_delegators :@queue, :pop, :empty?, :include?

    def initialize(&block)
      @queue = []
      @comparator = block
    end

    def push(element)
      @queue.insert(binary_index(element), element)

      self
    end

    private

    def binary_index(element)
      upper = @queue.size - 1
      lower = 0

      while upper >= lower
        index = lower + (upper - lower) / 2
        comp = @comparator.call(element, @queue[index])

        case comp
        when 0, nil
          return index
        when 1, true
          lower = index + 1
        when -1, false
          upper = index - 1
        end
      end
      lower
    end
  end
end
