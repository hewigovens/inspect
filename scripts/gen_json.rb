#!/usr/bin/env ruby


require 'csv'
require 'json'

ca_set = {}
ev_set = {}

line = -1
CSV.foreach('mozilla_trust.csv') do |row|
    line = line + 1
    if line == 0
        next
    end
    key = row[5].tr(':', '').downcase
    ca_name = row[3]
    ev_oid = row[12]
    ca_set[key] = {CA: ca_name, EV: ev_oid != 'Not EV'}

    if ev_oid != "Not EV"
        ev_set[ev_oid] = true
    end
end

File.open('mozilla_trust.json', 'w') do |fd|
    fd.write(ca_set.to_json)
end

File.open('mozilla_ev.json', 'w') do |fd|
    fd.write(ev_set.to_json)
end
