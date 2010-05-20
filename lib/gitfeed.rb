require 'rubygems'
require 'git'
require 'haml'
require 'rss/maker'
require 'sinatra'

class Gitfeed
  RSS_VERSION = '2.0'

  def initialize(repository_path, options = {})
    @git = Git.open(repository_path)
    @title = options[:title] || "Gitfeed for #{repository_path.sub(/.*\//, '')}"
    @url = options[:url] || 'http://github.com/scotchi/gitfeed'
    @description = options[:description] || repository_path
    @template = options[:template] || File.expand_path('../entry.haml',  __FILE__)
    @include_diffs = options[:include_diffs].nil? ? true : options[:include_diffs]
    @haml = Haml::Engine.new(File.read(@template))
  end

  def feed
    RSS::Maker.make(RSS_VERSION) do |maker|
      maker.channel.title = @title
      maker.channel.link = @url
      maker.channel.description = @description
      maker.items.do_sort = true
      @git.log(20).each do |entry|
        item = maker.items.new_item
        item.title = entry.message.sub(/\n.*/m, '')
        item.link = @url
        item.date = entry.date
        item.description = description(entry)
      end
    end
  end

  class Server < Sinatra::Base
    def self.start(*args)
      @@gitfeed = Gitfeed.new(*args)
      get '/' do
        content_type('text/xml')
        @@gitfeed.feed.to_s
      end
      self.run!
    end
  end

  private

  def description(entry)
    @haml.render(self, :entry => entry)
  end
end
