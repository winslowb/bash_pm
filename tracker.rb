#!/usr/bin/env ruby
require 'json'
require 'date'
require 'optparse'

# Data file stored in user's home directory
DATA_FILE = File.expand_path('~/.tracker_data.json')

def load_data
  if File.exist?(DATA_FILE)
    JSON.parse(File.read(DATA_FILE), symbolize_names: true)
  else
    { items: [] }
  end
end

def save_data(data)
  File.write(DATA_FILE, JSON.pretty_generate(data))
end

def next_id(data)
  ids = data[:items].map { |i| i[:id] }
  ids.empty? ? 1 : ids.max + 1
end

def create_item(type, options)
  data = load_data
  id = next_id(data)
  now = DateTime.now.iso8601
  item = {
    id: id,
    type: type,
    title: options[:title],
    description: options[:description],
    story_points: options[:story_points] || 0,
    difficulty: options[:difficulty] || 0,
    date_created: now,
    date_started: options[:date_started],
    date_completed: options[:date_completed],
    comments: []
  }
  data[:items] << item
  save_data(data)
  puts "Created #{type} ##{id}"
end

def add_comment(id, text)
  data = load_data
  item = data[:items].find { |i| i[:id] == id }
  unless item
    puts "Item ##{id} not found"
    exit 1
  end
  comment = { timestamp: DateTime.now.iso8601, text: text }
  item[:comments] << comment
  save_data(data)
  puts "Added comment to item ##{id}"
end

def list_items
  data = load_data
  data[:items].each do |i|
    puts "#{i[:type].capitalize} ##{i[:id]}: #{i[:title]}"
  end
end

# Main CLI dispatch
command = ARGV.shift
case command
when 'create'
  type = ARGV.shift
  unless %w[epic story task].include?(type)
    abort "Type must be 'epic', 'story', or 'task'"
  end
  options = {}
  optparser = OptionParser.new do |opts|
    opts.banner = "Usage: tracker.rb create #{type} [options]"
    opts.on('--title TITLE', 'Title (required)') { |v| options[:title] = v }
    opts.on('--description DESC', 'Description (required)') { |v| options[:description] = v }
    opts.on('--story-points N', Integer, 'Story points (integer)') { |v| options[:story_points] = v }
    opts.on('--difficulty N', Integer, 'Difficulty (engineering hours)') { |v| options[:difficulty] = v }
    opts.on('--date-started DATE', 'Date started (YYYY-MM-DD)') { |v| options[:date_started] = v }
    opts.on('--date-completed DATE', 'Date completed (YYYY-MM-DD)') { |v| options[:date_completed] = v }
  end
  begin
    optparser.parse!(ARGV)
    %i[title description].each do |field|
      abort "Missing --#{field.to_s.tr('_', '-')}" unless options[field]
    end
  rescue OptionParser::ParseError => e
    abort e.message
  end
  create_item(type, options)

when 'comment'
  id_str = ARGV.shift
  unless id_str =~ /^\d+$/
    abort "Usage: tracker.rb comment <id> --text 'comment'"
  end
  id = id_str.to_i
  text = nil
  optparser = OptionParser.new do |opts|
    opts.on('--text TEXT', 'Comment text (required)') { |v| text = v }
  end
  begin
    optparser.parse!(ARGV)
    abort "Missing --text" unless text
  rescue OptionParser::ParseError => e
    abort e.message
  end
  add_comment(id, text)

when 'list'
  list_items

else
  puts <<~USAGE
    Usage:
      tracker.rb create [epic|story|task] --title TITLE --description DESC [--story-points N] [--difficulty N] [--date-started YYYY-MM-DD] [--date-completed YYYY-MM-DD]
      tracker.rb comment <id> --text TEXT
      tracker.rb list
  USAGE
end