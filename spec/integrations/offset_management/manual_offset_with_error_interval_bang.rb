# frozen_string_literal: true

# When manual offset management is on, upon error Karafka should start again from the place
# it had in the checkpoint, not from the beginning. We check here that this works well when we
# commit "from time to time", not every message

setup_karafka do |config|
  config.manual_offset_management = true
end

elements = Array.new(100) { SecureRandom.uuid }

class Consumer < Karafka::BaseConsumer
  def consume
    @consumed ||= 0

    messages.each do |message|
      @consumed += 1

      raise StandardError if @consumed == 50

      # After 25 we should mark as consumed
      mark_as_consumed!(message) if @consumed == 24

      DataCollector.data[0] << message.raw_payload
    end
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
  DataCollector.data[0].size >= 125
end

# We need unique as due to error and manual offset, some will be duplicated
assert_equal elements, DataCollector.data[0].uniq
assert_equal 125, DataCollector.data[0].size
assert_equal 1, DataCollector.data.size