#!/usr/bin/env ruby

load 'utilities.rb'

class Router
  def initialize(query_response)
    @router = query_response.router
    @props = Hash.new.merge @router.props
    # TODO(cs): check endianness.
    @props[:address] = Inet::ntoa_little_endian(@props[:address])
  end

  def to_s
    "#{@router.inspect} #{@router.labels} #{@props}"
  end
end

class Link
  def initialize(query_response)
    @link = query_response.link
  end

  def to_s
    "#{@link.inspect} (#{@link.start_node.inspect})-#{@link.rel_type}->(#{@link.end_node.inspect}) #{@link.props}"
  end
end
