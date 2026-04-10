#!/usr/bin/env ruby
require "open-uri"
require "json"

ROOT = File.expand_path("..", __dir__)
papers_path = File.join(ROOT, "data", "papers.json")

papers = JSON.parse(File.read(papers_path))

repec_sources = [
  "https://econpapers.repec.org/",
  "https://ideas.repec.org/"
]

puts "Weekly refresh scaffold"
puts "Configured sources:"
repec_sources.each { |url| puts " - #{url}" }
puts "Tracked papers: #{papers.length}"
puts "This script is intended to be extended with source scraping or feed ingestion."
