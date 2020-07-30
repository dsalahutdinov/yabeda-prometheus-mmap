# frozen_string_literal: true

require 'rack'
require 'prometheus/client/rack/collector'
require 'prometheus/client/rack/exporter'

module Yabeda
  module Prometheus
    module Mmap
      # Rack application or middleware that provides metrics exposition endpoint
      class Exporter < ::Prometheus::Client::Rack::Exporter
        NOT_FOUND_HANDLER = lambda do |_env|
          [404, { 'Content-Type' => 'text/plain' }, ["Not Found\n"]]
        end.freeze

        class << self
          # Allows to use middleware as standalone rack application
          def call(env)
            @app ||= new(NOT_FOUND_HANDLER, path: '/')
            @app.call(env)
          end

          def start_metrics_server!
            Thread.new do
              default_port = ENV.fetch('PORT', 9394)
              Rack::Handler::WEBrick.run(
                rack_app,
                Host: ENV['PROMETHEUS_EXPORTER_BIND'] || '0.0.0.0',
                Port: ENV.fetch('PROMETHEUS_EXPORTER_PORT', default_port),
                AccessLog: []
              )
            end
          end

          def rack_app(exporter = self, path: '/metrics')
            Rack::Builder.new do
              use Rack::CommonLogger
              use Rack::ShowExceptions
              use exporter, path: path
              run NOT_FOUND_HANDLER
            end
          end
        end

        def initialize(app, options = {})
          super(app, options.merge(registry: Yabeda::Prometheus::Mmap.registry))
        end

        def call(env)
          Yabeda.collectors.each(&:call) if env['PATH_INFO'] == path
          super
        end
      end
    end
  end
end
