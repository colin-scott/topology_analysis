require 'set'

require_relative '../config.rb'
require_relative 'utilities.rb'
require_relative 'traceroute_reader_util.rb'
require_relative 'asmapper.rb'

class ASAnalysis
  
    attr_accessor :yahoo_aslist
    attr_reader :tr_total, :reached, :as_dist, :as_links, 
                :tr_iphops, :tr_ashops, :tr_churn, :ip_no_asn

    def initialize(yahoo_aslist=nil)
        # stats info
        @tr_total = 0
        @reached = 0
        @as_dist = {} # ASN => [#the shortest distance, IP address]
        @as_links = {} # [as1, as2] => count
        @tr_iphops = {} # IP hops => count
        @tr_ashops = {} # AS hops => count
        @tr_churn = {} # [src,dst] => AS traces

        @ip_no_asn = Set.new
        @yahoo_aslist = yahoo_aslist
    end

    def reset
        @tr_total = 0
        @reached = 0
        @as_dist.clear
        @as_links.clear
        @tr_iphops.clear
        @tr_ashops.clear
        @tr_churn.clear
        @ip_no_asn.clear
    end

    def merge(stats)
        @tr_total += stats.tr_total
        @reached += stats.reached
        stats.as_dist.each do |asn, val|
            dist, cnt = val
            if not @as_dist.has_key?(asn)
                @as_dist[asn] = val
            else
                if @as_dist[asn][0] > dist
                    @as_dist[asn] = val
                elsif @as_dist[asn][0] == dist
                    @as_dist[asn][1] += cnt
                # else => keep current
                end
            end
        end
        stats.as_links.each do |link, cnt|
            if @as_links.has_key?(link)
                @as_links[link] += cnt
            else
                @as_links[link] = cnt
            end
        end
    end

    def generate_as_trace(tr)
        astrace = []
        # generate as list
        tr.hops.each do |ip,_,ttl,_|
            if ttl == 0
                # missing hop
                astrace << nil
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

    def generate_as_trace_compact(tr)
        astrace = [tr.src_asn]
        lastasn = tr.src_asn
        missing = 0
        #puts "- #{tr.dst}"
        tr.hops.each do |ip,_,ttl,_|
            if ttl == 0
                # missing hop
                missing += 1
                #puts ip
            elsif Inet::in_private_prefix_q?(ip)
                # ignore the private IP
                next
                #puts ip
            else
                asn = ASMapper.query_asn(ip)
                if asn.nil?
                    missing += 1
                else
                    if asn != lastasn
                        astrace << nil if missing > 0
                        astrace << asn
                    end
                    lastasn = asn
                    missing = 0
                end
                #puts "#{ip} #{asn}"
            end
        end
        
        #astrace.each_with_index do |asn, i|
        #    if i == 0
        #        print "#{asn}"
        #    else
        #        print "->#{asn}"
        #    end
        #end
        #puts

        astrace
    end

    def update_as_distance(asn, dist)
        if not @as_dist.has_key?(asn)
            @as_dist[asn] = [dist, 1]
        else
            if @as_dist[asn][0] > dist
                @as_dist[asn] = [dist, 1]
            elsif @as_dist[asn][0] == dist
                @as_dist[asn][1] += 1
            end
        end
    end

    def count astrace
        @tr_total += 1
        lastasn = astrace.src_asn
        missing = 0
        as_hops = 0
        update_as_distance(astrace.src_asn, 0)

        astrace.hops.each do |asn|
            if asn == -2
                # unresponsive hops
                missing += 1
            elsif asn == -1
                # private IP hop, just ignore
                next
            elsif asn == 0
                # asn lookup failure
                missing += 1
            else
                if asn != lastasn
                    if missing == 0
                        link = [lastasn, asn].sort
                        @as_links[link] = 0 if not @as_links.has_key?(link)
                        @as_links[link] += 1
                    end

                    # update AS distance 
                    if as_hops == 0 and not @yahoo_aslist.nil? and @yahoo_aslist.include?(asn)
                        # for yahoo only: still consider at hop 0 since it's still within Yahoo
                        update_as_distance(asn, 0)
                    else
                        # if missing ASN > 1, we consider an AS hop inside
                        as_hops += 1 if missing > 0
                        # new AS hop detected
                        as_hops += 1
                        update_as_distance(asn, as_hops)
                    end
                end
                lastasn = asn
                missing = 0
            end
        end
        # missing ASN ast the last
        as_hops += 1 if missing > 0
        # add 1 to include the source AS
        as_hops += 1
        ip_hops = astrace.hops.size
        
        if astrace.reached
            @reached += 1
            @tr_iphops[ip_hops] = 0 if not @tr_iphops.has_key?(ip_hops)
            @tr_iphops[ip_hops] += 1
            @tr_ashops[as_hops] = 0 if not @tr_ashops.has_key?(as_hops)
            @tr_ashops[as_hops] += 1
        end
    end

    def churn_collect(tr)
        return if tr.hops[-1][0] != tr.dst
        astrace = generate_as_trace_compact(tr)
        if not @yahoo_aslist.nil?
            merge = 0
            i = 1
            while i < @yahoo_aslist.size and @yahoo_aslist.include?(astrace[i])
                merge += 1
                i += 1
            end
            as_hops = astrace.size - merge
        else
            as_hops = astrace.size
        end

        if @tr_churn.has_key?([tr.src_ip, tr.dst])
            @tr_churn[[tr.src_ip, tr.dst]] << astrace
        else
            @tr_churn[[tr.src_ip, tr.dst]] = Set.new([astrace])
        end
    end

    def compare_as_traces(tr1, tr2)
        pt1 = 0
        pt2 = 0
        skip1 = false
        skip2 = false
        while pt1 < tr1.size and pt2 < tr2.size
            if tr1[pt1] == tr2[pt2]
                pt1 += 1
                pt2 += 1
                skip1 = false
                skip2 = false
            else
                if tr1[pt1].nil?
                    pt1 += 1
                    skip1 = true
                elsif tr2[pt2].nil?
                    pt2 += 1
                    skip2 = true
                else
                    # tr1[pt1] and tr2[pt2] are not nil
                    if skip1
                        pt2 += 1
                        skip1 = false
                    elsif skip2
                        pt1 += 1
                        skip2 = false
                    else
                        return false
                    end
                end
            end
        end

        return false if tr1.size - pt1 > 1
        return false if tr1.size - pt1 == 1 and not skip2
        return false if tr2.size - pt2 > 1
        return false if tr2.size - pt2 == 1 and not skip1
        return true
    end
    
    # return:
    #   0: traceroute doesn't reach the dst
    #   1: (src,dst) is not contained
    #   2: as traces is different from existing traces
    #   3: as traces is contained
    def churn_compare(tr)
        return 0 if tr.hops[-1][0] != tr.dst
        return 1 if not @tr_churn.has_key?([tr.src_ip, tr.dst])
        astrace = generate_as_trace_compact(tr)
        traces = @tr_churn[[tr.src_ip, tr.dst]]
        if traces.include?(astrace)
            return 3
        else
            traces.each do |t|
                return 3 if compare_as_traces(t, astrace)
            end
            puts "(#{tr.src_ip}, #{tr.dst})"
            puts astrace.join("->")
            traces.each { |t| puts "- #{t.join("->")}" }
            return 2
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
            @as_links.each do |link, cnt|
                f.puts "#{link[0]},#{link[1]}: #{cnt}"
            end
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
                        cnt = @as_dist[asn][1]
                        f.puts "  #{asn}: #{cnt}"
                    end
                end
            end
        end
    end

    def output_tr_hops(fn)
        total_iphops = 0
        total_ashops = 0
        @tr_iphops.each { |hops, cnt| total_iphops += hops * cnt }
        @tr_ashops.each { |hops, cnt| total_ashops += hops * cnt }
        avg_iphops = total_iphops.to_f / @reached
        avg_ashops = total_ashops.to_f / @reached
        File.open(fn, 'a') do |f|
            f.printf("Average IP Hops: %.2f\n", avg_iphops)
            f.printf("Average AS Hops: %.2f\n", avg_ashops)
            f.puts("AS Hops:")
            @tr_ashops.keys.sort.each { |hops| f.puts("#{hops}: #{@tr_ashops[hops]}") }
        end
    end
end

