require 'date'

require_relative 'traceroute.rb'

def parse_filename fn
    # first remove all the directory
    fn = File.basename(fn)
    # remove extension .gz .log
    fn = File.basename(fn, File.extname(fn)) if fn.end_with? 'gz'
    fn = File.basename(fn, File.extname(fn)) if fn.end_with? 'log'
    # remove prefix
    fn.gsub!("tracertagent-", "")
    vp, timestr = fn.split('-')
    vp.downcase!
    time = DateTime.strptime(timestr, "%Y%m%d.%Hh%Mm%Ss")
    return [vp, time]
end

# Abstract class
class TracerouteFileReader
    ReadOutFile = "./readoutfile/readoutfile_no_ntoa"
    
    attr_reader :filename
    def initialize(filename)
        @filename = unzip(filename)
        @vp, @date = parse_filename @filename
    end

    def unzip(filename)
        if filename.end_with? '.gz'
            `gzip -d #{filename}`
            filename = filename[0...-3]
        end
        filename
    end
end

class AsciiTracerouteFileReader < TracerouteFileReader
    def initialize filename
        super(filename)
        @f = File.open(@filename)
        @next_destination = nil
    end 
    
    # seek to a certain line
    def seek lno
        lno.times { @f.gets }
        @lno = lno
    end

    def lineno
        return nil if @f.nil?
        return @f.lineno
    end

    def close
        @f.close
        @f = nil
    end

    def next_traceroute
        # Next destination is the first line:
        # D 8.8.8.8 n 14
        # H 0 169.229.49.1 0.302000 255 1415563001
        # H 1 169.229.59.225 0.944000 63 1415563005
        # H 2 128.32.255.57 0.807000 253 1415563009
        # H 3 128.32.0.66 0.297000 252 1415563013
        # H 4 137.164.50.16 0.855000 251 1415563017
        # H 5 137.164.22.27 2.537000 250 1415563021
        # H 6 72.14.205.134 4.219000 249 1415563025
        # H 7 216.239.49.250 3.092000 248 1415563029
        # H 8 209.85.250.60 3.253000 503 1415563033
        # H 9 72.14.232.63 18.594000 500 1415563037
        # H 10 216.239.50.189 21.783001 499 1415563041
        # H 11 64.233.174.131 21.052999 244 1415563045
        # H 12 0.0.0.0 0.000000 0 0
        # H 13 8.8.8.8 21.146999 46 1415563055
        @next_destination = @f.gets if @next_destination.nil?
        return nil if @next_destination.nil?

        # TODO(cs): add a link from the VP to the first hop.
        # TODO(cs): sanity check input.
        _, dstip, _, nhop = @next_destination.chomp.split
        tr = Traceroute.new(dstip, nhop)
        while line = @f.gets
            line = line.chomp
            if line[0] == 'D'
                @next_destination = line
                return tr
            end
            #last_ip, last_lat, last_ttl = ip, lat, ttl
            # TODO(cs): figure out what the last entry is.
            _, _, ip, lat, ttl, timestamp = line.split
            tr.append_hop(ip, lat, ttl, timestamp)
        end
        @next_destination = nil
        return tr
    end
end
