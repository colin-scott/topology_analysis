require 'set'

require_relative '../config.rb'
require_relative 'utilities.rb'
require_relative 'traceroute_reader_util.rb'
require_relative 'asmapper.rb'

class ASAnalysis
  
    attr_accessor :yahoo_aslist
    attr_reader :as_dist, :as_links, :ip_no_asn

    def initialize(yahoo_aslist=nil)
        # stats info
        @as_dist = {} # ASN => [#the shortest distance, IP address]
        @as_links = Set.new
        @ip_no_asn = Set.new
        @yahoo_aslist = yahoo_aslist
    end

    def reset
        @as_dist.clear
        @as_links.clear
        @ip_no_asn.clear
    end

    def merge(stats)
        stats.as_dist.each do |asn, val|
            dist, ip = val
            if not @as_dist.has_key? asn or @as_dist[asn][0] > dist
                @as_dist[asn] = val
            end
        end
        @as_links.merge(stats.as_links)
    end

    def generate_as_trace(tr)
        astrace = []
        # generate as list
        tr.hops.each do |ip,_,ttl,_|
            if ttl == 0
                # missing hop
                astrace << nil
                next
            elsif Inet::in_private_prefix_q? ip
                # use -1 to indicate private IP addr
                astrace << -1
            else
                asn = ASMapper.query_asn ip
                if asn.nil?
                    astrace << nil
                    @ip_no_asn << ip
                else
                    astrace << asn
                end
            end
        end
        astrace
    end

    def add_iplane tr
        astrace = generate_as_trace tr
        lastasn = tr.src_asn
        missing = 0
        as_nhop = 0
        
        # assume tr.src_asn is not nil
        @as_dist[tr.src_asn] = [0, tr.src_ip]

        astrace.each_with_index do |asn, i|
            if asn.nil?
                missing += 1
            elsif asn == -1
                # ignore private IP hop
                next
            else
                if asn != lastasn
                    @as_links << [lastasn, asn] if missing == 0

                    # update AS distance 
                    # if missing ASN > 1, we consider an AS hop inside
                    as_nhop += 1 if missing > 0
                    # new AS hop detected
                    as_nhop += 1
                    if not @as_dist.has_key?(asn) or @as_dist[asn][0] > as_nhop
                        @as_dist[asn] = [as_nhop, tr.hops[i][0]]
                    end
                end
                lastasn = asn
                missing = 0
            end
        end
   end

    def add_yahoo tr
        astrace = generate_as_trace tr
        lastasn = tr.src_asn
        missing = 0
        as_nhop = 0
        
        # assume tr.src_asn is not nil
        @as_dist[tr.src_asn] = [0, tr.src_ip]

        astrace.each_with_index do |asn, i|
            if asn.nil?
                missing += 1
            elsif asn == -1
                # ignore private IP hop
                next
            else
                if asn != lastasn
                    @as_links << [lastasn, asn] if missing == 0
                    
                    # update AS distance
                    if as_nhop == 0 and @yahoo_aslist.include? asn
                        # still consider at AS hop 0
                        # don't incrase as_nhop
                        @as_dist[asn] = [0, tr.hops[i][0]]
                    else
                        # if missing ASN > 1, we consider an AS hop inside
                        as_nhop += 1 if missing > 0
                        # new AS hop detected
                        as_nhop += 1
                        if not @as_dist.has_key?(asn) or @as_dist[asn][0] > as_nhop
                            @as_dist[asn] = [as_nhop, tr.hops[i][0]]
                        end
                    end
                end
                lastasn = asn
                missing = 0
            end
        end
    end

    def output_as(fn)
        File.open(fn, 'w') do |f|
            f.puts("# ASN distance")
            @as_dist.each { |asn, val| f.puts "#{asn} #{val[0]}" }
        end
    end

    def output_aslinks(fn)
        File.open(fn, 'w') do |f|
            @as_links.each { |a,b| f.puts "#{a} #{b}" }
        end
    end

    def output_as_distance(fn, neighbor=false)
        distance = {}
        sum = 0
        @as_dist.each do |asn, val|
            dist, ip = val
            sum += dist
            distance[dist] = [] if not distance.has_key?(dist)
            distance[dist] << asn
        end
        avg_dist = sum.to_f / @as_dist.size

        File.open(fn, 'a') do |f|
            f.printf("Average Distance: %.2f\n", avg_dist)
            distance.keys.sort.each do |dist|
                asnlist = distance[dist]
                f.printf("%2d: %d\n", dist, asnlist.size)
            end
            if neighbor
                # output all the neighbors
                if distance.has_key?(1)
                    neighbors = distance[1]
                    f.puts "Neighbors:"
                    neighbors.sort.each do |asn|
                        ip = @as_dist[asn][1]
                        f.puts "  #{asn}: #{ip}"
                    end
                end
            end
        end
    end
end

