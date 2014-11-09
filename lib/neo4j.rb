#!/usr/bin/env ruby

require 'neo4j-core'
require_relative 'utilities.rb'
require_relative 'topology_entities.rb'

class GraphDatabase
  def initialize
    @session = Neo4j::Session.open(:server_db, 'http://localhost:7474')
    # TODO(cs): possible a performance problem to call this at every
    # initialization.
    place_constraints
  end

  def place_constraints
    @session.query("CREATE CONSTRAINT ON (r:Router) ASSERT r.address IS UNIQUE")
    # TODO(cs): create constraints on links as well?
  end

  def select_all_routers
    @session.query("MATCH (router:Router) RETURN router")
  end

  def select_all_links
    @session.query("MATCH (r1)-[link:Link]->(r2) RETURN link")
  end

  def delete_all
    @session.query <<-eos
      MATCH (n)
      OPTIONAL MATCH (n)-[r]-()
      DELETE n,r
    eos
  end

  def create_link(address1, address2, vp, destination_address, ttl, latency)
    (address1, address2, destination_address) = [address1, address2, destination_address].map do |addr|
      if addr.is_a?(String) then Inet::aton(addr) else addr end
    end
    # TODO(cs): figure out how to use DSL to make node unique, rather than raw Cypher
    r1 = @session.query("MERGE (r1:Router { address: #{address1} }) RETURN r1").first.r1
    r2 = @session.query("MERGE (r2:Router { address: #{address2} }) RETURN r2").first.r2
    link_attrs = {
      vp: vp,
      destination_address: destination_address,
      ttl: ttl,
      latency: latency
    }
    r1.create_rel("Link", r2, link_attrs)
  end
end

if $0 == __FILE__
  g = GraphDatabase.new
  g.create_link("1.2.3.4", "2.3.4.5", "vp1", "5.6.7.8")
  g.create_link("1.2.3.4", "2.3.4.5", "vp2", "5.6.7.8")
  g.select_all_routers.each do |response|
    puts Router.new(response)
  end
  g.select_all_links.each do |response|
    puts Link.new(response)
  end
end
