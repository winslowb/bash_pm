#!/usr/bin/env ruby
# CLI tool for creating epics, stories, and tasks, and adding comments.

require 'json'
require 'optparse'
require 'time'
require 'fileutils'

# Default data file in the user's home directory
DATA_FILE = File.join(Dir.home, '.task_tracker.json')

# Load existing data or initialize empty structure
def load_data
  if File.exist?(DATA_FILE)
    JSON.parse(File.read(DATA_FILE), symbolize_names: true)
  else
    { items: [] }
  end
end

# Save data back to the file, creating directories as needed
def save_data(data)
  FileUtils.mkdir_p(File.dirname(DATA_FILE))
  File.write(DATA_FILE, JSON.pretty_generate(data))
end

# Print usage and exit
def usage
  name = File.basename(__FILE__)
  puts <<~USAGE
    Usage:
      #{name} create [epic|story|task] --title TITLE --description DESC --points N --difficulty HRS
      #{name} comment ID --comment TEXT
      #{name} help

    Commands:
      create    Create a new epic, story, or task.
      comment   Add a comment to an item by ID.
      help      Show this help message.

    Options for 'create':
      --title TITLE         (required) Title of the item
      --description DESC    (required) Description of the item
      --points N            Story points (integer, default: 0)
      --difficulty HRS      Difficulty in engineering hours (float, default: 0.0)

    Options for 'comment':
      --comment TEXT        (required) Comment text
  USAGE
  exit 1
end

# Main entrypoint
if ARGV.empty? || %w[help -h --help].include?(ARGV[0])
  usage
end

command = ARGV.shift
case command
when 'create'
  # Expect type next
  type = ARGV.shift
  unless %w[epic story task].include?(type)
    puts "Error: type must be 'epic', 'story', or 'task'."
    usage
  end
  options = { points: 0, difficulty: 0.0 }
  OptionParser.new do |opts|
    opts.on('--title TITLE', 'Title of the item')        { |v| options[:title] = v }
    opts.on('--description DESC', 'Description')         { |v| options[:description] = v }
    opts.on('--points N', Integer, 'Story points')       { |v| options[:points] = v }
    opts.on('--difficulty HRS', Float, 'Difficulty')     { |v| options[:difficulty] = v }
    opts.on('-h', '--help', 'Show help')                 { usage }
  end.parse!(ARGV)
  # Validate required fields
  unless options[:title] && options[:description]
    puts 'Error: --title and --description are required.'
    usage
  end
  data = load_data
  next_id = (data[:items].map { |i| i[:id] }.max || 0) + 1
  # Build new item
  item = {
    id: next_id,
    type: type,
    title: options[:title],
    description: options[:description],
    story_points: options[:points],
    difficulty: options[:difficulty],
    date_created: Time.now.iso8601,
    date_started: nil,
    date_completed: nil,
    comments: []
  }
  data[:items] << item
  save_data(data)
  puts "Created #{type} with ID #{next_id}."

when 'comment'
  # Expect ID next
  id = ARGV.shift&.to_i
  unless id && id > 0
    puts 'Error: Valid ID is required.'
    usage
  end
  options = {}
  OptionParser.new do |opts|
    opts.on('--comment TEXT', 'Comment text') { |v| options[:comment] = v }
    opts.on('-h', '--help', 'Show help')     { usage }
  end.parse!(ARGV)
  unless options[:comment]
    puts 'Error: --comment is required.'
    usage
  end
  data = load_data
  item = data[:items].find { |i| i[:id] == id }
  unless item
    puts "Error: No item found with ID #{id}."
    exit 1
  end
  item[:comments] << { text: options[:comment], timestamp: Time.now.iso8601 }
  save_data(data)
  puts "Added comment to item ID #{id}."

else
  usage
end