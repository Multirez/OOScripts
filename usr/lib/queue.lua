--[[ Simple FIFO collection
     Author: Multirez ]]

local queue = {}

function queue.new()
    local queue = {}
    queue.firstIndex = 1
    queue.lastIndex = 0

    function queue:count()
        return self.lastIndex - self.firstIndex + 1
    end

    function queue:push(obj)
        local last = self.lastIndex + 1
        self.lastIndex = last
        self[last] = obj
    end

    function queue:pull()
        if self:count() <= 0 then error("queue is empty or corrupted") end
        local first = self.firstIndex
        local result = self[first]
        self[first] = nil
        self.firstIndex = first + 1
        return result
    end

    return queue
end

return queue
