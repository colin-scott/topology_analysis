require 'set'

require_relative '../config.rb'
require_relative 'traceroute_reader_util.rb'
require_relative 'asmapper.rb'

class Analysis
  
    attr_accessor :yahoo_aslist
    attr_reader :ip, :as, :ip_links, :as_links, :ip_nhops, :as_nhops, :ip_no_asn

    def initialize
        # stats info
        @ip = Set.new
        @as = {} # ASN => #the shortest hops to reach it
        @ip_links = Set.new
        @as_links = Set.new
        @ip_nhops = {}
        @as_nhops = {}

        @ip_no_asn = Set.new
        @yahoo_aslist = nil
    end

    def reset
        @ip.clear
        @as.clear
        @ip_links.clear
        @as_links.clear
        @ip_nhops.clear
        @as_nhops.clear

        @ip_no_asn.clear
    end

    def generate_as_trace tr
        astrace = []
        # generate as list
        tr.hops.each do |ip,_,ttl,_|
            if ttl == 0
                astrace << nil
                next
            end
            asn = ASMapper.query_asn ip
            if asn.nil?
                astrace << nil
                @ip_no_asn << ip
            else
                astrace << asn
            end
        end
        astrace
    end

    def add tr
        astrace = generate_as_trace tr
        lastasn = tr.src_asn
        missing = 0
        as_nhop = 0
        
        # assume tr.src_asn is not nil
        @as[tr.src_asn] = 0

        astrace.each do |asn|
            if asn.nil?
                missing += 1
            else
                if asn != lastasn
                    #puts "#{lastasn}, #{asn}" if missing == 1
                    @as_links << [lastasn, asn] if missing <= 1
                    
                    # if missing ASN > 1, we consider an AS hop inside
                    as_nhop += 1 if missing > 1
                    # new AS hop detected
                    as_nhop += 1
                    if not @as.has_key? asn or @as[asn] > as_nhop
                        @as[asn] = as_nhop
                    end
                end

                lastasn = asn
                missing = 0
            end
        end
=begin
        lastip = nil
        tr.hops.each_with_index do |item, index|
            ip,_,ttl,_ = item
            ip = nil if ttl == 0
            if not ip.nil?
                @ip << ip if ttl != 0
                #ip_links << [lastip, ip] if not lastip.nil?
            end
            lastip = ip
       end
=end
    end

    def add_yahoo tr
        astrace = generate_as_trace tr
        lastasn = tr.src_asn
        missing = 0
        as_nhop = 0
        
        # assume tr.src_asn is not nil
        @as[tr.src_asn] = 0

        astrace.each do |asn|
            if asn.nil?
                missing += 1
            else
                if asn != lastasn
                    #puts "#{lastasn}, #{asn}" if missing == 1
                    @as_links << [lastasn, asn] if missing <= 1
                    
                    if as_nhop == 0 and @yahoo_aslist.include? asn
                        # still consider at AS hop 0
                        # don't incrase as_nhop
                        @as[asn] = 0
                    else
                        # if missing ASN > 1, we consider an AS hop inside
                        as_nhop += 1 if missing > 1
                        # new AS hop detected
                        as_nhop += 1
                        if not @as.has_key? asn or @as[asn] > as_nhop
                            @as[asn] = as_nhop
                        end
                    end
                end

                lastasn = asn
                missing = 0
            end
        end

=begin
        lastip = nil
        tr.hops.each_with_index do |item, index|
            ip,_,ttl,_ = item
            ip = nil if ttl == 0
            if not ip.nil?
                @ip << ip if ttl != 0
                #ip_links << [lastip, ip] if not lastip.nil?
            end
            lastip = ip
       end
=end
    end

    def output_as fn
        File.open(fn, 'w') do |f|
            @as.each { |asn, _| f.puts asn }
        end
    end

    def output_aslinks fn
        File.open(fn, 'w') do |f|
            @as_links.each { |a,b| f.puts "#{a} #{b}" }
        end
    end

    def output_as_bfs fn
        as_bfs = {}
        @as.each do |asn, nhop|
            as_bfs[nhop] = Set.new if not as_bfs.has_key? nhop
            as_bfs[nhop] << asn
        end

        File.open(fn, 'a') do |f|
            as_bfs.keys.sort.each do |nhop|
                asnlist = as_bfs[nhop]
                f.printf("%2d: %d\n", nhop, asnlist.size)
            end
=begin
            as_bfs.keys.sort.each do |nhop|
                asnlist = as_bfs[nhop]
                f.puts "--------------------- #{nhop} -----------------------"
                asnlist.each { |asn| f.puts asn }
            end
=end
        end
    end
end

if $0 == __FILE__
    if ARGV.size == 0
        puts "Usage: #{File.basename($0)} <iteration> [<iteration>...]"
        puts "    <iteration>\t\tsingle iteration id, e.g., 1"
        puts "\t\t\titeration range, e.g., \"2-3\", \"4-7,9-10\" (for aggregation analysis)"
        exit
    end
    stats = Stats.new
    while not ARGV.empty?
        targets = ARGV.shift
        stats.analyze targets
    end
end
