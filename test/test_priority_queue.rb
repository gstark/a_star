require "test_helper"

describe AStar::PriorityQueue do
  person = Data.define(:name, :age)

  it "can store an element" do
    queue = AStar::PriorityQueue.new { |person_a, person_b| person_a.age < person_b.age }

    queue.push(person.new(name: "Sally Jones", age: 12))
  end

  it "can store multiple elements in increasing order based on a comparator" do
    # define a comparator that yields the *youngest* person first
    queue = AStar::PriorityQueue.new { |person_a, person_b| person_a.age < person_b.age }

    queue.push(person.new(name: "Sally Jones", age: 12))
    queue.push(person.new(name: "Adam Smith", age: 18))
    queue.push(person.new(name: "Betty Parsons", age: 5))
    queue.push(person.new(name: "John Doe", age: 9))

    # These should be popped in order of increasing age
    # based on how we defined our comparator
    assert_equal "Betty Parsons", queue.pop.name
    assert_equal "John Doe", queue.pop.name
    assert_equal "Sally Jones", queue.pop.name
    assert_equal "Adam Smith", queue.pop.name
  end

  it "can store multiple elements in decreasing order based on a comparator" do
    # define a comparator that yields the *oldest* person first
    queue = AStar::PriorityQueue.new { |person_a, person_b| person_a.age > person_b.age }

    queue.push(person.new(name: "Sally Jones", age: 12))
    queue.push(person.new(name: "Adam Smith", age: 18))
    queue.push(person.new(name: "Betty Parsons", age: 5))
    queue.push(person.new(name: "John Doe", age: 9))

    # These should be popped in order of DECREASING age
    # based on how we defined our comparator
    assert_equal "Adam Smith", queue.pop.name
    assert_equal "Sally Jones", queue.pop.name
    assert_equal "John Doe", queue.pop.name
    assert_equal "Betty Parsons", queue.pop.name
  end

  it "will return nil if no elements are available to pop" do
    queue = AStar::PriorityQueue.new { |person_a, person_b| person_a.age < person_b.age }

    queue.push(person.new(name: "Sally Jones", age: 12))

    assert_equal "Sally Jones", queue.pop.name
    assert_nil queue.pop
  end

  it "can determine if an element is in the queue" do
    queue = AStar::PriorityQueue.new { |person_a, person_b| person_a.age < person_b.age }

    sally = person.new(name: "Sally Jones", age: 12)
    john = person.new(name: "John Doe", age: 9)

    queue.push(sally)

    assert queue.include?(sally)
    refute queue.include?(john)
  end

  it "can determine if the queue is empty" do
    queue = AStar::PriorityQueue.new { |person_a, person_b| person_a.age < person_b.age }

    assert queue.empty?

    queue.push(person.new(name: "Sally Jones", age: 12))

    refute queue.empty?

    queue.pop

    assert queue.empty?
  end
end
