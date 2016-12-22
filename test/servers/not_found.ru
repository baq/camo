run lambda { |env|
  path = File.expand_path('../kqed.mp3', __FILE__)
  data = File.read(path)
  [404, {'Content-Type' => 'audio/mpeg'}, [data]]
}
