#!/usr/bin/env ruby

load 'neo4j.rb'

if $0 == __FILE__
  g = GraphDatabase.new
  g.delete_all
end
