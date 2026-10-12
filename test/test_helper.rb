# The plugin's tests run inside a Runwell checkout, whose own tests don't load plugins. From
# Runwell's directory, with this plugin linked (bin/rails "plugins:link[path]"):
#
#   bin/rails test path/to/market/test
#
# This loads the plugin before Runwell boots, runs Runwell's test setup (fixtures, sign_in_as),
# then adds the plugin's tables to the test database.
ENV["RAILS_ENV"] = "test"
ENV["PARALLEL_WORKERS"] ||= "1"
runwell = ENV.fetch("RUNWELL", Dir.pwd)

require File.join(runwell, "config/boot")
require "rails"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "market"
require File.join(runwell, "test/test_helper")

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.connection_pool.then do |pool|
  ActiveRecord::MigrationContext.new([ File.expand_path("../db/migrate", __dir__) ], pool.schema_migration, pool.internal_metadata).migrate
end

module Market
  module TestHelpers
    # A Probe that answers these facts without the network.
    FakeProbe = Struct.new(:domain, :facts)

    def facts(domain: "rival.example", pages: 40, posts: 10, tools: %w[google_analytics], title: "Rival Plumbing", locations: 2)
      { "domain" => domain,
        "home_page" => { "title" => title, "headings" => [ "Plumbers you can trust" ], "platform" => "WordPress", "tools" => tools,
                         "socials" => { "facebook" => "https://facebook.com/rival" }, "schema_types" => [ "Plumber" ], "words" => 900 },
        "sitemap" => { "pages" => pages, "posts" => posts, "locations" => locations, "services" => 6, "posts_last_90_days" => 3, "last_changed" => "2026-10-01" } }
    end

    def read(subject, **options)
      Snapshot.take(subject, probe: FakeProbe.new(subject.domain, facts(domain: subject.domain, **options)))
    end

    # The AI plugin's Ai.structured, answering `answer`, for the length of the block.
    def with_ai(answer)
      defined_here = !defined?(::Ai)
      Object.const_set(:Ai, Module.new) if defined_here
      ai = ::Ai.singleton_class
      saved = %i[structured available_for?].select { ai.method_defined?(it) }.to_h { [ it, ::Ai.method(it) ] }
      ai.define_method(:available_for?) { |*| true }
      ai.define_method(:structured) { |**request| answer.respond_to?(:call) ? answer.call(request) : answer }
      yield
    ensure
      if defined_here
        Object.send(:remove_const, :Ai)
      else
        saved.each { |name, method| ai.define_method(name, method) }
      end
    end
  end
end

ActiveSupport::TestCase.include Market::TestHelpers
ActionDispatch::IntegrationTest.include Market::TestHelpers
