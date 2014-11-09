#!/usr/bin/env ruby

load 'lib/neo4j.rb'
load 'lib/traceroute_reader_util.rb'

def compile_readoutfile
  ret = nil
  Dir.chdir("readoutfile") do
    ret = system("make")
  end
  ret
end

class BinaryTracerouteFileReader < TracerouteFileReader
  def initialize(filename, database)
    @filename = filename
    @vp = get_vp_from_filename(filename)
    @database = database
  end

  def read
    IO.popen("#{TracerouteFileReader::ReadOutFile} #{@filename}") do |f|
      while line = f.gets
        parse_and_insert_traceroute(line)
      end
    end
  end

  def parse_and_insert_traceroute(line)
    hops = line.chomp.split
    destination = hops.shift.to_i
    last_ip, last_lat, last_ttl = nil, nil, nil
    ip, lat, ttl = nil, nil, nil
    # TODO(cs): add a link from the VP to the first hop.
    while not hops.empty?
      last_ip, last_lat, last_ttl = ip, lat, ttl
      if hops[0] == "*"
        hops.shift
        ip, lat, ttl = nil, nil, nil
      else
        # TODO(cs): sanity check input.
        ip, lat, ttl = hops.shift.to_i, hops.shift.to_f, hops.shift.to_i
      end
      if not ip.nil? and not last_ip.nil?
        @database.create_link(last_ip, ip, @vp, destination, ttl, lat)
      end
    end
  end

end

if $0 == __FILE__
  if not compile_readoutfile
    raise "Could not compile readoutfile. Try manually?"
  end

  database = GraphDatabase.new

  ARGV.each do |file|
    BinaryTracerouteFileReader.new(file, database).read
  end
end
