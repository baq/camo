require 'rubygems'
require 'json'
require 'base64'
require 'openssl'
require 'rest_client'
require 'addressable/uri'

require 'test/unit'

module CamoProxyTests
  def config
    { 'key'  => ENV['CAMO_KEY']  || "imwithher2016",
      'host' => ENV['CAMO_HOST'] || "http://localhost:8081" }
  end

  def spawn_server(path)
    port = 9292
    config = "test/servers/#{path}.ru"
    host = "localhost:#{port}"
    pid = fork do
      STDOUT.reopen "/dev/null"
      STDERR.reopen "/dev/null"
      exec "rackup", "--port", port.to_s, config
    end
    sleep 2
    begin
      yield host
    ensure
      Process.kill(:TERM, pid)
      Process.wait(pid)
    end
  end

  def test_follows_https_redirect_for_audio_links
    response = request('http://www.kqed.org/.stream/mp3splice/radio/tcr/2016/11/2016-11-02-tcr.mp3')
    assert_equal(200, response.code)
  end

  def test_doesnt_crash_with_non_url_encoded_url
    assert_raise RestClient::ResourceNotFound do
      RestClient.get("#{config['host']}/crashme?url=crash&url=me")
    end
  end

  def test_always_sets_security_headers
    ['/', '/status'].each do |path|
      response = RestClient.get("#{config['host']}#{path}")
      assert_equal "deny", response.headers[:x_frame_options]
      assert_equal "default-src 'none'; img-src data:; style-src 'unsafe-inline'", response.headers[:content_security_policy]
      assert_equal "nosniff", response.headers[:x_content_type_options]
      assert_equal "max-age=31536000; includeSubDomains", response.headers[:strict_transport_security]
    end

    response = request('http://www.kqed.org/.stream/mp3splice/radio/tcr/2016/11/2016-11-02-tcr.mp3')
    assert_equal "deny", response.headers[:x_frame_options]
    assert_equal "default-src 'none'; img-src data:; style-src 'unsafe-inline'", response.headers[:content_security_policy]
    assert_equal "nosniff", response.headers[:x_content_type_options]
    assert_equal "max-age=31536000; includeSubDomains", response.headers[:strict_transport_security]
  end

  def test_proxy_https_kqed
    response = request('https://s3-us-west-1.amazonaws.com/audio.prod.spoke/0002082016_Immigration_in_the_Election_mix_final.mp3')
    assert_equal(200, response.code)
  end

  def test_follows_redirects
    response = request('https://goo.gl/ngrpgx')
    assert_equal(200, response.code)
  end

  def test_proxy_valid_audio_url
    response = request('http://s3-us-west-1.amazonaws.com/audio.prod.spoke/0511112016_Quartz_at_60dB_Don_t_Unfriend_your_Friends_Talk_and_Listen_Instead.mp3')
    assert_equal(200, response.code)
  end

  def test_audio_with_delimited_content_type_url
    response = request('http://uploadir.com/u/kwm2g7kd')
    assert_equal(200, response.code)
  end
  
