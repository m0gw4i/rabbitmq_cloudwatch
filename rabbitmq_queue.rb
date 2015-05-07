require 'httparty'
require 'fog/aws'
require 'yaml'
require 'sidekiq'

$config = YAML.load_file(File.expand_path('config.yaml' , __FILE__))

Sidekiq.configure_server do |config|
  config.redis = { :namespace => 'x' }
end

class RabbitQueue
  include HTTParty
  rabbit_host = $config['rabbit_host']
  rabbit_port = $config['rabbit_port']
  base_uri "#{rabbit_host}:#{rabbit_port}/api"
  
  def initialize(u, p)
    @rabbit_vhost = $config['rabbit_vhost']
    @rabbit_queue = $config['rabbit_queue']
    @auth = {username: u, password: p}
  end

  def get_queue(options = {})
  	options.merge!( { basic_auth: @auth } )
  	self.class.get("/queues/#{@rabbit_vhost}/#{@rabbit_queue}", options)
  	
  end

  def messages_ready()
  	q = get_queue()
  	return { messages_ready: q['messages_ready'] }
  end

  def messages_unacked()
  	q = get_queue()
  	return { messages_unacked: q['messages_unacknowledged'] }
  end
end

class HardWorker
  include Sidekiq::Worker
  
  def initialize()
    aws_access = $config['aws_access_key_id']
    aws_secret = $config['aws_secret_access_key']
    @r_user = $config['rabbitmq_user']
    @r_pass = $config['rabbitmq_pass']
  	@cw = Fog::AWS::CloudWatch.new(
			{
				:aws_access_key_id => aws_access, 
				:aws_secret_access_key => aws_secret 
			}
		)
  end
	def perform()
    while true do
			r = RabbitQueue.new(@r_user, @r_pass)
			rr = r.messages_ready()
			ra = r.messages_unacked
			rq = rr.merge(ra)

			@cw.put_metric_data('RabbitMQ', [ 
				{ 'MetricName' => 'messages_ready', 'Unit' => 'Count', 'Value' => rq[:messages_ready] },
				{ 'MetricName' => 'messages_unacked', 'Unit' => 'Count', 'Value' => rq[:messages_unacked] }
			])
      sleep 5
    end
	end
end
HardWorker.perform_async()