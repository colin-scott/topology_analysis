#!/usr/bin/env ruby

require_relative 'utilities.rb'

class Router
  def initialize(query_response)
    if query_response.is_a? Neo4j::Server::CypherNode
      @router = query_response
    else
      @router = query_response.router
    end
    @props = Hash.new.merge @router.props
    # TODO(cs): check endianness.
    @props[:address] = Inet::ntoa_little_endian(@props[:address])
  end

  def to_s
    @props[:address]
  end
end

class Link
  def initialize(query_response)
    @link = query_response.link
    @props = Hash.new.merge @link.props
    if @props["destination_address"]
      @props["destination_address"] = Inet::ntoa_little_endian(@props["destination_address"])
    end
  end

  def to_s
    "(#{Router.new(@link.start_node)})-#{@link.rel_type}->(#{Router.new(@link.end_node)}) #{@props}"
  end
end
