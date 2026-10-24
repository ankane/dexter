require "minitest/autorun"
require_relative "../lib/dexter"

class CollectorTest < Minitest::Test
  class ObservedMutex
    attr_reader :entered

    def initialize
      @mutex = Mutex.new
      @entered = Queue.new
    end

    def synchronize
      @entered << true
      @mutex.synchronize { yield }
    end
  end

  def test_add_waits_until_fetch_finishes_iterating_queries
    collector = Dexter::Collector.new(min_time: 0, min_calls: 0)
    first = "SELECT * FROM posts WHERE id = 1"
    second = "SELECT * FROM users WHERE id = 1"
    concurrent = "SELECT * FROM comments WHERE id = 1"
    collector.add(first, 1)
    collector.add(second, 1)

    mutex = ObservedMutex.new
    collector.instance_variable_set(:@mutex, mutex)
    query_entered = Queue.new
    release_query = Queue.new
    first_results = Queue.new
    errors = Queue.new
    query_class = Dexter::Query
    original_new = query_class.method(:new)
    singleton = query_class.singleton_class
    singleton.define_method(:new) do |*args, **kwargs|
      if Thread.current[:pause_dexter_query_new]
        Thread.current[:pause_dexter_query_new] = false
        query_entered << true
        release_query.pop
      end
      original_new.call(*args, **kwargs)
    end

    reader = Thread.new do
      begin
        Thread.current[:pause_dexter_query_new] = true
        first_results << collector.fetch_queries
      rescue StandardError => error
        errors << error
      end
    end
    mutex.entered.pop
    query_entered.pop

    writer = Thread.new do
      begin
        collector.add(concurrent, 1)
      rescue StandardError => error
        errors << error
      end
    end
    mutex.entered.pop

    fingerprint = PgQuery.fingerprint(concurrent)
    refute collector.instance_variable_get(:@top_queries).key?(fingerprint)

    release_query << true
    reader.join
    writer.join
    raise errors.pop unless errors.empty?

    assert_equal [first, second].sort, first_results.pop.map(&:statement).sort
    assert_equal [concurrent], collector.fetch_queries.map(&:statement)
  ensure
    release_query << true if release_query && reader&.alive?
    reader&.join
    writer&.join
    singleton&.define_method(:new, original_new) if singleton && original_new
  end
end
