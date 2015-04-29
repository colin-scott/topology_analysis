class BGPAtom
    def initialize(ip)
        @ip = ip
        @latency = []
        @ashop = []
    end

    def num_traceroute
        @latency.size
    end

    def avg_latency
        sum = 0.0
        @latency.each { |v| sum += v }
        sum / @latency.size
    end

    def avg_ashop
        sum = 0
        @ashop.each { |n| sum += n }
        sum.to_f / @ashop.size
    end

    def add_traceroute(tr)
        return if tr.hops.size == 0 or tr.dst != tr.hops[-1][0]
        @latency << tr.hops[-1][1]
    end

    def add_astrace(astrace, yahoo_aslist=nil)
        return if not astrace.reached
        lastasn = astrace.src_asn
        as_hops = 0
        missing = 0
        astrace.hops.each do |asn|
            if asn <= 0
                missing += 1
            else
                if asn != lastasn
                    if as_hops == 0 and not yahoo_aslist.nil? and yahoo_aslist.include?(asn)
                        # do not add ashops since it's still within yahoo
                        nil
                    else
                        as_hops += 1 if missing > 0
                        as_hops += 1
                    end
                    lastasn = asn
                    missing = 0
                end
            end
        end
        # include the src AS, so we add 1 here
        as_hops += 1
        @ashop << as_hops
    end
end


