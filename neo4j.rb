#!/usr/bin/env ruby

require 'neo4j-core'
load 'utilities.rb'

class GraphDatabase
  def initialize
    @session = Neo4j::Session.open(:server_db, 'http://localhost:7474')
  end

  def select_all
    @session.query("MATCH (N) RETURN N")
  end

  def create_router(address)
    # TODO(cs): figure out MERGE in the gem.
    Neo4j::Node.create({address: address}, :router)
  end
end

if $0 == __FILE__
  g = GraphDatabase.new
  g.select_all.each do |n|
    puts n
  end
end
