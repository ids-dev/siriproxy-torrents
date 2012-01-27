require 'siri_objects'
require 'pp'
require 'hpricot'
require 'net/http'
require 'net/http/post/multipart'

class SiriProxy::Plugin::Torrents < SiriProxy::Plugin
  # Siri passes small numbers as words.
  # We use a hash to convert them back to integers
  @@numbers = {'one' => 1, 'two' => 2, 'three' => 3, 'four' => 4, 'five' => 5,
               'six' => 6, 'seven' => 7, 'eight' => 8, 'nine' => 9, 'ten' => 10}

  def initialize(config)
    @torrentleech = {
      login: config['torrentleech']['login'],
      password: config['torrentleech']['password'],
      http: Net::HTTP.new('torrentleech.org')
    }

    @utorrent = {
      host: config['utorrent']['host'],
      login: config['utorrent']['login'],
      password: config['utorrent']['password']
    }
  end

  def get_cookies_from_response(response)
    cookies = response.to_hash['set-cookie']
    return '' if cookies.nil?
    cookies = cookies.map{|i| i.split(';')[0].split '='}.flatten
    cookies = Hash[*cookies].reject{|k, v| v == 'deleted'}
    cookies.map{|k, v| "#{k}=#{v}"}.join '; '
  end

  def torrentleech_login
    request = Net::HTTP::Post.new '/user/account/login'
    request.set_form_data({'username' => @torrentleech[:login], 'password' => @torrentleech[:password]})
    response = @torrentleech[:http].request request
    cookies = get_cookies_from_response response
    @torrentleech[:cookies] = cookies unless cookies.empty?
  end

  def torrentleech_search(query)
    torrentleech_login if @torrentleech[:cookies].nil?
    request = Net::HTTP::Get.new "/torrents/browse/index/query/#{query}/order/desc/orderby/seeders"
    request['Cookie'] = @torrentleech[:cookies]
    response = @torrentleech[:http].request request
    cookies = get_cookies_from_response response
    @torrentleech[:cookies] = cookies unless cookies.empty?
    html = Hpricot(response.body)
    results = []
    (html/'table#torrenttable/tbody/tr:lt(3)').each do |row|
        results << {
            title:    (row / 'td[2]/span.title/a').inner_text,
            href:     (row % 'td[3]/a')['href'],
            size:     (row / 'td[5]').inner_text,
            seeders:  (row / 'td[7]').inner_text,
            leechers: (row / 'td[8]').inner_text
        }
    end
    results
  end

  def utorrent_get_token
    uri = URI("http://#{@utorrent[:host]}/gui/token.html?t=#{Time.now.to_i}")
    request = Net::HTTP::Get.new uri.request_uri
    request.basic_auth @utorrent[:login], @utorrent[:password]

    response = Net::HTTP.start uri.hostname, uri.port do |http|
      http.request request
    end

    cookies = get_cookies_from_response response
    @utorrent[:cookies] = cookies unless cookies.empty?

    (Hpricot(response.body) % 'div').inner_text
  end

  def say_results(results)
    results.each_with_index do |result, i|
      say "#{result[:title]} (#{result[:size]}, #{result[:seeders]} seeders, #{result[:leechers]} leechers)", spoken: "#{i + 1}. #{result[:title]}"
    end
  end

  def start_download(id)
    result = @torrentleech[:results][id]

    request = Net::HTTP::Get.new result[:href]
    request['Cookie'] = @torrentleech[:cookies]
    response = @torrentleech[:http].request request

    cookies = get_cookies_from_response response
    @torrentleech[:cookies] = cookies unless cookies.empty?

    @utorrent[:token] = utorrent_get_token if @utorrent[:token].nil?

    uri = URI("http://#{@utorrent[:host]}/gui/")
    params = {token: @utorrent[:token], action: 'add-file', download_dir: 0, path: ''}
    uri.query = URI.encode_www_form(params)

    request = Net::HTTP::Post::Multipart.new uri.request_uri, torrent_file: UploadIO.new(StringIO.new(response.body), 'application/octet-stream', result[:href].split('/').last)
    request.basic_auth @utorrent[:login], @utorrent[:password]
    request['Cookie'] = @utorrent[:cookies]

    response = Net::HTTP.start uri.hostname, uri.port do |http|
      http.request request
    end

    say "Downloading #{result[:title]}"
  end

  listen_for /download (.*)/i do |name|
    @torrentleech[:results] = torrentleech_search name
    say_results @torrentleech[:results][0..2]
    response = ask "Which one should i download?"

    if response =~ /(?:number )?([1-3]|one|two|three)/i
      match = $1
      match = @@numbers[match] if @@numbers.key? match
      start_download match.to_i - 1
      #elsif response =~ /show more results/i
      #say_results @results[3..5]
    else
      say "Download cancelled"
    end
    request_completed
  end
end
