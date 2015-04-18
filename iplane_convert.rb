require 'set'

require_relative 'retrieve_data.rb'
require_relative 'config.rb'
require_relative 'lib/traceroute_reader_util.rb'
require_relative 'lib/astrace.rb'

include TopoConfig

if $0 == __FILE__
    options = {}
    optparse = OptionParser.new do |opts|
        options[:start] = nil
        opts.on("-s", "--start DATE", "Specify the start date (format: 20150101)") do |start|
            options[:start] = Date.parse(start)
        end
        options[:duration] = nil
        opts.on("-d", "--duration DURATION", "Sepcify the duration of days/weeks (format: 1d, 5d, 1w)") do |duration|
            if duration.end_with?('d')
                options[:duration] = duration.chomp('d').to_i
            elsif duration.end_with?('w')
                options[:duration] = duration.chomp('w').to_i * 7
            else
                puts "Wrong option for duration: #{duration}"
                exit
            end
        end
        opts.on("-h", "--help", "Prints this help") do 
            puts opts
            exit
        end
    end
    optparse.parse!
    if options[:start].nil?
        puts "No start date is given."
        exit
    elsif options[:duration].nil?
        put "No duration is given."
        exit
    end

    startdate = options[:start]
    duration = options[:duration]
    puts "Duration: #{duration} days"

    numday = 0
    targets = load_target_list

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        numday += 1

        tracelist = retrieve_iplane(date)
        puts "[#{Time.now}] Start the analysis on #{date}"

        tracelist.each do |vp, uris|
            if IPLANE_BLACKLIST.include?(vp)
                puts "Skip the broken node #{vp}"
                next
            end

            puts "[#{Time.now}] Processing data from #{vp}"

            firsthop = nil
            index_file, trace_file = download_iplane_data(date, uris)
            reader = IPlaneTRFileReader.new(index_file, trace_file)
            output = trace_file.sub('trace.out', 'astrace').sub('.gz', '')

            puts "[#{Time.now}] Converting #{trace_file}"
            convert_to_as_trace(reader, output, firsthop, targets)
            puts "[#{Time.now}] Output AS trace file #{output}"
       end
    end

    puts "[#{Time.now}] Program ends"
end
