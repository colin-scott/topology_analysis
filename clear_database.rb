#!/usr/bin/env ruby

require_relative 'lib/neo4j.rb'

if $0 == __FILE__
  g = GraphDatabase.new
  g.delete_all
end
#
