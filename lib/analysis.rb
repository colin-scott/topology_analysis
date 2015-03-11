require 'set'

require_relative '../config.rb'
require_relative 'traceroute_reader_util.rb'
require_relative 'asmapper.rb'

class Analysis
  
    attr_reader :ip, :as, :ip_links, :as_links, :ip_nhops, :as_nhops, :ip_no_asn

    # IP: record IPs    
    # IPLink: record all of IP links
    # IPHop: record number of IP hops
    # AS: record ASes
    # ASLink: record AS links
    # ASHop: record number of AS hops
    FUNCTIONS = [:IP, :IPLink, :IPHop, :AS, :ASLink, :ASHop]

    def initialize funcs
        # sanity check
        funcs.each do |func| 
            if not FUNCTIONS.include? func
                raise "Function #{func} not supported"
            end
        end
        @funcs = funcs
        # stats info
        
        @ip = Set.new
        @as = Set.new
        @ip_links = Set.new
        @as_links = Set.new
        @ip_nhops = {}
        @as_nhops = {}

        @ip_no_asn = Set.new
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

    def generate_as_hops tr
        ashops = []
        # generate as list
        tr.hops.each do |ip,_,ttl,_|
            if ttl == 0
                ashops << nil
                next
            end
            asn = ASMapper.query_as_num ip
            if asn.nil?
                ashops << nil
                @ip_no_asn << ip
            else
                ashops << asn
            end
        end
        ashops
    end

    def add tr
        if @funcs.include? :AS or @funcs.include? :ASLink or @funcs.include? :ASHop
            ashops = generate_as_hops tr
        end

        lastip = nil
        lastasn = nil
        tr.hops.each_with_index do |item, index|
            ip,_,ttl,_ = item
            ip = nil if ttl == 0

            if @funcs.include? :IP
                @ip << ip if ttl != 0
            end

            if @funcs.include? :IPLink
                if not ip.nil? and not lastip.nil?
                    ip_links << [lastip, ip]
                end
                lastip = ip
            end

            if @funcs.include? :AS
                asn = ashops[index]
                @as << asn if not asn.nil?
            end

            if @funcs.include? :ASLink
                asn = ashops[index]
                if not asn.nil? and not lastasn.nil? and asn != lastasn
                    as_links << [lastasn, asn]
                end
                lastasn = asn
            end 
        end
        
        if @funcs.include? :IPHop
            @ip_nhops << tr.nhop if tr.hops[-1][0] == tr.dst
        end
    end

    def write_summary niter
        fn = File.join(TopoConfig::OUTPUT_DIR, "#{@filepfx}.summary.txt")
        puts "[#{Time.now}] Write summary to #{fn}"
        file = File.open(fn, 'w')
        file.puts("Vantage Point: #{@vp[0]}")
        file.puts("VP ASN: #{@vp[1]}")
        file.puts("#iterations: #{niter}")
        file.puts("#IP: #{@ip_list.size}")

        avg_ip_hops = 0
        cnt = 0
        @ip_hops.each { |hop, c| avg_ip_hops += hop * c; cnt += c }
        file.puts("Average IP hops: #{avg_ip_hops.to_f / cnt}")
        
        avg_as_hops = 0
        cnt = 0
        @as_hops.each { |hop, c| avg_as_hops += hop * c; cnt += c }
        file.puts("Average AS hops: #{avg_as_hops.to_f / cnt}")
        
        file.puts("#traceroute: #{cnt}")
        file.puts("#PeerAS: #{@peer_as.size}")
        file.close
    end

    def write_cdf fn, hops
        fn = File.join(TopoConfig::OUTPUT_DIR, fn)
        puts "[#{Time.now}] Write to CDF file #{fn}"
        File.open(fn, 'w') do |file|
            hops.keys.sort.each { |n| file.puts "#{n},#{hops[n]}" }
        end
    end

    def write_peeras 
        fn = File.join(TopoConfig::OUTPUT_DIR, "#{@filepfx}.peeras.txt")
        puts "[#{Time.now}] Write to PeerAS file #{fn}"
        File.open(fn, 'w') do |file|
            @peer_as.sort.each { |asn| file.puts asn }
        end
    end
    
    def log_abnormal tr, aslist
        fn = File.join(TopoConfig::OUTPUT_DIR, "#{@filepfx}.abnormal.txt")
        File.open(fn, 'a') do |file|
            file.puts '---------------------------------------'
            file.puts tr.to_s
            file.puts "AS hops: #{aslist.size}"
            file.puts aslist.join(',')
        end
    end

    def get_vp_asn vp
        result = `nslookup #{vp}`.split.compact[-1]
        ip = result.split(':')[-1].strip
        ASMapper.query_as_num ip
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
