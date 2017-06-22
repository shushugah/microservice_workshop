#!/usr/bin/env ruby
# encoding: utf-8

# Copyright (c) 2017 by Fred George.
# May be used freely except for training; license required for training.

# For debugging...
# require 'pry'
# require 'pry-nav'

require 'securerandom'
require 'rapids_rivers'

# Understands the complete stream of messages on an event bus
class SolutionCollector
  attr_reader :service_name

  def initialize(host_ip, port)
    rapids_connection = RapidsRivers::RabbitMqRapids.new(host_ip, port)
    @river = RapidsRivers::RabbitMqRiver.new(rapids_connection)
    @service_name = 'solution_collector_ruby_' + SecureRandom.uuid

    @best_solutions = {} # { uuid => cost }
  end

  def start
    puts " [*] #{@service_name} waiting for traffic on RabbitMQ event bus ... To exit press CTRL+C"
    @river.register(self)
  end

  def packet rapids_connection, packet, warnings
    # puts " [*] #{warnings}"

    return unless relevant?(packet)

    uuid = uuid(packet)
    new_cost = cost(packet)

    # binding.pry
    unless @best_solutions[uuid].nil?
      old_cost = @best_solutions[uuid]

      # trying to find cheapest for this need
      if old_cost > new_cost
        @best_solutions[uuid] = new_cost

        puts "better offer : #{packet.to_s}"
      end
    else
      # first offer
      @best_solutions[uuid] = new_cost
      puts "new offer : #{packet.to_s}"
    end
  end

  def on_error rapids_connection, errors
    puts " [x] #{errors}"
  end

  private

  def relevant?(packet)
    !packet.instance_variable_get("@json_hash")['car_rental_offer'].nil?
  end

  def cost(packet)
    packet.instance_variable_get("@json_hash")['cost'].split(" ").first.to_i
  end


  def uuid(packet)
    packet.instance_variable_get("@json_hash")['uuid']
  end
end

SolutionCollector.new(ARGV.shift, ARGV.shift).start
