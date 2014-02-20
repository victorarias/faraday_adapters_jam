URL = "http://secure-earth-8451.herokuapp.com/foo.json"

require 'benchmark'
require 'faraday'
require 'faraday_middleware'
require 'em-synchrony'

class Tester
  attr_reader :client

  def initialize
    @client = Faraday.new(URL) do |faraday|
      middleware_init(faraday)
    end
  end

  def perform
    1.upto 20 do
      response = client.get

      raise 'Invalid status' if response.status != 200
      raise 'Invalid body' if response.body["ok"] != true
    end
  end

  def middleware_init(faraday)
    faraday.request :json
    faraday.response :json

    middleware_hook(faraday)
  end

  def middleware_hook(faraday)
    raise 'override me'
  end
end

class FaradayDefault < Tester
  def middleware_hook(faraday)
    faraday.adapter Faraday.default_adapter
  end
end

class FaradayPersistent < Tester
  def middleware_hook(faraday)
    faraday.adapter :net_http_persistent
  end
end

class FaradayEM < Tester
  def perform
    client.in_parallel do
      1.upto 20 do
        response = client.get
        response.on_complete do
          raise 'Invalid status' if response.status != 200
          raise 'Invalid body' if response.body["ok"] != true
        end
      end
    end
  end

  def middleware_hook(faraday)
    faraday.adapter :em_synchrony
  end
end

Benchmark.bm do |x|
  x.report("default") { FaradayDefault.new.perform }
  x.report("keep-alive") { FaradayPersistent.new.perform }
  x.report("em") { FaradayEM.new.perform }
end
