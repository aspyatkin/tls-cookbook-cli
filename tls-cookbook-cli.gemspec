Gem::Specification.new do |s|
  s.name = 'tls-cookbook-cli'
  s.version = '1.0.0'
  s.date = '2017-06-14'
  s.summary = 'TLS Cookbook CLI'
  s.description = 'TLS Cookbook CLI'
  s.authors = ['Alexander Pyatkin']
  s.email = 'aspyatkin@gmail.com'
  s.files = [
    'lib/tls/cli.rb',
    'lib/tls/cli/main.rb',
    'lib/tls/cli/helpers.rb'
  ]
  s.executables = [
    'tls-cookbook-cli'
  ]
  s.homepage = 'https://github.com/aspyatkin/tls-cookbook-cli'
  s.license = 'MIT'

  s.required_ruby_version = '>= 2.3'

  s.add_dependency 'thor', '~> 0.19.1'

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'rake'
end
