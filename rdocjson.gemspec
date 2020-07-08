Gem::Specification.new do |spec|
  spec.name = "rdocjson"
  spec.license = "MIT"
  spec.summary = "JSON from RDoc"
  spec.version = "0.0.1"
  spec.author = "Dorian Marié"
  spec.email = "dorian@dorianmarie.fr"
  spec.homepage = "https://github.com/dorianmariefr/rdocjson"
  spec.add_dependency("rdoc", "~> 4.0")
  spec.add_dependency("json", "~> 2.3")
  spec.files = Dir["**/*.rb"]
end
