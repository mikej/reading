require 'faraday'
require 'nokogiri'

conn = Faraday.new(:url => 'https://www.goodreads.com')

user_id = ARGV[0]
key = ENV['GOODREADS_KEY']
per_page = 100
page = 1

loop do
  response = conn.get("/review/list/#{user_id}.xml?key=#{key}&v=2&per_page=#{per_page}&page=#{page}")
  doc = Nokogiri::XML(response.body)
  books = doc.xpath('//book')
  puts books.size
  page = page + 1
  break if books.size != per_page
end 