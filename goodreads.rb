require 'faraday'
require 'nokogiri'
require 'yaml'
require 'oauth'

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
    consumer = OAuth::Consumer.new(@api_key, @api_secret, :site => "https://www.goodreads.com")
    @access_token = OAuth::AccessToken.new(consumer, config['access_token'], config['access_token_secret'])
  end

  def set_owned(access_token, book_id)
    response = access_token.post('/owned_books.xml', {
      'owned_book[book_id]' => book_id
    })
  end

  def get_non_owned
    get_books(sort: 'owned', order: 'a', stop_on_non_match: true) do |review_element|
      review_element.at_xpath('./owned').text == '0'
    end
  end

  def get_owned
    get_books(sort: 'owned', order: 'd', stop_on_non_match: true) do |review_element|
      review_element.at_xpath('./owned').text == '1'
    end
  end

  def get_books(options = {})
    conn = Faraday.new(:url => 'https://www.goodreads.com')
    per_page = 100
    page = 1

    books = []
    loop do
      url = "/review/list/#{@user_id}.xml?key=#{@api_key}&v=2&per_page=#{per_page}&page=#{page}"
      url << "&sort=#{options[:sort]}" if options.has_key? :sort
      url << "&order=#{options[:order]}" if options.has_key? :order
      url << "&shelf=#{options[:shelf]}" if options.has_key? :shelf
      response = conn.get(url)
      doc = Nokogiri::XML(response.body)
      review_elements = doc.xpath('//review')
      review_elements.each do |review_element|
        title = review_element.at_xpath('./book/title').text
        book_id = review_element.at_xpath('./book/id').text
        isbn = review_element.at_xpath('./book/isbn').text
        shelf_elements = review_element.xpath('./shelves/shelf')
        shelves = shelf_elements.map { |shelf_element| shelf_element['name'] }
        owned = review_element.at_xpath('./owned').text == '1' ? true : false
        if !block_given? || yield(review_element)
          books << Book.new(title, book_id, isbn, shelves, owned)
        else
          return books if options[:stop_on_non_match]
        end
      end
      page = page + 1
      return books if review_elements.size != per_page
    end
  end

end