=begin  
  def test_proxy_localhost_test_server
    spawn_server(:ok) do |host|
      response = RestClient.get("http://localhost:9292/kqed.mp3")
      assert_equal(200, response.code)

      response = request("http://localhost:9292/kqed.mp3")
      assert_equal(200, response.code)
    end
  end

  def test_svg_image_with_delimited_content_type_url
    response = request('https://saucelabs.com/browser-matrix/bootstrap.svg')
    assert_equal(200, response.code)
  end

  def test_proxy_valid_image_url_with_crazy_subdomain
    response = request('http://27.media.tumblr.com/tumblr_lkp6rdDfRi1qce6mto1_500.jpg')
    assert_equal(200, response.code)
  end

  def test_strict_image_content_type_checking
    assert_raise RestClient::ResourceNotFound do
      request("http://calm-shore-1799.herokuapp.com/foo.png")
    end
  end

  def test_proxy_valid_google_chart_url
    response = request('http://chart.apis.google.com/chart?chs=920x200&chxl=0:%7C2010-08-13%7C2010-09-12%7C2010-10-12%7C2010-11-11%7C1:%7C0%7C0%7C0%7C0%7C0%7C0&chm=B,EBF5FB,0,0,0&chco=008Cd6&chls=3,1,0&chg=8.3,20,1,4&chd=s:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA&chxt=x,y&cht=lc')
    assert_equal(200, response.code)
  end

  def test_proxy_valid_chunked_image_file
    response = request('http://www.igvita.com/posts/12/spdyproxy-diagram.png')
    assert_equal(200, response.code)
    assert_nil(response.headers[:content_length])
  end

  def test_follows_redirects_formatted_strangely
    response = request('http://cl.ly/DPcp/Screen%20Shot%202012-01-17%20at%203.42.32%20PM.png')
    assert_equal(200, response.code)
  end

  def test_follows_redirects_with_path_only_location_headers
    assert_nothing_raised do
      request('http://blogs.msdn.com/photos/noahric/images/9948044/425x286.aspx')
    end
  end

  def test_forwards_404_with_image
    spawn_server(:not_found) do |host|
      uri = request_uri("http://#{host}/octocat.jpg")
      response = RestClient.get(uri){ |response, request, result| response }
      assert_equal(404, response.code)
      assert_equal("image/jpeg", response.headers[:content_type])
    end
  end

  def test_404s_on_request_error
    spawn_server(:crash_request) do |host|
      assert_raise RestClient::ResourceNotFound do
        request("http://#{host}/cats.png")
      end
    end
  end

  def test_404s_on_infinidirect
    assert_raise RestClient::ResourceNotFound do
      request('http://modeselektor.herokuapp.com/')
    end
  end

  def test_404s_on_urls_without_an_http_host
    assert_raise RestClient::ResourceNotFound do
      request('/picture/Mincemeat/Pimp.jpg')
    end
  end

  def test_404s_on_images_greater_than_5_megabytes
    assert_raise RestClient::ResourceNotFound do
      request('http://apod.nasa.gov/apod/image/0505/larryslookout_spirit_big.jpg')
    end
  end

  def test_404s_on_host_not_found
    assert_raise RestClient::ResourceNotFound do
      request('http://flabergasted.cx')
    end
  end

  def test_404s_on_non_image_content_type
    assert_raise RestClient::ResourceNotFound do
      request('https://github.com/atmos/cinderella/raw/master/bootstrap.sh')
    end
  end

  def test_404s_on_connect_timeout
    assert_raise RestClient::ResourceNotFound do
      request('http://10.0.0.1/foo.cgi')
    end
  end

  def test_404s_on_environmental_excludes
    assert_raise RestClient::ResourceNotFound do
      request('http://iphone.internal.example.org/foo.cgi')
    end
  end

  def test_follows_temporary_redirects
    response = request('http://bit.ly/1l9Fztb')
    assert_equal(200, response.code)
  end

  def test_request_from_self
    assert_raise RestClient::ResourceNotFound do
      uri = request_uri("http://camo-localhost-test.herokuapp.com")
      response = request( uri )
    end
  end

  def test_404s_send_cache_headers
    uri = request_uri("http://example.org/")
    response = RestClient.get(uri){ |response, request, result| response }
    assert_equal(404, response.code)
    assert_equal("0", response.headers[:expires])
    assert_equal("no-cache, no-store, private, must-revalidate", response.headers[:cache_control])
  end
  
  def test_proxy_survives_redirect_without_location
    spawn_server(:redirect_without_location) do |host|
      assert_raise RestClient::ResourceNotFound do
        request("http://#{host}")
      end
    end

    response = request('http://media.ebaumsworld.com/picture/Mincemeat/Pimp.jpg')
    assert_equal(200, response.code)
  end
=end
end

=begin
class CamoProxyQueryStringTest < Test::Unit::TestCase
  include CamoProxyTests

  def request_uri(audio_url)
    hexdigest = OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha1'), config['key'], audio_url)

    uri = Addressable::URI.parse("#{config['host']}/#{hexdigest}")
    uri.query_values = { 'url' => audio_url, 'repo' => '', 'path' => '' }

    uri.to_s
  end

  def request(audio_url)
    RestClient.get(request_uri(audio_url))
  end
end
=end

class CamoProxyPathTest < Test::Unit::TestCase
  include CamoProxyTests

  def hexenc(audio_url)
    audio_url.to_enum(:each_byte).map { |byte| "%02x" % byte }.join
  end

  def request_uri(audio_url)
    hexdigest = OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha1'), config['key'], audio_url)
    encoded_audio_url = hexenc(audio_url)
    "#{config['host']}/#{hexdigest}/#{encoded_audio_url}"
  end

  def request(audio_url)
    RestClient.get(request_uri(audio_url))
  end
end
