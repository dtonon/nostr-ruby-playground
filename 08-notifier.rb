# Be alerted for new content or private messages
# Usage: ruby 08-checker.rb [word1, word2, ..., pub_key, ...]

require 'highline/import'
require 'schnorr'
require 'json'
require "base64"
require 'faye/websocket'
require 'eventmachine'

PINS = {
  "private": "⬛️", "0": "🟨", "1": "🟧", "2": "🟥", "3": "🟫", "4": "🟦", "5": "🟪", "6": "⬜️"
}

if ARGV[0]
  keywords_string = ARGV.join(" ")
end

if !keywords_string
  puts "\n🟥 What content you would like to be alerted of?"
  keywords_string = ask("> ") { |q| q.validate = /.{3,100}/ }
  puts
end

puts "\n🟥 How many hours I have to search back?"
puts "Press enter to just start from now"
$hours_history = ask("> ") { |q| q.validate = /|\d{1,2}/ }.to_i
puts

keywords_data = keywords_string.downcase.gsub(",", " ").split(" ").compact.reject{|k| k.empty? || k.size < 2}

recipients_data = []
keywords_data.each_with_index do |k, index|
  if k.size == 64 # is a pubkey
    recipients_data << k
    keywords_data.delete_at(index)
  end
end

relay_host = "wss://relay.damus.io" # 'wss://nostr-relay.wlvs.space' - 'ws://127.0.0.1'

def subscription_keywords(ignore_history = false)
  since = (ignore_history ? Time.now.utc : Time.now.utc - 60*60*$hours_history)
  debug = request = ["REQ", SecureRandom.random_number.to_s,
    { "kinds": [1, 42], "since": since.to_i  }
  ].to_json
end

def subscription_private(recipients_data, ignore_history = false)
  if recipients_data.any?
    since = (ignore_history ? Time.now.utc : Time.now.utc - 60*60*$hours_history)
    debug = request = ["REQ", SecureRandom.random_number.to_s,
      { "kinds": [4], "#p": recipients_data, "since": since.to_i, "limit": 1 }
    ].to_json
  end
end

$last_event = Time.now

def notify_if_interesting(event, keywords_data, recipients_data)
  hit = nil
  pin = nil
  event_recipients = nil
  if [1, 42].include?(event[2]["kind"])
    keywords_data.each_with_index do |k, index|
      if event[2]["content"].downcase.include?(k)
        hit = :keyword
        pin = index < 6 ? PINS[index.to_s.to_sym] : PINS["6".to_sym]
      end
    end
  end
  
  if [4].include?(event[2]["kind"])
    event_recipients = event[2]["tags"].select{ |t| t[0] == "p" }.first[1..-1]
    recipients_data.each do |k|
      if event_recipients.include?(k)
        hit = :recipient
        pin = PINS[:private]
      end
    end
  end
  
  case hit
  when :keyword
    puts "\n\n#{pin} " + event[2]["content"].strip
    puts "> Event ID #{event[2]["id"]}"
    puts "> From #{event[2]["pubkey"]}"
    puts "> At #{Time.at(event[2]["created_at"])}"
  when :recipient
    puts "\n\n#{pin} Private message"
    puts "> Event ID #{event[2]["id"]}"
    puts "> From #{event[2]["pubkey"]}"
    puts "> To #{event_recipients.join(", ")}"
    puts "> At #{Time.at(event[2]["created_at"])}"
  end

  # Make a sound
  if hit && Time.now - $last_event > 5
    print "\a"
  end
  $last_event = Time.now
end

def relay_connect(relay_host, keywords_data, recipients_data, ignore_history = false)

  ws = Faye::WebSocket::Client.new(relay_host, nil, {ping: 60})

  ws.on :open do |event|
    sr = subscription_keywords(ignore_history)
    ws.send sr
    sr = subscription_private(recipients_data, ignore_history)
    ws.send sr if sr
    puts "\n🟩 Ready to find new content!"
    puts "\nSearching for keywords:"
    keywords_data.each_with_index { |k, index| puts "#{PINS[index.to_s.to_sym]} #{k}"}
    puts "\nAnd direct messages to:"
    puts recipients_data.map{|r| "#{PINS[:private]} #{r}\n"}
  end

  ws.on :message do |msg|
    if !msg.data.empty?
      begin
        event = JSON.parse(msg.data)
        # puts "---------- Event -----------------\n#{event.inspect}\n\n"
        if event[0] == "EVENT" && [1, 4, 42].include?(event[2]["kind"])
          notify_if_interesting(event, keywords_data, recipients_data)
        end
      rescue JSON::ParserError
        return "🟥 " + msg.data.inspect + "\n\n"
      end
    end
  end

  ws.on :error do |event|
    # p [:error, event]
  end

  ws.on :close do |event|
    # p [:close, event.code, event.reason]
    puts "🟥 Reconnecting..."
    sleep(5)
    relay_connect(relay_host, keywords_data, recipients_data, true)
  end
end

EM.run {

  relay_connect(relay_host, keywords_data, recipients_data)
  
}