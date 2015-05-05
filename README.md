# RabbitMQ Queue Stats to CloudWatch
Currently fetches messages ready and unacknowledged messages stats from RabbitMQ and posts to CloudWatch
## Requirements
* RabbitMQ
* Ruby
* Sidekiq
* Redis
* AWS account with user having CloudWatch perms

## Usage
1. Start Redis
2. Start sidekiq: `sidekiq -r ./rabbitmq_queue.rb`
