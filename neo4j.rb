#!/usr/bin/env ruby

require 'neo4j-core'
load 'utilities.rb'

class GraphDatabase
  def initialize
    @session = Neo4j::Session.open(:server_db, 'http://localhost:7474')
  end

  def place_constraints
    @session.query("CREATE CONSTRAINT ON (r:Router) ASSERT r.address IS UNIQUE")
    @session.query("CREATE CONSTRAINT ON (vp:VP) ASSERT vp.name IS UNIQUE")
    # TODO(cs): create constraints on links as well?
  end

  def select_all_routers_and_edges
    @session.query("MATCH (N) RETURN N")
  end

  def delete_all
    @session.query <<-eos
      MATCH (n)
      OPTIONAL MATCH (n)-[r]-()
      DELETE n,r
    eos
  end

  def create_router(address)
    address = Inet::aton(address) if address.is_a? String
    @session.query("MERGE (r:Router { address: #{address} }) RETURN r")
  end

  def create_link(address1, address2, source_vp, destination_address)
    destination_address = Inet::aton(destination_address) if destination_address.is_a? String
    router1 = create_router(address1)
    router2 = create_router(address1)
    # Ensure VP exists in DB.
    create_vp(source_vp)
    @session.query <<-eos
      START r1=node(#{router1.id}), r2=node(#{router2.id})
      CREATE r1-[l:Link {source_vp: #{source_vp}, destination_address: #{destination_address }}]-r2
      return l
    eos
  end

  def create_vp(name)
    @session.query("MERGE (vp:VP { name: #{name} }) RETURN vp")
  end
end

if $0 == __FILE__
  g = GraphDatabase.new
  g.create_link("1.2.3.4", "2.3.4.5", "vp1", "5.6.7.8")
  g.select_all.each do |n|
    puts n
  end
end
