#!/usr/bin/env ruby

require 'optparse'

require_relative 'lib/neo4j.rb'
require_relative 'lib/traceroute.rb'
require_relative 'lib/traceroute_reader_util.rb'
require_relative 'config.rb'
require_relative 'retrieve_data.rb'

class VPTraceroute

    def initialize(vp, data_dir, logfile=true)
        @vp = vp
        @data_dir = data_dir
        @logfile = logfile

        @iter_file = TopoConfig::ITERATION_FILE
        @index = 0
        @parsed_files = Hash.new
        @curr_iter = nil

        load_iterations if logfile
    end

    def load_iterations
        if not File.exist? @iter_file 
            File.open(@iter_file, 'w') do |f|
                f.puts "id,vp,Date,StartTime,EndTime,Duration(s),#valid,#invalid,Data Files"
            end
        end
        firstline = true
        File.open(@iter_file).each_line do |line|
            if firstline
                firstline = false
                next
            end
            items = line.split(',')
            @index = items[0].to_i
            filelist = items[-1]
            filelist.split('|').each do |file|
                range = file.split(':')
                if range.size == 2
                    @parsed_files[range[0]] = -1
                else
                    @parsed_files[range[0]] = range[2].to_i
                end
                # puts "#{range[0]},#{@parsed_files[range[0]]}"
            end
        end
        @index += 1
        puts "index: #{@index}"
        # index always starts from 1
    end

    def log_iteration(iter)
        start_time = Time.at(iter.start_time).to_s
        end_time = Time.at(iter.end_time).to_s
        record = "#{@index},#{@vp},#{iter.date},#{start_time},#{end_time},#{iter.duration},#{iter.valid_cnt},#{iter.invalid_cnt},#{iter.filelist}"
        if @logfile
            File.open(@iter_file, 'a') do |f|
                f.puts(record)
            end
        else
            puts "[#{Time.now}] #{record}"
        end
        @index += 1
    end

    def parse_range(start_date, end_date)
        Dir.entries(@data_dir).sort.each do |fn|
            next if not fn =~ /#{@vp}/
            vp, time = parse_filename fn
            next if vp != @vp
            date = time.strftime("%Y%m%d")
            next if not start_date.nil? and date < start_date
            next if not end_date.nil? and date > end_date
            fn = File.expand_path(File.join(@data_dir, fn))
            offset = (@parsed_files.include? fn) ? @parsed_files[fn] : 0
            next if offset == -1
            parse_file(fn, offset)
            @parsed_files[fn] = -1
        end
=begin
because an iteration may not finish, there's some residue in the upcoming file
        if not @curr_iter.nil?
            log_iteration @curr_iter
            @curr_iter = nil
        end
=end
    end

    def parse_all
        parse_range(nil, nil)
    end

    # check if tr exceeds the @date limit
    def exceed_date? tr
        return false if @date.nil?
        tr_date = Time.at(tr.start_time).strftime("%Y%m%d")
        if tr_date > @date
            return true
        else
            return false
        end
    end

    def parse_file(fn, offset=0)
        #puts fn, offset
        reader = AsciiTracerouteFileReader.new fn
        reader.seek offset
        @curr_iter = Iteration.new if @curr_iter.nil?
        @curr_iter.files << "#{reader.filename}:#{offset}"

        while true
            # lastpt records the last line number
            # "-1" because we already read next_destination line
            lastpt = reader.lineno - 1
            tr = reader.next_traceroute
            break if tr.nil?

            # detect if an interation is ended
            if not @curr_iter.insert_traceroute tr
                # end of one iteration
                if lastpt >= 0
                    @curr_iter.files[-1] += ":#{lastpt}"
                else
                    @curr_iter.files.pop
                end
                log_iteration @curr_iter
                @curr_iter = nil
                # now create a new iteration 
                @curr_iter = Iteration.new
                @curr_iter.insert_traceroute tr
                if lastpt >= 0
                    @curr_iter.files << "#{reader.filename}:#{lastpt}"
                else
                    @curr_iter.files << "#{reader.filename}:0"
                end
            end
        end
        reader.close
    end
end

if $0 == __FILE__

    options = {}
    optparse = OptionParser.new do |opts|
        opts.banner = "Usage: vp_traceroutes [options] <data_dir>"
        options[:start] = nil
        opts.on("-s", "--start DATE", "Start date to download, e.g. 20150101 (If not set, start from oldest") do |start|
            options[:start] = start
        end
        options[:end] = nil
        opts.on("-e", "--end DATE", "End date to download, e.g. 20150101 (If not set, end till latest)") do |enddate|
            options[:end] = enddate
        end
        opts.on("-h", "--help", "Prints this help") do 
            puts opts
            exit
        end
    end
    optparse.parse!
    data_dir = ARGV.pop
    raise "Need to specify data directory" unless data_dir
    data_dir = File.expand_path(data_dir)
    puts options
    puts data_dir

    vpfiles = retrieve(TopoConfig::REMOTE_DATA_URI, nil, options[:start], options[:end])
    vpfiles.keys.sort.each do |vp|
        puts "[#{Time.now}] retrieve data for #{vp}"
        files = vpfiles[vp]
        files.each do |fn|
            next if File.exist?(File.join(data_dir, fn))
            if fn.end_with? '.gz'
                # if local file is decompressed
                next if File.exist?(File.join(data_dir, fn[0...-3]))
            end
            #puts "retrieve #{fn} from remote server"
            `scp #{TopoConfig::REMOTE_DATA_URI}#{fn} #{data_dir}`
        end
        puts "[#{Time.now}] process data for #{vp}"
        vp = VPTraceroute.new(vp, data_dir)
        #vp.parse_file "/home/arvind3/data/download/tracertagent-r01.ycpi.ams.yahoo.net-20150109.10h05m03s.log"
        vp.parse_range(options[:start], options[:end])
    end
end
