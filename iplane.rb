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
    filelist = retrieve_iplane(date)
    output_dir = File.join(TopoConfig::IPLANE_DATA_DIR, date)
    Dir.mkdir(output_dir) if not Dir.exist? output_dir

    stats = Analysis.new [:AS, :ASLink]
    targets = load_target_list

    puts "[#{Time.now}] Start the analysis on iPlane date"
    filelist.each do |vp, uris|
        puts "[#{Time.now}] Processing data from #{vp}"
        index_uri = uris['index']
        index_file = File.join(output_dir, index_uri[index_uri.rindex('/')+1..-1])
        if not File.exist? index_file
            puts "Download #{index_file}"
            `curl #{index_uri} -o #{index_file}`
        end

        trace_uri = uris['trace']
        trace_file = File.join(output_dir, trace_uri[trace_uri.rindex('/')+1..-1])
        trace_file_ = trace_file.gsub(".gz", "")
        if not File.exist? trace_file and not File.exist? trace_file_
            puts "Download #{trace_file}"
            `curl #{trace_uri} -o #{trace_file}`
        end

        reader = IPlaneTracerouteFileReader.new(index_file, trace_file)
        reader.each do |tr|
            if targets.include? tr.dst
                stats.add tr
            end
        end
        #puts stats.as.size
        #break
    end
    puts "[#{Time.now}] Start to output the results"
    File.open("AS#{date}.txt", 'w') do |f|
        stats.as.each { |asn| f.puts asn }
    end
    File.open("ASLink#{date}.txt", 'w') do |f|
        stats.as_links.each { |a,b| f.puts "#{a} #{b}" }
    end
    puts "[#{Time.now}] Program ends"
end
