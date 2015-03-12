require 'set'

require_relative 'retrieve_data.rb'
require_relative 'config.rb'
require_relative 'lib/traceroute_reader_util.rb'
require_relative 'lib/analysis'

def load_target_list
    targets = Set.new
    File.open(TopoConfig::TARGET_LIST_FILE).each_line do |ip|
        targets << ip.chomp
    end
    targets
end

if $0 == __FILE__
    options = {}
    optparse = OptionParser.new do |opts|
        options[:data] = nil
        opts.on("-d", "--date DATE", "Specify the date (format: 20150101)") do |date|
            options[:date] = date
        end
        opts.on("-h", "--help", "Prints this help") do 
            puts opts
            exit
        end
    end
    optparse.parse!
    if options[:date].nil?
        puts "No date is given."
        exit
    end

    date = options[:date]
    tracelist = retrieve_yahoo(date)
    tracedir = TopoConfig::YAHOO_DATA_DIR

    stats = Analysis.new [:IP, :AS, :ASLink]
    targets = load_target_list

    puts "[#{Time.now}] Start the analysis on iPlane date"
    tracelist.each do |vp, filelist|
        puts "[#{Time.now}] Processing data from #{vp}"

        filelist.each do |fn|
            localfn = File.join(tracedir, fn)
            localfn_ = localfn.gsub(".gz", "")
            next if File.exist? localfn or File.exist? localfn_
            remote_uri = TopoConfig::YAHOO_DATA_URI + fn
            puts "[#{Time.now}] Downloading #{fn}"
            `scp #{remote_uri} #{tracedir}`
        end
        filelist.map! { |fn| fn = File.join(tracedir, fn) }

        reader = YahooTRFileReader.new filelist
        firsthop = nil
        reader.each do |tr|
            if firsthop.nil?
                firsthop = tr.hops[0] if tr.hops[0][2] != 0
            elsif tr.hops[0][2] == 0
                tr.hops[0] = firsthop
            end
            stats.add tr
        end
        #puts stats.as.size
    end

    puts "[#{Time.now}] Start to output the results"
    puts "#IP: #{stats.ip.size}"
    puts "#IP_no_asn: #{stats.ip_no_asn.size}"
    fn = File.join(TopoConfig::YAHOO_OUTPUT_DIR, "AS#{date}.txt")
    File.open(fn, 'w') do |f|
        stats.as.each { |asn| f.puts asn }
    end
    puts "Output to #{fn}"
    fn = File.join(TopoConfig::YAHOO_OUTPUT_DIR, "ASLink#{date}.txt")
    File.open(fn, 'w') do |f|
        stats.as_links.each { |a,b| f.puts "#{a} #{b}" }
    end
    puts "Output to #{fn}"
    puts "[#{Time.now}] Program ends"
end
