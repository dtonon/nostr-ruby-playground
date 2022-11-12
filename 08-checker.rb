# Be alerted for new content or private messages
# Usage: ruby 08-checker.rb [word1, word2, ..., pub_key, ...]

require 'highline/import'
require 'schnorr'
require 'json'
require "base64"
require 'websocket-client-simple'

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

def subscription_request(recipients_data)
  request = ["REQ", SecureRandom.random_number.to_s]
  request << { "kinds": [1, 42], "since": (Time.now.utc - 60*60*$hours_history).to_i  }

  if recipients_data.any?
    request << { "kinds": [4], "#p": recipients_data, "since": (Time.now.utc - 60*60*$hours_history).to_i  }
  end
  request.to_json
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
    puts "> From #{event[2]["pubkey"]} at #{Time.at(event[2]["created_at"])}"
    puts "> At #{Time.at(event[2]["created_at"])}"
  when :recipient
    puts "\n\n#{pin} Private message"
    puts "> Event ID #{event[2]["id"]}"
    puts "> From #{event[2]["pubkey"]} at #{Time.at(event[2]["created_at"])}"
    puts "> To #{event_recipients.join(", ")}"
    puts "> At #{Time.at(event[2]["created_at"])}"
  end

  # Make a sound
  if hit && Time.now - $last_event > 5
    print "\a"
  end
  $last_event = Time.now
end

ws = WebSocket::Client::Simple.connect relay_host

ws.on :message do |msg|
  if !msg.data.empty?
    begin
      event = JSON.parse(msg.data)

      if event[0] == "EVENT" && [1, 4, 42].include?(event[2]["kind"])
        notify_if_interesting(event, keywords_data, recipients_data)
      end

      # puts "---------- Event -----------------\n#{event.inspect}\n\n"
      
    rescue JSON::ParserError
      return "🟥 " + msg.data.inspect + "\n\n"
    end
  end

end

ws.on :open do
  sr = subscription_request(recipients_data)
  ws.send sr
  puts "\n🟩 Ready to find new content!"
  puts "\nSearching for keywords:"
  keywords_data.each_with_index { |k, index| puts "#{PINS[index.to_s.to_sym]} #{k}"}
  puts "\nAnd direct messages to:"
  puts recipients_data.map{|r| "#{PINS[:private]} #{r}\n"}
end

ws.on :close do |e|
  p e
  exit 1
end

ws.on :error do |e|
  p e
end

loop do
end