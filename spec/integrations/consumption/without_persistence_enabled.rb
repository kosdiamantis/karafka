# frozen_string_literal: true

# Karafka should not use same consumer instance when consumer_persistence is set to false
# Each batch of data should be consumed with new instance

setup_karafka do |config|
  config.consumer_persistence = false
  config.max_messages = 1
end

elements = Array.new(100) { SecureRandom.uuid }

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector.data[0] << object_id
  end
end

Karafka::App.routes.draw do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
    end
  end
end

elements.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 100
end

assert_equal 100, DataCollector.data[0].size