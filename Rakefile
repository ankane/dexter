require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test

namespace :docker do
  task :release do
    require_relative "lib/dexter/version"

    system "docker build --pull --no-cache --platform linux/amd64 -t ankane/dexter:latest .", exception: true
    system "docker build --platform linux/amd64 -t ankane/dexter:v#{Dexter::VERSION} .", exception: true

    # TODO solve error with google-protobuf
    # system "docker buildx build --push --pull --no-cache --platform linux/amd64,linux/arm64 -t ankane/dexter:latest .", exception: true
    # system "docker buildx build --push --platform linux/amd64,linux/arm64 -t ankane/dexter:v#{Dexter::VERSION} .", exception: true
  end
end

namespace :bench do
  task :find_columns do
    require "benchmark/ips"
    require "dexter"

    indexer = Dexter::Indexer.new({})
    query = Dexter::Query.new("SELECT * FROM posts WHERE user_id = 1 ORDER BY blog_id LIMIT 1000")
    Benchmark.ips do |x|
      x.report("find_columns") do
        indexer.send(:find_columns, query.tree)
      end
    end
  end
end
