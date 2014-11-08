#!/usr/bin/env ruby

require 'neo4j-core'
load 'utilities.rb'

class GraphDatabase
  def initialize
    @session = Neo4j::Session.open(:server_db, 'http://localhost:7474')
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

  def create_link(address1, address2, vp, destination_address)
    (address1, address2, destination_address) = [address1, address2, destination_address].map do |addr|
      Inet::aton(addr) if addr.is_a? String
    end
    # TODO(cs): figure out how to use DSL to make node unique, rather than raw Cypher
    r1 = @session.query("MERGE (r1:Router { address: #{address1} }) RETURN r1").first.r1
    r2 = @session.query("MERGE (r2:Router { address: #{address2} }) RETURN r2").first.r2
    r1.create_rel("Link", r2, {vp: vp, destination_address: destination_address})
  end
end

if $0 == __FILE__
  g = GraphDatabase.new
  g.place_constraints
  g.create_link("1.2.3.4", "2.3.4.5", "vp1", "5.6.7.8")
  g.create_link("1.2.3.4", "2.3.4.5", "vp2", "5.6.7.8")
  g.select_all_routers.each do |response|
    router = response.router
    puts "#{router.inspect} #{router.labels} #{router.props} #{router.rels} #{router.nodes}"
  end
  g.select_all_links.each do |response|
    link = response.link
    puts "#{link.inspect} #{link.rel_type} #{link.props}"
  end
end
