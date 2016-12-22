class ProxyTestServer
  def call(env)
    [302, {"Content-Type" => "audio/foo"}, "test"]
  end
end

run ProxyTestServer.new
