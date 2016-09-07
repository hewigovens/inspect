#!/usr/bin/env ruby


require 'csv'
require 'json'

ca_set = {}

line = -1
CSV.foreach('mozilla_trust.csv') do |row|
    line = line + 1
    if line == 0
        next
    end
    key = row[4].tr(':', '').downcase
    ca_set[key] = true
end

File.open('mozilla_trust.json', 'w') do |fd|
    fd.write(ca_set.to_json)
end
