require "znet_local_to_statsd/version"
require 'json'
require "net/http"
require 'uri'
require 'statsd-ruby'

module ZnetLocalToStatsd

  STATSD_NAMESPACE = "tellstick"

  class << self
    def run
      @stick_address = ENV['STICK_ADDRESS'] || "tellstick"
      @file_path = ENV['TOKEN_LOCATION'] || "#{Dir.home}/.tellstick_token"
      $statsd = Statsd.new((ENV['STATSD_ADDR'] || 'localhost'), (ENV['STATSD_PORT'] || '8125'))

      while true
        poll_sensors
        sleep(ENV['SLEEP_DURATION']|| 5)
      end
    end

    private

    def token
      @token ||= get_token
    end

    def get_token
      token = read_from_config
      return token if test_token(token)

      request_token = request_request_token
      access_token = exchange_request_token_to_access_token(request_token)
      raise StandardError, "New token didn't work for test request, please try again'" unless test_token(access_token)
      File.open(@filepath, 'w') { |file| file.write(access_token) }
      access_token
    end

    def read_from_config
      return "" unless File.exists?(@file_path)
      File.open(@file_path, "r").readlines[0].chomp
    end

    def test_token(access_token)
      return false if access_token == ""
      @token = access_token
      response = make_request_with_token("/api/devices/list")
      response.code.to_i == 200 ? true : false
    end

    def request_request_token
      # FIXME parametrize
      uri = URI.parse("http://#{@stick_address}/api/token")
      app_id = " ZnetLocalToStatsd"
      http = Net::HTTP.new(uri.hostname, uri.port)
      response = http.send_request('PUT', uri.path, "app=#{app_id}")
      raise StandardError, "Token request failed, #{response.code} / #{response.body}" if response.code.to_i != 200

      parsed_body = JSON.parse(response.body)
      puts "Please auth the app at #{parsed_body['authUrl']}"
      puts "When you have finished auth press enter"
      $stdin.gets
      return parsed_body['token']
    end

    def exchange_request_token_to_access_token(request_token)
      uri = URI.parse("http://#{@stick_address}/api/token?token=#{request_token}")
      uri.query = URI.encode_www_form( { :token => request_token } )
      http = Net::HTTP.new(uri.hostname, uri.port)
      response = http.send_request('GET', uri)
      raise StandardError, "Token exchange failed, #{response.body}" if response.code.to_i != 200

      JSON.parse(response.body)['token']
    end

    def make_request_with_token(path, params={})
      uri = URI.parse("http://#{@stick_address}#{path}")
      uri.query = URI.encode_www_form( params )
      req = Net::HTTP::Get.new(uri)
      req.add_field('Authorization', "Bearer #{token}")
      response = Net::HTTP.new(uri.host, uri.port).start do |http|
        http.request(req)
      end
      response
    end

    def poll_sensors
      get_sensors.each do |sensor|
        send_sensor_data_to_statsd(sensor['id'])
      end
    end

    def get_sensors
      JSON.parse(make_request_with_token("/api/sensors/list").body)['sensor']
    end

    def send_sensor_data_to_statsd(sensor_id)
      response = JSON.parse(make_request_with_token("/api/sensor/info", { 'id' => sensor_id}).body)
      name = response['name']
      metrics = response['data'].sort_by! { |metric| metric['name']}

      previous_value = ""
      metrics.each_with_index do |metric, i|
        # Ugly hack to work around sensors that use same name for multiple things (eg. philio power meter)
        metric['name'] == previous_value ? index = i : index = ""

        # tellstick.sensorX.temp(N)
        statsd_metric = "#{STATSD_NAMESPACE}.#{name}.#{metric['name']}#{index}"
        puts("#{statsd_metric} #{metric['value']}")
        $statsd.gauge(statsd_metric, metric['value'])
        previous_value = metric['name']
      end
    end
  end
end
