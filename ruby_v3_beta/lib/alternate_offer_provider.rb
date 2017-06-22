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
class AlternateOfferProvider
  attr_reader :service_name

  def initialize(host_ip, port)
    rapids_connection = RapidsRivers::RabbitMqRapids.new(host_ip, port)
    @river = RapidsRivers::RabbitMqRiver.new(rapids_connection)
    @service_name = 'alternate_offer_provider_ruby_' + SecureRandom.uuid
  end

  def start
    puts " [*] #{@service_name} waiting for traffic on RabbitMQ event bus ... To exit press CTRL+C"
    @river.register(self)
  end

  def packet rapids_connection, packet, warnings
    if relevant?(packet)
      puts  "looking for rental_need"
      puts " [>] Received a rental offer need on the bus:\n\t     #{packet.to_json}"

      publish_solution(rapids_connection, packet)
    end
  end

  def on_error rapids_connection, errors
    puts " [x] #{errors}"
  end

  private

  def get_solution(packet)
    RapidsRivers::Packet.new(
      "car_rental_offer" => offer_message,
      "cost" => "#{cost} EUR/day",
      "uuid" => message_key(packet, 'uuid')
    )
  end

  def publish_solution(rapids_connection, packet)
    sol = get_solution(packet)
    puts " [<] Published a rental offer the bus:\n\t     #{sol.to_json}"
    rapids_connection.publish sol
  end

  # def offer_solution
  #   RapidsRivers::Packet.new("car_rental_offer" => "a shiny car rental offer for you.", "cost" => "#{cost} EUR/day")
  # end

  def relevant?(packet)
    # packet.instance_variable_get("@json_hash")["need"] == "car_rental_offer"
    message_key(packet, 'need') == "car_rental_offer"
  end

  def message_key(packet, key)
    packet.instance_variable_get("@json_hash")[key]
  end


  def cost
    45
  end

  def offer_message
    "a bland car rental offer for you."
  end

end

AlternateOfferProvider.new(ARGV.shift, ARGV.shift).start
