#! /usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'byebug'
require 'capybara-webkit'
require './mechanize_capybara'

Capybara::Webkit.configure do |config|
  config.allow_unknown_urls
  config.skip_image_loading  = false
end
Capybara.javascript_driver = :webkit_debug
Capybara.current_driver = :webkit

puts "Malaysian Amateur Radio Station"
puts "---------------------------------"
print "Please enter your callsign: "
callsign = gets
puts "Getting data for #{callsign.upcase}"

# Fetch and parse HTML document
agent = MerchanizeCapybaraClient.new
page_url = "https://www.mcmc.gov.my/legal/registers/register-of-apparatus-assignments-search?src=#{callsign}&fld=CallSign&type=AARadio"
@page = agent.get(page_url)
@page.wait_for_and_stop_waiting('.footer-widget', 5)

if @page.search('table.tableStyle01 tbody tr td.Holder')[0]&.text == nil
  puts "---------------------------------"
  puts "Sorry! There is no data for for #{callsign.upcase}"
  puts "---------------------------------"
else
  puts "---------------------------------"
  holder = @page.search('table.tableStyle01 tbody tr td.Holder')[0]&.text.strip.gsub("\n"," ")
  puts "Holder: " + holder
  callsign = @page.search('table.tableStyle01 tbody tr td.Callsign')[0]&.text.strip.gsub("\n"," ")
  puts "Callsign: " + callsign
  assign = @page.search('table.tableStyle01 tbody tr td.AssignNo')[0]&.text.strip.gsub("\n"," ")
  puts "Assignment No: " + assign
  expiry_date = @page.search('table.tableStyle01 tbody tr td.ExpiryDate')[0]&.text.strip.gsub("\n"," ")
  puts "Expiry Date: " + expiry_date
  puts "---------------------------------"
end
