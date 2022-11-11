# Test Damus npub/nsec <=> standard key conversion
# npub/nsec are based on Bech32 / BIP 0173: https://en.bitcoin.it/wiki/Bech32
# Online tester: https://damus.io/key/

require './lib/segwit_addr'
require './lib/custom_addr'

puts "\nTest npub/nsec => standard key conversion"
puts "-----------------------------------------------------------\n\n"

addr = "npub1je9jj72avgwd4nc9lk20kgeqdjy8gtd3lfgtxnt4ghe6ygsasyjqjqum7q"
target_conversion = "964b29795d621cdacf05fd94fb23206c88742db1fa50b34d7545f3a2221d8124"
custom_addr = CustomAddr.new(addr)
conversion = custom_addr.to_scriptpubkey
puts "Source:                 #{addr}"
puts "Targed conversion:      #{target_conversion}"
puts "Conversion:             #{conversion}"
puts target_conversion == conversion ? "MATCH!" : "FAIL!"
# puts "Debug prog:\n#{custom_addr.prog}"

puts "\n\nTest standard => npub/nsec standard key conversion"
puts "-----------------------------------------------------------\n\n"

scriptpubkey = "964b29795d621cdacf05fd94fb23206c88742db1fa50b34d7545f3a2221d8124"
target_conversion = "npub1je9jj72avgwd4nc9lk20kgeqdjy8gtd3lfgtxnt4ghe6ygsasyjqjqum7q"
custom_addr = CustomAddr.new()
custom_addr.scriptpubkey = scriptpubkey
custom_addr.hrp = "npub"
conversion = custom_addr.addr
puts "Source                  #{scriptpubkey}"
puts "Targed conversion:      #{target_conversion}"
puts "Conversion:             #{conversion}"
puts target_conversion == conversion ? "MATCH!" : "FAIL!"
# puts "Debug prog =>           #{custom_addr.prog}"

puts "\n\nTest Segwit key conversion"
puts "-----------------------------------------------------------\n\n"

addr = "BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4"
target_conversion = "0014751e76e8199196d454941c45d1b3a323f1433bd6"
custom_addr = SegwitAddr.new(addr)
conversion = custom_addr.to_scriptpubkey
puts "Source                  #{addr}"
puts "Targed conversion:      #{target_conversion}"
puts "to_scriptpubkey:        #{conversion}"
puts target_conversion == conversion ? "MATCH!" : "FAIL!"