require "net/http/responses.rb"

class MerchanizeCapybaraClient
  attr_accessor :timeout
  attr_accessor :session

  def initialize()
    @timeout = 10
    @session ||= Capybara::Session.new(:webkit)
    @session.driver.header('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36')
  end

  def get(url)
    # https://github.com/thoughtbot/capybara-webkit/blob/2e869bb9b71394c10429b45a5338fe7342f1eacb/lib/capybara/webkit/configuration.rb
    begin
      @session.visit(url)
      # puts "status: #{@session.status_code}"
      unless [200, 302].include?(@session.status_code)
      	raise Mechanize::ResponseCodeError.new(MerchanizeCapybaraPage.new(@session), "invalid status: #{@session.status_code}")
      end
      page = MerchanizeCapybaraPage.new(@session)
      page.timeout = @timeout
      return page
      #InvalidResponseError
    rescue Capybara::Webkit::InvalidResponseError => e
    	raise Mechanize::ResponseCodeError.new MerchanizeCapybaraPage.new(@session), e.message
   	rescue Exception => e
   		puts "unknown error: #{e.inspect}"
   		raise e
    end
  end
end

class MerchanizeCapybaraElement
  attr_accessor :timeout, :page
  attr_accessor :node, :nokonode

  def initialize(page, node, timeout=10)
    @node = node
    @page = page
    @timeout = timeout
    @started = timeout
    if @node.nil?
      raise ArgumentError.new("node is nil")
    end
  end

  def name
    @node.name
  end

  def attr(name)
    @node.attr(name)
  end

  def reset_timer
    @started = nil
  end

  def search(selector, options={})
    # no more wait
    res = []
    list = @node.css(selector)
    list.each{|node|
      res << MerchanizeCapybaraElement.new(@page, node, @timeout)
    }

    return MerchanizeCapybaraNodes.new(@page, res, @timeout)
  end

  def at(selector, options={})
    # #reloads
    res = @node.at_css(selector)
    puts "selector: #{selector}: #{res.inspect}"
    return nil if res.nil?
    return MerchanizeCapybaraElement.new(@page, res, @timeout)
  end


  def at_css(selector, options={})
    return at(selector, options)
  end

  def css(selector, options={})
    return at(selector, options)
  end

  def children
    list = []
    @node.children.each do |node|
      list << MerchanizeCapybaraElement.new(@page, node, @timeout)
    end
    MerchanizeCapybaraNodes.new(@page, list, @timeout)
  end

  def next
    return nil if @node.next.nil?
    MerchanizeCapybaraElement.new(@page, @node.next, @timeout)
  end

  def text
    @node.text
  end

  # attribute
  def [](key)
    @node[key]
  end

end

class MerchanizeCapybaraNodes
  include Enumerable
  attr_accessor :nodes, :page

  def each(&block)
    return enum_for(__method__) if block.nil?
    @nodes.each do |ob|
      block.call(ob)
    end
  end

  def initialize(page, nodes, timeout)
    @page = page
    @timeout = timeout
    unless nodes.kind_of?(Array)
      raise "Invalid nodes: #{nodes.inspect}"
    end
    @nodes = nodes
  end

  def search(selector, options={})
    res = []
    @nodes.each do |node|
      res = res.concat(node.search(selector, options).nodes)
    end
    MerchanizeCapybaraNodes.new(@page, res, @timeout)
  end

  def at(selector, options={})
    @nodes.each do |node|
      res = node.at(selector, options)
      return res if !res.nil?
    end
    nil
  end

  def first
    if size < 0
      return nil
    end
    @nodes[0]
  end

  def last
    if size < 0
      return nil
    end
    @nodes[@nodes.size-1]
  end

  def size
    @nodes.size
  end

  def []=(i, value)
    @nodes[i] = value
  end

  def [](i)
    @nodes[i]
  end
end

class MerchanizeCapybaraPage
  attr_accessor :timeout, :session, :page
  attr_accessor :status_code

  def initialize(session)
    @session = session
    @session.find("body")#wait for body
    @page = Nokogiri::HTML(@session.html)
    @timeout = 10
    @url = @session.current_url
    @status_code = @session.status_code
  end

  def uri
    @session.current_url
  end

  def code
  	@status_code
  end

  def content
    @session.html
  end

  def html
  	content
  end

  def wait_for_and_stop_waiting(selector, timeout, options={})
    @timeout = timeout
    search(selector, options)
  end

  def css(selector, options={})
    search(selector, )
  end

  def search(selector, options={})
    @started ||= Time.now

    # trigger capybara wait, until element exists
    list = @session.all(:css, selector, options)
    while list.size < 1 && (Time.now-@started) < @timeout
      # log_info "search: waiting #{selector}..."
      sleep 0.1
      list = @session.all(:css, selector, options)
    end
    if list.size < 1
      # puts "search: missing #{selector}!"
    end
    #reloads
    @page = Nokogiri::HTML(@session.html)

    res = []
    list = @page.css(selector)
    list.each{|node|
      res << MerchanizeCapybaraElement.new(@page, node, @timeout)
    }
    return MerchanizeCapybaraNodes.new(@page, res, @timeout)
  end


  def at(selector, options={})
    @started ||= Time.now
    res = @session.first(:css, selector, options)

    # trigger capybara wait, until element exists
    while res.nil? && (Time.now-started) < @timeout
      puts "element: waiting #{selector}..."
      sleep 0.1
      res = @session.first(:css, selector, options)
    end
    #reloads
    @page = Nokogiri::HTML(@session.html)
    puts "selector: #{selector}: #{res.inspect}"
    res = @page.at_css(selector)
    return MerchanizeCapybaraElement.new(@page, res, @timeout)
  end

  def at_css(selector, options={})
    return at(selector, options)
  end

  def session
    @session
  end
end
