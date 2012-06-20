require 'net/smtp'

require 'active_record'

class Post < ActiveRecord::Base
  validates_uniqueness_of :url
end

def initdb
  ActiveRecord::Base.establish_connection(:adapter => 'sqlite3',
                                          :database => 'db.sqlite3')
  ActiveRecord::Migrator.migrate("migrate/")
end

def getmsg(post, cfg)
  subj = "#{cfg['email_subject_prefix']} #{post.postdate} #{post.title}"

  message = "From: #{cfg['email_from']}\nTo: #{cfg['email_to']}\nSubject: #{subj}\n
    #{post.postdate} #{post.title}
    #{post.url}"
end
