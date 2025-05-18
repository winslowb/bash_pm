#!/usr/bin/env ruby

require 'json'
require 'optparse'
require 'date'

class DataStore
  DATA_FILE = File.join(Dir.pwd, 'agile_data.json')

  def initialize
    if File.exist?(DATA_FILE)
      @data = JSON.parse(File.read(DATA_FILE))
    else
      @data = { "next_id" => 1, "entities" => [] }
      save
    end
  end

  def save
    File.write(DATA_FILE, JSON.pretty_generate(@data))
  end

  def next_id
    id = @data["next_id"]
    @data["next_id"] += 1
    save
    id
  end

  def create_entity(type:, title:, description:, story_points:, difficulty:)
    entity = {
      "id" => next_id,
      "type" => type,
      "title" => title,
      "description" => description,
      "story_points" => story_points,
      "difficulty" => difficulty,
      "created_at" => DateTime.now.to_s,
      "started_at" => nil,
      "completed_at" => nil,
      "comments" => []
    }
    @data["entities"] << entity
    save
    entity
  end

  def list_entities(type)
    @data["entities"].select { |e| e["type"] == type }
  end

  def find_entity(id)
    @data["entities"].find { |e| e["id"] == id }
  end

  def add_comment(entity_id:, content:)
    entity = find_entity(entity_id)
    raise "Entity #{entity_id} not found" unless entity
    comments = entity["comments"]
    comment_id = comments.empty? ? 1 : comments.last["id"] + 1
    comment = {
      "id" => comment_id,
      "content" => content,
      "created_at" => DateTime.now.to_s
    }
    comments << comment
    save
    comment
  end
end

def print_entity(entity)
  puts "ID: #{entity['id']}"
  puts "Type: #{entity['type']}"
  puts "Title: #{entity['title']}"
  puts "Description: #{entity['description']}"
  puts "Story Points: #{entity['story_points']}"
  puts "Difficulty: #{entity['difficulty']}"
  puts "Created At: #{entity['created_at']}"
  puts "Started At: #{entity['started_at']}"
  puts "Completed At: #{entity['completed_at']}"
  if entity['comments'] && !entity['comments'].empty?
    puts "Comments:"
    entity['comments'].each do |c|
      puts "  [#{c['id']}] #{c['created_at']}: #{c['content']}"
    end
  end
end

if ARGV.empty?
  puts "Usage: agile [epic|story|task|comment] [action] [options]"
  exit 1
end

command = ARGV.shift

case command
when 'epic', 'story', 'task'
  type = command
  action = ARGV.shift
  ds = DataStore.new

  case action
  when 'create'
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: agile #{type} create --title TITLE --description DESC --points N --difficulty N"
      opts.on("--title TITLE", "Title of the #{type}") { |v| options[:title] = v }
      opts.on("--description DESC", "Description") { |v| options[:description] = v }
      opts.on("--points N", Integer, "Story points") { |v| options[:story_points] = v }
      opts.on("--difficulty N", Integer, "Difficulty (engineering hours)") { |v| options[:difficulty] = v }
    end
    parser.parse!(ARGV)
    [:title, :description, :story_points, :difficulty].each do |opt|
      if options[opt].nil?
        puts "Missing --#{opt}"
        puts parser
        exit 1
      end
    end
    entity = ds.create_entity(type: type, title: options[:title], description: options[:description], story_points: options[:story_points], difficulty: options[:difficulty])
    puts "#{type.capitalize} created with ID #{entity['id']}"

  when 'list'
    entities = ds.list_entities(type)
    if entities.empty?
      plural = (type == 'story') ? 'stories' : "#{type}s"
      puts "No #{plural} found."
    else
      entities.each { |e| puts "[#{e['id']}] #{e['title']}" }
    end

  when 'show'
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: agile #{type} show --id ID"
      opts.on("--id ID", Integer, "ID of the #{type}") { |v| options[:id] = v }
    end
    parser.parse!(ARGV)
    unless options[:id]
      puts "Missing --id"
      puts parser
      exit 1
    end
    entity = ds.find_entity(options[:id])
    if entity && entity['type'] == type
      print_entity(entity)
    else
      puts "#{type.capitalize} with ID #{options[:id]} not found."
      exit 1
    end

  when 'start', 'complete'
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: agile #{type} #{action} --id ID"
      opts.on("--id ID", Integer, "ID of the #{type}") { |v| options[:id] = v }
    end
    parser.parse!(ARGV)
    unless options[:id]
      puts "Missing --id"
      puts parser
      exit 1
    end
    entity = ds.find_entity(options[:id])
    if entity && entity['type'] == type
      timestamp = DateTime.now.to_s
      field = action == 'start' ? 'started_at' : 'completed_at'
      entity[field] = timestamp
      ds.save
      verb = action == 'start' ? 'started' : 'completed'
      puts "#{type.capitalize} #{verb} at #{timestamp}"
    else
      puts "#{type.capitalize} with ID #{options[:id]} not found."
      exit 1
    end

  else
    puts "Unknown action '#{action}' for #{type}."
    puts "Available actions: create, list, show, start, complete"
    exit 1
  end

when 'comment'
  action = ARGV.shift
  ds = DataStore.new

  case action
  when 'add'
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: agile comment add --id ENTITY_ID --content TEXT"
      opts.on("--id ID", Integer, "Entity ID") { |v| options[:id] = v }
      opts.on("--content TEXT", "Comment text") { |v| options[:content] = v }
    end
    parser.parse!(ARGV)
    [:id, :content].each do |opt|
      if options[opt].nil?
        puts "Missing --#{opt}"
        puts parser
        exit 1
      end
    end
    comment = ds.add_comment(entity_id: options[:id], content: options[:content])
    puts "Comment added with ID #{comment['id']} to entity #{options[:id]}"

  when 'list'
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: agile comment list --id ENTITY_ID"
      opts.on("--id ID", Integer, "Entity ID") { |v| options[:id] = v }
    end
    parser.parse!(ARGV)
    unless options[:id]
      puts "Missing --id"
      puts parser
      exit 1
    end
    entity = ds.find_entity(options[:id])
    if entity
      comments = entity['comments']
      if comments.empty?
        puts "No comments for entity #{options[:id]}"
      else
        comments.each { |c| puts "[#{c['id']}] #{c['created_at']}: #{c['content']}" }
      end
    else
      puts "Entity with ID #{options[:id]} not found."
      exit 1
    end

  else
    puts "Unknown comment action '#{action}'."
    puts "Available actions: add, list"
    exit 1
  end

else
  puts "Unknown command '#{command}'."
  puts "Usage: agile [epic|story|task|comment] [action] [options]"
  exit 1
end