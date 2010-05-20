require 'rubygems'
require 'git'
require 'haml'
require 'rss/maker'
require 'sinatra'

# A Git to RSS converter

class Gitfeed

  RSS_VERSION = '2.0'

  # Creates a Gitfeed instance for a specific Git repository where each change
  # is an RSS entry.
  #
  # @param [String] repository_path Path to a Git repository
  # @param [Hash] options Options for the created RSS feed
  #
  # @option options [String] :title ("Gitfeed for Repository")
  #  Title for the RSS feed
  # @option options [String] :url ("http://github.com/scotchi.net/gitfeed")
  #  Base URL for the RSS feed and all links
  # @option options [String] :description (repository_path)
  #  Description of the RSS feed
  # @option options [String] :template ("entry.haml")
  #  Path to a Haml template for the individual entries
  # @option options [Boolean] :include_diffs (true)
  #  Include diffs in the RSS output

  def initialize(repository_path, options = {})
    @git = Git.open(repository_path)
    @title = options[:title] || "Gitfeed for #{repository_path.sub(/.*\//, '')}"
    @url = options[:url] || 'http://github.com/scotchi/gitfeed'
    @description = options[:description] || repository_path
    @template = options[:template] || File.expand_path('../entry.haml',  __FILE__)
    @include_diffs = options[:include_diffs].nil? ? true : options[:include_diffs]
    @haml = Haml::Engine.new(File.read(@template))
  end

  # @return [String] An RSS v2 XML stream of the most recent git commits

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
    end.to_s
  end

  # A Sinatra-based stand-alone server that serves up an RSS feed of the
  # changes in the specified repository.

  class Server < Sinatra::Base

    # Starts a standalone server. The arguments are identical to Gitfeed.new

    def self.start(*args)
      @@gitfeed = Gitfeed.new(*args)
      get '/' do
        content_type('text/xml')
        @@gitfeed.feed
      end
      self.run!
    end
  end

  private

  def description(entry)
    @haml.render(self, :entry => entry)
  end
end
