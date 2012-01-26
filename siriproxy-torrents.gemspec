# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "siriproxy-torrents"
  s.version     = "0.0.1" 
  s.authors     = ["d3x"]
  s.email       = [""]
  s.homepage    = ""
  s.summary     = %q{Siri torrentleech plugin}
  s.description = %q{A torrentleech.org plugin allowing you to order Siri to download torrents for you}

  #s.rubyforge_project = ""

  s.files         = `git ls-files 2> /dev/null`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/* 2> /dev/null`.split("\n")
  s.executables   = `git ls-files -- bin/* 2> /dev/null`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_runtime_dependency 'hpricot'
  s.add_runtime_dependency 'multipart-post'
end
