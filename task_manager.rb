#!/usr/bin/env ruby
"""
Simple task/epic/story manager script
Usage:
  task_manager.rb create [epic|story|task] --title TITLE --description DESC [options]
  task_manager.rb comment [epic|story|task] ID --comment TEXT

Data stored in ~/.task_manager_data.yml
"""
require 'optparse'
require 'yaml'
require 'time'
require 'fileutils'

DATA_FILE = File.expand_path("~/.task_manager_data.yml")

def load_data
  if File.exist?(DATA_FILE)
    YAML.load_file(DATA_FILE) || {'epics'=>[], 'stories'=>[], 'tasks'=>[], 'comments'=>[]}
  else
    {'epics'=>[], 'stories'=>[], 'tasks'=>[], 'comments'=>[]}
  end
end

def save_data(data)
  dir = File.dirname(DATA_FILE)
  FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
  File.open(DATA_FILE, 'w') { |f| f.write(data.to_yaml) }
end

def next_id(list)
  list.empty? ? 1 : (list.map{|i| i['id']}.max + 1)
end

def create_item(type, opts)
  data = load_data
  key = type + 's'
  abort "Unknown type: #{type}" unless data.key?(key)
  list = data[key]
  id = next_id(list)
  now = Time.now.iso8601
  item = {
    'id' => id,
    'title' => opts[:title],
    'description' => opts[:description],
    'story_points' => opts[:story_points],
    'difficulty' => opts[:difficulty],
    'date_created' => now,
    'date_started' => opts[:date_started],
    'date_completed' => opts[:date_completed]
  }
  list << item
  save_data(data)
  puts "#{type.capitalize} ##{id} created."
end

def comment_item(type, id, text)
  data = load_data
  key = type + 's'
  list = data[key]
  item = list.find{|i| i['id'] == id.to_i}
  abort "#{type.capitalize} ##{id} not found." unless item
  comments = data['comments']
  cid = next_id(comments)
  now = Time.now.iso8601
  comment = {'id'=>cid, 'type'=>type, 'item_id'=>item['id'], 'comment'=>text, 'date_created'=>now}
  comments << comment
  save_data(data)
  puts "Comment ##{cid} added to #{type} ##{id}."
end

def usage
  puts <<-USAGE
Usage:
  #{File.basename($0)} create [epic|story|task] --title TITLE --description DESC [options]
  #{File.basename($0)} comment [epic|story|task] ID --comment TEXT

Options:
  --title TITLE
  --description DESC
  --story_points N
  --difficulty HOURS
  --date_started YYYY-MM-DD
  --date_completed YYYY-MM-DD
  --comment TEXT
USAGE
  exit 1
end

if ARGV.empty?
  usage
end

cmd = ARGV.shift
case cmd
when 'create'
  type = ARGV.shift
  opts = {}
  parser = OptionParser.new do |o|
    o.on('--title TITLE', 'Title') { |v| opts[:title] = v }
    o.on('--description DESC', 'Description') { |v| opts[:description] = v }
    o.on('--story_points N', Integer, 'Story points') { |v| opts[:story_points] = v }
    o.on('--difficulty H', Float, 'Difficulty hours') { |v| opts[:difficulty] = v }
    o.on('--date_started D', 'Date started') { |v| opts[:date_started] = v }
    o.on('--date_completed D', 'Date completed') { |v| opts[:date_completed] = v }
  end
  begin
    parser.parse!(ARGV)
  rescue OptionParser::InvalidOption => e
    abort e.message
  end
  unless %w(epic story task).include?(type) && opts[:title] && opts[:description]
    usage
  end
  create_item(type, opts)
when 'comment'
  type = ARGV.shift
  id = ARGV.shift
  opts = {}
  parser = OptionParser.new do |o|
    o.on('--comment TEXT', 'Comment text') { |v| opts[:comment] = v }
  end
  begin
    parser.parse!(ARGV)
  rescue OptionParser::InvalidOption => e
    abort e.message
  end
  unless %w(epic story task).include?(type) && id && opts[:comment]
    usage
  end
  comment_item(type, id, opts[:comment])
else
  usage
end