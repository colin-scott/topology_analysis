require_relative 'iplane_as_distance.rb'
require_relative 'iplane_churn.rb'
require_relative 'iplane_convert.rb'

if $0 == __FILE__
    options = {}
    optparse = OptionParser.new do |opts|
        options[:option] = nil
        opts.on("-o", "--option OPTION", [:as, :churn, :convert], "Select analysis (as, churn, convert)") do |option|
            options[:option] = option
        end
        options[:start] = nil
        opts.on("-s", "--start DATE", "Specify the start date (format: 20150101)") do |start|
            options[:start] = Date.parse(start)
        end
        options[:duration] = nil
        opts.on("-d", "--duration DURATION", "Specify the number of days") do |duration|
            options[:duration] = duration.to_i
        end
        options[:aslist] = nil
        opts.on("--as FILE", "Specify the file that contains the ASN selection list") do |aslist|
            options[:aslist] = []
            File.open(aslist).each { |line| options[:aslist] << line.to_i }
        end
        opts.on("-h", "--help", "Prints this help") do 
            puts opts
            exit
        end
    end
    optparse.parse!
    if options[:option].nil?
        puts "No option is given."
        exit
    elsif options[:start].nil?
        puts "No start date is given."
        exit
    #elsif options[:duration].nil?
    #    put "No duration is given."
    #    exit
    end

    if options[:option] == :as
        nil
    elsif options[:option] == :churn
        ChurnAnalysis::analyze(options)
    elsif options[:option] == :convert
        Converter::convert(options)
    end
end
