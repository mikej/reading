require 'faraday'
require 'nokogiri'
require 'yaml'

class Book
  attr_reader :title, :book_id, :isbn, :shelves

  def initialize(title, book_id, isbn, shelves, owned)
    @title = title
    @book_id = book_id
    @isbn = isbn
    @shelves = shelves
    @owned = owned
  end

  def owned?
    @owned
  end
end

class Goodreads

  def initialize
    config = YAML.load_file('reading.yml')['goodreads']
    @api_key = config['api_key']
    @api_secret = config['api_secret']
    @user_id = config['user_id']
  end

  def get_books
    conn = Faraday.new(:url => 'https://www.goodreads.com')
    per_page = 100
    page = 1

    books = []
    loop do
      response = conn.get("/review/list/#{@user_id}.xml?key=#{@api_key}&v=2&per_page=#{per_page}&page=#{page}")
      doc = Nokogiri::XML(response.body)
      review_elements = doc.xpath('//review')
      review_elements.each do |review_element|
        title = review_element.at_xpath('./book/title').text
        book_id = review_element.at_xpath('./book/id').text
        isbn = review_element.at_xpath('./book/isbn').text
        shelf_elements = review_element.xpath('./shelves/shelf')
        shelves = shelf_elements.map { |shelf_element| shelf_element['name'] }
        owned = review_element.at_xpath('./owned').text == '1' ? true : false
        books << Book.new(title, book_id, isbn, shelves, owned)
      end
      page = page + 1
      break if review_elements.size != per_page
    end
    books
  end

end