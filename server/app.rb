# frozen_string_literal: true

require 'eventmachine'
require 'sinatra'
require 'securerandom'
require_relative 'event_generator'

SCHEDULE_TIME = 60
connections = []
registrations = {} #key: username, value: password
streams = {} #key: username, value: stream object
stream_token_num = 0
msg_tokens = {} #key: msg_token, value: username
stream_tokens = {} #key: stream_token, value: username

event_generator = EventGenerator.new

first_server_status_msg = event_generator.createServerStatusEvent("Server is created")
events = [['ServerStatus', first_server_status_msg]]

def get_header(headers, header_type)
  for header in headers.keys
    if header.upcase == header_type.upcase
      return headers[header]
    end
  end
  return nil
end

def get_bearer_token(headers)
  pattern = /^Bearer /
  header = get_header(headers, "HTTP_AUTHORIZATION")
  header.gsub(pattern, '') if header && header.match(pattern)
end
class String
  def is_i?
      /\A[-+]?\d+\z/ === self
  end
end
def is_valid_event_id(event_id, events)
  if !event_id.is_i?
    return false
  end
  event_id = event_id.to_i
  return 0 <= event_id && event_id <= events.length
end

EventMachine.schedule do
  EventMachine.add_periodic_timer(SCHEDULE_TIME) do
    # Change this for any timed events you need to schedule.
    puts "This message will be output to the server console every #{SCHEDULE_TIME} seconds"
  end
end

options "/*" do
  headers 'Access-Control-Allow-Origin' => '*'
  headers 'Access-Control-Allow-Methods' => '*'
  headers 'Access-Control-Allow-Headers' => '*'
  200
end

get '/stream/:token', provides: 'text/event-stream' do |token|
  headers 'Access-Control-Allow-Origin' => '*'
  if !stream_tokens.has_key?(token)
    status 403
  else
    username = stream_tokens[token]
    if streams.has_key?(username)
      status 409
    else
      stream(:keep_open) do |connection|
        connections << connection
        streams[username] = connection

        last_event_id = get_header(request.env, "HTTP_LAST_EVENT_ID")
        if last_event_id && is_valid_event_id(last_event_id, events) #reconnect
          last_event_id = last_event_id.to_i + 1
          for event in events[last_event_id..-1] do
            if event[0] == 'Message' || event[0] == 'ServerStatus'
              connection << event[1]
            end
          end

          new_user_join_msg = event_generator.createJoinEvent(username)
          events << ['Join', new_user_join_msg]

          for c in connections do
            c << new_user_join_msg
          end
        else #new connection
          new_users_msg = event_generator.createUsersEvent(streams.keys)
          new_user_join_msg = event_generator.createJoinEvent(username)

          connection << new_users_msg
          events << ['Users', new_users_msg]
          events << ['Join', new_user_join_msg]

          for event in events do
            if event[0] == 'Message' || event[0] == 'ServerStatus'
              connection << event[1]
            end
          end

          for c in connections do
            c << new_user_join_msg
          end
        end
        
        connection.callback do
          connections.delete(connection)
          streams.delete(username)
          user_part_msg = event_generator.createPartEvent(username)
          events << ['Part', user_part_msg]
          for c in connections do
            c << user_part_msg
          end
        end
      end
    end
  end
end

post '/login' do
  headers 'Access-Control-Allow-Origin' => '*'
  username = params['username']
  password = params['password']

  param_keys_expected = Set["username", "password"]
  param_keys_actual = params.keys.to_set
  if username == '' || password == '' || param_keys_expected != param_keys_actual
    status 422
  else
    if !registrations.has_key?(username) #new user registration
      registrations[username] = password
      status 201
      content_type 'application/json'
      new_msg_token = SecureRandom.uuid
      new_stream_token = "stream_token#{stream_token_num}"
      body_json = { :message_token => new_msg_token, :stream_token => new_stream_token }.to_json
      msg_tokens[new_msg_token] = username
      stream_tokens[new_stream_token] = username
      stream_token_num += 1
      body body_json
    else #existing user login
      if streams.has_key?(username)
        status 409
      elsif password != registrations[username]
        status 403
      else
        status 201
        content_type 'application/json'
        new_msg_token = SecureRandom.uuid
        new_stream_token = "stream_token#{stream_token_num}"
        body_json = { :message_token => new_msg_token, :stream_token => new_stream_token }.to_json
        msg_tokens[new_msg_token] = username
        stream_tokens[new_stream_token] = username
        stream_token_num += 1

        old_msg_token = msg_tokens.key(username)
        old_stream_token = stream_tokens.key(username)

        msg_tokens.delete(old_msg_token)
        stream_tokens.delete(old_stream_token)

        body body_json
      end
    end
  end
end

post '/message' do
  headers 'Access-Control-Allow-Origin' => '*'
  param_keys_expected = Set['message']
  param_keys_actual = params.keys.to_set

  if param_keys_actual != param_keys_expected || params['message'] == ''
    status 422
  else
    token = get_bearer_token(request.env)
    if !msg_tokens.has_key?(token)
      status 403
    elsif !streams.has_key?(msg_tokens[token])
      new_msg_token = SecureRandom.uuid
      username = msg_tokens.delete(token)
      msg_tokens[new_msg_token] = username
      headers 'Token' => new_msg_token
      status 409
    else
      new_msg_token = SecureRandom.uuid
      username = msg_tokens.delete(token)
      msg_tokens[new_msg_token] = username

      message = params['message']
      if message == "/quit"
        disconnect_msg = event_generator.createDisconnectEvent()
        events << ['Disconnect', disconnect_msg]

        user_stream = streams[username]
        user_stream << disconnect_msg
        user_stream.close

        headers 'Access-Control-Expose-Headers' => 'token'
        headers 'Token' => new_msg_token
        status 201
      elsif message == "/reconnect"
        user_stream = streams[username]
        user_stream.close

        headers 'Access-Control-Expose-Headers' => 'token'
        headers 'Token' => new_msg_token
        status 201
      elsif message.split()[0] == "/kick" && message.split().length == 2
        targeted_user = message.split()[1]
        if username == targeted_user || !streams.has_key?(targeted_user)
          status 409
        else
          server_kick_msg = event_generator.createServerStatusEvent("#{username} kicked #{targeted_user}")
          events << ['ServerStatus', server_kick_msg]

          targeted_user_stream = streams[targeted_user]
          targeted_user_stream.close

          connections.each do |connection|
            connection << server_kick_msg
          end
          
          headers 'Access-Control-Expose-Headers' => 'token'
          headers 'Token' => new_msg_token
          status 201
        end
      else
        new_msg = event_generator.createMessageEvent(message, username)
        connections.each do |connection|
          connection << new_msg
        end

        events << ['Message', new_msg]

        headers 'Access-Control-Expose-Headers' => 'token'
        headers 'Token' => new_msg_token
        status 201
      end
    end
  end
end
