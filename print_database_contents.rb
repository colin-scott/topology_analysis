#!/usr/bin/env ruby

require_relative 'lib/neo4j.rb'
require_relative 'lib/topology_entities.rb'

if $0 == __FILE__
  g = GraphDatabase.new
  g.select_all_routers.each do |response|
    puts Router.new(response)
  end
  g.select_all_links.each do |response|
    puts Link.new(response)
  end
end
