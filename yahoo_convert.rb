require 'set'

require_relative 'retrieve_data.rb'
require_relative 'config.rb'
require_relative 'lib/traceroute_reader_util.rb'
require_relative 'lib/analysis'

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
    stats = ASAnalysis.new
    vp_info = {}

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        numday += 1

        tracelist = retrieve_yahoo(date)
        puts "[#{Time.now}] Start the convert on #{date}"

        tracelist.each do |vp, filelist|
            if vp_info.has_key?(vp)
                vp_ip, vp_asn = vp_info[vp]
            else
                vp_ip = ASMapper.get_ip_from_url(vp)
                vp_asn = ASMapper.query_asn(vp_ip)
                vp_info[vp] = [vp_ip, vp_asn]
            end

            if vp_asn.nil?
                puts "#{vp}, #{vp_ip}"
            end

            puts "[#{Time.now}] Processing data from #{vp}"

            filelist = download_yahoo_data(filelist)
            firsthop = nil

            filelist.each do |fn|
                puts "[#{Time.now}] Converting #{fn}"
                reader = AsciiTRFileReader.new(fn)
                outfn = fn.sub('tracertagent', 'astrace').sub('.gz', '')
                fout = File.open(outfn, 'w')

                reader.each do |tr|
                    # fill in the missing first hop skipped by traceroute
                    firsthop = tr.hops[0] if firsthop.nil? and tr.hops[0][2] != 0
                    tr.hops[0] = firsthop if not firsthop.nil? and tr.hops[0][2] == 0

                    tr.src_ip = vp_ip
                    tr.src_asn = vp_asn
                    astrace = stats.generate_as_trace(tr)
                    reached = (tr.dst == tr.hops[-1][0])

                    # -2: unresponsive hop
                    # -1: private IP
                    #  0: no ASN found
                    fout.print "#{tr.dst} #{reached}"
                    astrace.each_with_index do |asn, i|
                        if tr.hops[i][2] == 0
                            fout.print " -2"
                        elsif asn.nil?
                            fout.print " 0"
                        else
                            fout.print " #{asn}"
                        end
                    end
                    fout.puts
                end

                fout.close()
                puts "[#{Time.now}] Output AS trace file #{outfn}"
            end
        end
    end

    puts "[#{Time.now}] Program ends"
end
