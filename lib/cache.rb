
class Node
    attr_accessor :next, :prev
    attr_reader :key, :val
    def initialize key, val
        @key = key
        @val = val
        @prev = nil
        @next = nil
    end

    def to_s
        "#{@key}:#{@val}"
    end
end

class LinkList
    attr_reader :head, :tail
    def initialize
        @head = nil
        @tail = nil
    end

    def append node
        if @head.nil?
            @head = node
            @tail = node
        else
            @tail.next = node
            node.prev = @tail
            @tail = node
        end
    end

    def delete node
        if node == @head
            @head = node.next
            @tail = nil if @tail == node
        elsif node == @tail
            # node.prev cannot be nil
            node.prev.next = nil
            @tail = node.prev
        else
            node.prev.next = node.next
            node.next.prev = node.prev
        end
    end

    def to_s
        s = ""
        node = @head
        while not node.nil?
            s += node.to_s + " "
            node = node.next
        end
        s
    end
end

class Cache
    #MAX_CACHE_SIZE = 2 # for test
    MAX_CACHE_SIZE = 50000

    def initialize
        @lookup = Hash.new
        @lru = LinkList.new
    end

    def add key, val
        if @lookup.size == MAX_CACHE_SIZE
            # evict the least recent used node
            node = @lru.head
            @lookup.delete node.key
            @lru.delete node
        end
        node = Node.new(key, val)
        @lru.append node
        @lookup[key] = node
    end

    def query key
        if @lookup.has_key? key
            node = @lookup[key]
            # refresh cache
            @lru.delete node
            @lru.append node
            return node.val
        end
        nil
    end
end

if $0 == __FILE__
=begin
    list = LinkList.new
    node1 = Node.new 1,'a'
    node2 = Node.new 2,'b'
    node3 = Node.new 3,'c'
    list.append node1
    puts list
    list.delete node1
    puts list
    list.append node2
    list.append node3
    puts list
    list.append node1
    puts list
    list.delete node3
    puts list
    list.delete node1
    puts list
=end
    cache = Cache.new
    cache.add 1, 'a'
    puts cache.query(1)
    cache.add 2, 'b'
    puts cache.query(2)
    cache.add 3, 'c'
    puts cache.query(3)
    puts cache.query(1)
    puts cache.query(2)
    cache.add 1, 'a'
    puts cache.query(3) # should be nil
    puts cache.query(2)
    puts cache.query(1)
end
