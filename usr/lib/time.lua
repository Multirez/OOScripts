local time

function time.Time2String(time)
    local seconds = time / 100
    local minutes = seconds / 60
    local hours = minutes / 60
    local days = hours / 24
    return string.format("%i:%02i:%02i", (hours % 24), (minutes % 60), (seconds % 60))
end

return time
