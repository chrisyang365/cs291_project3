require 'securerandom'

class EventGenerator
    def initialize
        @event_id = 0
    end
    def createMessageEvent(message, username)
        data = {:message => message, :user => username, :created => Time.now.to_f}
        sse_string = getSSEString(data, MESSAGE)
        return sse_string
    end
    def createUsersEvent(users)
        data = {:users => users, :created => Time.now.to_f}
        sse_string = getSSEString(data, USERS)
        return sse_string
    end
    def createDisconnectEvent
        data = {:created => Time.now.to_f}
        sse_string = getSSEString(data, DISCONNECT)
        return sse_string
    end
    def createJoinEvent(username)
        data = {:user => username, :created => Time.now.to_f}
        sse_string = getSSEString(data, JOIN)
        return sse_string
    end
    def createPartEvent(username)
        data = {:user => username, :created => Time.now.to_f}
        sse_string = getSSEString(data, PART)
        return sse_string
    end
    def createServerStatusEvent(status)
        data = {:status => status, :created => Time.now.to_f}
        sse_string = getSSEString(data, SERVER_STATUS)
        return sse_string
    end
    private
    def getSSEString(data, event_type)
        sse_string = "data: #{data.to_json}\n" + "event: #{event_type}\n" + "id: #{@event_id}\n\n"
        @event_id += 1
        return sse_string
    end

    DISCONNECT = 'Disconnect'
    JOIN = 'Join'
    MESSAGE = 'Message'
    PART = 'Part'
    SERVER_STATUS = 'ServerStatus'
    USERS = 'Users'

end