require 'cgi'
require 'optparse'
require 'yaml'

require 'nokogiri'

require_relative 'model'

def validate_config(config)
  valid = true

  keys = ["email_from", "email_to", "local_craigslist", "queries"]
  keys.each do |k|
    if not config.has_key? k
      $stderr.puts "error: config.yml missing key: #{k}"
      valid = false
    end
  end

  defaults = {"email_subject_prefix" => "new apartment found:", "bedrooms" => "",
    "min_price" => "", "max_price" => ""}
  defaults.each do |k, v|
    if not config.has_key? k
      config[k] = v
      puts "notice: using default value '#{v}' for '#{k}'" if config["verbose"]
    end
  end

  exit(1) if not valid
end

def generate_uas
  base = ['Mozilla/5.0 (Windows _NTVER_;_ARCH_ rv:15.0) Gecko/20120427 Firefox/15.0a1',
          'Mozilla/5.0 (Windows _NTVER_;_ARCH_ rv:14.0) Gecko/20120405 Firefox/14.0a1',
          'Mozilla/5.0 (Windows _NTVER_;_ARCH_ rv:12.0) Gecko/20120403211507 Firefox/12.0',
          'Mozilla/5.0 (Windows _NTVER_;_ARCH_ rv:11.0) Gecko Firefox/11.0']
  
  agents = []
  base.each do |b|
    ["", " WOW64;"].each do |arch|
      ["5.1", "6.1", "6.1"].each do |ntver|
        agents << b.sub("_NTVER_", ntver).sub("_ARCH_", arch)
      end
    end
  end

  return agents
end

def fetch_url(url, ua)
  sleep(5 + rand(60))

  # yes, this is disgusting
  curl = "curl -s -A '#{ua}' '#{url}'"
  resp = %x{#{curl}}
end

def sendmail(msg)
  puts msg
  File.popen('/usr/lib/sendmail -oi -t -oem -odb', "w") do |pipe|
    pipe.puts msg
  end
end

def main
  cfg = YAML.load_file('config.yml')
  cfg["verbose"] = false

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"
    opts.on("-h", "--help", "Show this message") {
      puts opts
      exit
    }
    opts.on("-v", 'Be verbose') { cfg["verbose"] = true }
  end.parse!

  validate_config(cfg)
  initdb()

  uas = generate_uas

  # store posts here to send all emails at once
  newposts = []

  cfg['queries'].each do |query|
    ua = uas.sample
    url = "#{cfg['local_craigslist']}/search/apa?query=#{CGI.escape query}&srchType=A&minAsk=#{cfg['min_price']}&maxAsk=#{cfg['max_price']}&bedrooms=#{cfg['bedrooms']}"
    puts "checking #{url}" if cfg["verbose"]

    doc = Nokogiri::HTML fetch_url(url, ua), nil, 'utf-8'

    doc.search("p.row").each do |row|
      begin
        if row.at("span.itemdate").nil? or row.at("a").nil? or not row.at("a").has_attribute? "href"
          puts "skipping row with nil values: #{row}" if cfg["verbose"]
          next
        end

        date = row.at("span.itemdate").content.strip
        purl = row.at("a")['href']
        title = row.at("a").content.strip

        p = Post.where(:url => purl)
        if p.length > 0
          puts "skipping known post: #{purl}" if cfg["verbose"]
          next
        end

        p = Post.new(:url => purl, :title => title, :postdate => date)
        p.page = fetch_url(purl, ua)
        p.save!

        newposts << p

      rescue Exception => e
        $stderr.puts "encountered exception handling row: #{row}"
        $stderr.puts e.message
        $stderr.puts e.backtrace.inspect
      end
    end
  end

  newposts.each do |post|
    sendmail(getmsg(post, cfg))
  end
end

main
