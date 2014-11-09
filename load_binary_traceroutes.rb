#!/usr/bin/env ruby

load 'lib/neo4j.rb'

# TODO(cs): figure out how to read destination field from each traceroute in
# the binary file.

def compile_readoutfile
  ret = nil
  Dir.chdir("readoutfile") do
    ret = system("make")
  end
  ret
end

class TracerouteFileReader
  ReadOutFile = "./readoutfile/readoutfile_no_ntoa"

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

  private

  def get_vp_from_filename(filename)
    filename.gsub("trace.out", "")
  end

  def parse_and_insert_traceroute(line)
    # TODO(cs): figure out how to get the destination reliably.
    destination = nil
    hops = line.chomp.split
    last_ip, last_lat, last_ttl = nil, nil, nil
    ip, lat, ttl = nil, nil, nil
    # TODO(cs): add a link from the VP to the first hop
    while not hops.empty?
      last_ip, last_lat, last_ttl = ip, lat, ttl
      if hops[0] == "*"
        hops.shift
        ip, lat, ttl = nil, nil, nil
      else
        # TODO(cs): sanity check input.
        ip, lat, ttl = hops.shift.to_i, hops.shift.to_f, hops.shift.to_i
      end
      puts "IP is #{ip} #{lat} #{ttl}"
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
    TracerouteFileReader.new(file, database).read
  end
end
