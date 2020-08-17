# frozen_string_literal: true

require 'lights'

# Main entrypoint for home automation server
class Beta
  class UndefinedSwitchError < RuntimeError; end

  HUE_USERNAME = ENV['HUE_USERNAME']
  HUE_IP = '10.0.0.71'

  SWITCHES = {
    studio: { 'uniqueid' => '00:00:00:00:00:47:12:96-f2' }.freeze
  }.freeze

  BUTTONS = {
    34 => :off,
    16 => :two,
    17 => :three,
    18 => :four
  }

  attr_reader :client

  def initialize
    @client = Lights.new(HUE_IP, HUE_USERNAME)
    @sensors = {}
    start_sensor_loop!
  end

  def update_sensors!
    old_sensors = @sensors
    updated_sensors = {}
    new_sensors = client.request_sensor_list
    SWITCHES.each do |name, selector|
      updated_sensors[name] = new_sensors.values.find do |hash|
        selector.all? { |key, value| hash[key] == value }
      end
    end
    @sensors = updated_sensors

    old_sensors.each do |name, hash|
      if updated_sensors[name]
        if hash["state"]["lastupdated"] != updated_sensors[name]["state"]["lastupdated"]
          sensor_state_change!(
            name, old_state: old_sensors[name], new_state: updated_sensors[name]
          )
        end
      end
    end
  end

  def start_sensor_loop!
    Thread.new do
      loop do
        update_sensors!
        sleep 0.2
      end
    end
  end

  def sensors
    client.request_sensor_list
  end

  def sensor_state_change!(name, old_state:, new_state:)
    message = "Button pressed! switch=#{name} button=#{BUTTONS[new_state["state"]["buttonevent"]]}"
    `say #{message}`
    puts message
  end

  def switch(name)
    raise UndefinedSwitchError("No switch named #{name} defined.") unless SWITCHES[name]

    switch_selector = SWITCHES[name]
    sensors.find do |_id, hash|
      switch_selector.all? do |key, value|
        hash[key] == value
      end
    end
  end
end
