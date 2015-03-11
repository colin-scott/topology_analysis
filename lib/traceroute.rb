
class Traceroute
    attr_reader :src, :dst, :hops
    def initialize(dst)
        @dst = dst
        @hops = Array.new 
        # each item: [ip, latency, ttl, timestamp]
    end

    def nhop
        @hops.size
    end

    def valid?
        flag = false
        @hops.each do |_,_,ttl,_|
            if ttl != 0
                flag = true
                break
            end
        end
        flag
    end

    def start_time
        index = 0
        while @hops[index][2] == 0
            index += 1
        end
        @hops[index][3]
    end

    def end_time
        index = -1
        while @hops[index][2] == 0
            index -= 1
        end
        @hops[index][3]
    end

    def append_hop(ip, latency, ttl, timestamp)
        @hops << [ip, latency, ttl, timestamp]
    end

    # return true if the traceroute skips first a few hops
    def skip?
        return (@hops[0][2] == 0) # ttl field
    end

    def to_s
        s = "D #{@dst} n #{nhop}\n"
        @hops.each_with_index { |val, i| s += "H #{i} #{val[0]} #{val[1]} #{val[2]} #{val[3]}\n" }
        s
    end
end

class Iteration
    attr_accessor :files
    attr_reader :first, :last, :valid_cnt, :invalid_cnt
    CONTINUOUS_SKIP_THRESHOLD = 100

    def initialize
        @first = nil
        @last = nil
        @contskip = 2
        @stage = 0 # only two stages, stage 0 or 1
        @files = Array.new
        @valid_cnt = 0
        @invalid_cnt = 0
    end
    
    # return true/false
    # true:  tr is accepted
    # false: tr should belong to next iteration
    def insert_traceroute tr
        #puts tr.dst
        # sanity check traceroute
        if not tr.valid?
            @invalid_cnt += 1
            return true
        end
        # if this tr happens after last tr 500s, regard as a new iteration
        if (not @last.nil?) and (tr.start_time - @last.end_time > 500)
            #puts "#{@last.dst} #{last.end_time}"
            #puts "#{tr.dst} #{tr.start_time}"
            return false
        end
        # now decide whether to insert tr
        skip = tr.skip?
        insert = false
        if @stage == 0
            # stage 0 means traceroute doesn't skip the first hop
            if skip
                @contskip += 1
                # if all recent traceroute skips the first hop
                # then we enter into stage 1
                @stage = 1 if @contskip > CONTINUOUS_SKIP_THRESHOLD
            else
                @contskip = 0
            end
            insert = true
        else
            # stage 1 means all traceroute skips the first hop
            insert = true if skip
            # if tr doesn't skip first hop, it indicates a new iteration
        end
        
        if insert
            # now insert this tr
            @first = tr if @first.nil?
            if skip
                tr.hops[0] = @first.hops[0]
            end
            @last = tr
            @valid_cnt += 1
        end
        insert 
    end

    def filelist
        @files.join("|")
    end

    def start_time
        return nil if @first.nil?
        @first.start_time
    end

    def end_time
        return nil if @last.nil?
        @last.end_time
    end

    def date
        Time.at(start_time()).strftime("%Y%m%d")
    end

    def end_date
        Time.at(end_time()).strftime("%Y%m%d")
    end

    def duration
        st = start_time()
        et = end_time()
        return nil if st.nil? or et.nil?
        return et - st
    end
end
