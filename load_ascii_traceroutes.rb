#!/usr/bin/env ruby

require_relative 'lib/neo4j.rb'
require_relative 'lib/traceroute_reader_util.rb'
require_relative 'avg_hop.rb'

$avghop = AverageHop.new

class AsciiTracerouteFileReader < TracerouteFileReader
  def read
    puts @filename
    File.open(@filename) do |f|
      next_destination = f.gets
      while next_destination
        next_destination = parse_and_insert_traceroute(f, next_destination)
      end
      puts $avghop.avg_hop @vp
    end
  end

  def parse_and_insert_traceroute(f, next_destination)
    # Next destination is the first line:
    # D 8.8.8.8 n 14
    # H 0 169.229.49.1 0.302000 255 1415563001
    # H 1 169.229.59.225 0.944000 63 1415563005
    # H 2 128.32.255.57 0.807000 253 1415563009
    # H 3 128.32.0.66 0.297000 252 1415563013
    # H 4 137.164.50.16 0.855000 251 1415563017
    # H 5 137.164.22.27 2.537000 250 1415563021
    # H 6 72.14.205.134 4.219000 249 1415563025
    # H 7 216.239.49.250 3.092000 248 1415563029
    # H 8 209.85.250.60 3.253000 503 1415563033
    # H 9 72.14.232.63 18.594000 500 1415563037
    # H 10 216.239.50.189 21.783001 499 1415563041
    # H 11 64.233.174.131 21.052999 244 1415563045
    # H 12 0.0.0.0 0.000000 0 0
    # H 13 8.8.8.8 21.146999 46 1415563055
    _, destination, _, nhop = next_destination.chomp.split
    nhop = nhop.to_i
    if not $avghop.insert(@vp, destination, nhop)
       #puts 'end'
       #puts $avghop.avg_hop @vp
       #exit
    end
    # TODO(cs): add a link from the VP to the first hop.
    # TODO(cs): sanity check input.
    last_ip, last_lat, last_ttl = nil, nil, nil
    ip, lat, ttl = nil, nil, nil
    while line = f.gets
      line = line.chomp
      return line if line[0] == "D"
      next
      last_ip, last_lat, last_ttl = ip, lat, ttl
      # TODO(cs): figure out what the last entry is.
      _, _, ip, lat, ttl, _ = line.split
      if ip == "0.0.0.0"
        ip, lat, ttl = nil, nil, nil
      else
        lat, ttl = lat.to_f, ttl.to_i
      end
      if not ip.nil? and not last_ip.nil?
        @database.create_link(last_ip, ip, @vp, destination, ttl, lat)
      end
    end
  end
end

if $0 == __FILE__
  database = GraphDatabase.new

  datadir = ARGV[0]
  prefix = ARGV[1]
  
  filelist = Dir.entries(datadir).sort
  filelist.each do |file|
    next if not file.start_with? prefix
    file = File.join(datadir, file)
    AsciiTracerouteFileReader.new(file, database).read
  end
end
