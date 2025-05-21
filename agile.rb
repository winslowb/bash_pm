#!/usr/bin/env ruby

require 'json'
require 'optparse'
require 'date'
require 'csv'

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

  def create_entity(type:, title:, description:, story_points:, difficulty:, assigned_to: nil)
    entity = {
      "id" => next_id,
      "type" => type,
      "title" => title,
      "description" => description,
      "story_points" => story_points,
      "difficulty" => difficulty,
      "assigned_to" => assigned_to,
      "status" => "to do",
      "archived" => false,
      "created_at" => DateTime.now.to_s,
      "started_at" => nil,
      "completed_at" => nil,
      "comments" => [],
      "epic_id" => nil,
      "story_id" => nil,
      "sprint_id" => nil
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
  def update_entity(id, attrs)
    entity = find_entity(id)
    raise "Entity #{id} not found" unless entity
    attrs.each { |k, v| entity[k.to_s] = v }
    save
    entity
  end

  def delete_entity(id)
    entity = find_entity(id)
    raise "Entity #{id} not found" unless entity
    @data["entities"].delete_if { |e| e["id"] == id }
    save
  end

  def archive_entity(id)
    entity = find_entity(id)
    raise "Entity #{id} not found" unless entity
    entity["archived"] = true
    save
    entity
  end

  def create_sprint(title:, description:, start_date:, end_date:)
    entity = {
      "id" => next_id,
      "type" => "sprint",
      "title" => title,
      "description" => description,
      "status" => "to do",
      "archived" => false,
      "start_date" => start_date,
      "end_date" => end_date,
      "created_at" => DateTime.now.to_s,
      "comments" => []
    }
    @data["entities"] << entity
    save
    entity
  end

  # Export data to JSON or CSV
  def export_data(format:, output:)
    case format
    when 'json'
      File.write(output, JSON.pretty_generate(@data))
    when 'csv'
      headers = %w[id type title description story_points difficulty status archived created_at started_at completed_at epic_id story_id sprint_id assigned_to]
      CSV.open(output, 'w') do |csv|
        csv << headers
        @data['entities'].each do |e|
          csv << headers.map { |h| e[h] }
        end
      end
    else
      raise "Unknown format: #{format}"
    end
  end

  # Generate summary metrics
  def report_metrics
    metrics = {}
    stats = {}
    %w[epic story task].each do |t|
      items = @data['entities'].select { |e| e['type'] == t }
      total = items.size
      to_do = items.count { |e| e['status'] == 'to do' }
      doing = items.count { |e| e['status'] == 'doing' }
      done = items.count { |e| e['status'] == 'done' }
      archived = items.count { |e| e['archived'] }
      points = items.map { |e| e['story_points'] || 0 }.sum
      diffs = items.map { |e| e['difficulty'] || 0 }
      avg_diff = diffs.empty? ? 0 : (diffs.sum.to_f / diffs.size).round(2)
      stats[t] = { total: total, to_do: to_do, doing: doing, done: done, archived: archived, story_points: points, average_difficulty: avg_diff }
    end
    metrics[:entity_stats] = stats

    tasks = @data['entities'].select { |e| e['type'] == 'task' }
    sprints = @data['entities'].select { |e| e['type'] == 'sprint' }
    per_sprint = {}
    sprints.each do |s|
      cnt = tasks.count { |t| t['sprint_id'] == s['id'] }
      per_sprint[s['id']] = { title: s['title'], count: cnt }
    end
    metrics[:tasks_per_sprint] = per_sprint

    per_assignee = {}
    tasks.each do |t|
      assignee = t['assigned_to'] || 'Unassigned'
      per_assignee[assignee] ||= 0
      per_assignee[assignee] += 1
    end
    metrics[:tasks_per_assignee] = per_assignee

    metrics
  end
end

def print_entity(entity)
  puts "ID: #{entity['id']}"
  puts "Type: #{entity['type']}"
  puts "Title: #{entity['title']}"
  puts "Assigned To: #{entity['assigned_to']}" if entity.key?('assigned_to') && entity['assigned_to']
  puts "Description: #{entity['description']}"
  puts "Status: #{entity['status']}" if entity.key?("status")
  puts "Archived: #{entity['archived']}" if entity.key?("archived")
  if entity["type"] == "sprint"
    puts "Start Date: #{entity['start_date']}"
    puts "End Date: #{entity['end_date']}"
    ds = DataStore.new
    stories = ds.list_entities("story").select { |s| s["sprint_id"] == entity["id"] }
    tasks = ds.list_entities("task").select do |t|
      t["sprint_id"] == entity["id"] ||
        (t["story_id"] && stories.map { |s| s["id"] }.include?(t["story_id"]))
    end
    unless stories.empty?
      puts "Stories in Sprint:"
      stories.each { |s| puts "  [#{s['id']}] #{s['title']}" }
    end
    unless tasks.empty?
      puts "Tasks in Sprint:"
      tasks.each { |t| puts "  [#{t['id']}] #{t['title']}" }
    end
  else
    puts "Story Points: #{entity['story_points']}" if entity.key?('story_points')
    puts "Difficulty: #{entity['difficulty']}" if entity.key?('difficulty')
    puts "Created At: #{entity['created_at']}" if entity.key?('created_at')
    puts "Started At: #{entity['started_at']}" if entity.key?('started_at')
    puts "Completed At: #{entity['completed_at']}" if entity.key?('completed_at')
    puts "Epic ID: #{entity['epic_id']}" if entity.key?('epic_id') && entity['epic_id']
    puts "Story ID: #{entity['story_id']}" if entity.key?('story_id') && entity['story_id']
    puts "Sprint ID: #{entity['sprint_id']}" if entity.key?('sprint_id') && entity['sprint_id']
    if entity['type'] == 'epic'
      ds = DataStore.new
      stories = ds.list_entities('story').select { |s| s['epic_id'] == entity['id'] }
      unless stories.empty?
        puts "Stories in Epic:"
        stories.each { |s| puts "  [#{s['id']}] #{s['title']}" }
      end
    end
    if entity['type'] == 'story'
      ds = DataStore.new
      tasks = ds.list_entities('task').select { |t| t['story_id'] == entity['id'] }
      unless tasks.empty?
        puts "Tasks in Story:"
        tasks.each { |t| puts "  [#{t['id']}] #{t['title']}" }
      end
    end
  end
  if entity['comments'] && !entity['comments'].empty?
    puts "Comments:"
    entity['comments'].each do |c|
      puts "  [#{c['id']}] #{c['created_at']}: #{c['content']}"
    end
  end
end

if ARGV.empty?
  puts "Usage: agile [epic|story|task|sprint|comment|report] [action] [options]"
  exit 1
end

command = ARGV.shift

case command
when 'epic', 'story', 'task', 'sprint'
  type = command
  action = ARGV.shift
  ds = DataStore.new

  case action
  when 'create'
    if type == 'sprint'
      options = {}
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: agile sprint create --title TITLE --description DESC --start DATE --end DATE"
        opts.on("--title TITLE", "Title of the sprint") { |v| options[:title] = v }
        opts.on("--description DESC", "Description") { |v| options[:description] = v }
        opts.on("--start DATE", "Start date (YYYY-MM-DD)") { |v| options[:start_date] = v }
        opts.on("--end DATE", "End date (YYYY-MM-DD)") { |v| options[:end_date] = v }
      end
      parser.parse!(ARGV)
      [:title, :description, :start_date, :end_date].each do |opt|
        if options[opt].nil?
          puts "Missing --#{opt.to_s.gsub('_','-')}"
          puts parser
          exit 1
        end
      end
      entity = ds.create_sprint(title: options[:title], description: options[:description], start_date: options[:start_date], end_date: options[:end_date])
      puts "Sprint created with ID #{entity['id']}"
    else
      options = {}
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: agile #{type} create --title TITLE --description DESC --points N --difficulty N"
        opts.on("--title TITLE", "Title of the #{type}") { |v| options[:title] = v }
        opts.on("--description DESC", "Description") { |v| options[:description] = v }
        opts.on("--points N", Integer, "Story points") { |v| options[:story_points] = v }
        opts.on("--difficulty N", Integer, "Difficulty (engineering hours)") { |v| options[:difficulty] = v }
        opts.on("--assigned-to ASSIGNEE", "Assign to person") { |v| options[:assigned_to] = v }
      end
      parser.parse!(ARGV)
      [:title, :description, :story_points, :difficulty].each do |opt|
        if options[opt].nil?
          puts "Missing --#{opt}"
          puts parser
          exit 1
        end
      end
      entity = ds.create_entity(type: type, title: options[:title], description: options[:description], story_points: options[:story_points], difficulty: options[:difficulty], assigned_to: options[:assigned_to])
      puts "#{type.capitalize} created with ID #{entity['id']}"
    end

  when 'list'
    if type == 'sprint'
      sprints = ds.list_entities('sprint').reject { |e| e['archived'] }
      if sprints.empty?
        puts "No sprints found."
      else
        sprints.each { |e| puts "[#{e['id']}] #{e['title']} (#{e['status']})" }
      end
    else
      entities = ds.list_entities(type).reject { |e| e['archived'] }
      if entities.empty?
        plural = (type == 'story') ? 'stories' : "#{type}s"
        puts "No #{plural} found."
      else
        entities.each { |e| puts "[#{e['id']}] #{e['title']} (#{e['status']})" }
      end
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
      ds.update_entity(options[:id], 'status' => action == 'start' ? 'doing' : 'done')
      ds.update_entity(options[:id], 'status' => action == 'start' ? 'doing' : 'done')
      verb = action == 'start' ? 'started' : 'completed'
      puts "#{type.capitalize} #{verb} at #{timestamp}"
    else
      puts "#{type.capitalize} with ID #{options[:id]} not found."
      exit 1
    end

  when 'link'
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: agile #{type} link --id ID [--epic EPIC_ID] [--story STORY_ID] [--sprint SPRINT_ID]"
      opts.on("--id ID", Integer, "ID of the #{type}") { |v| options[:id] = v }
      opts.on("--epic EPIC_ID", Integer, "Link to epic") { |v| options[:epic_id] = v }
      opts.on("--story STORY_ID", Integer, "Link to story") { |v| options[:story_id] = v }
      opts.on("--sprint SPRINT_ID", Integer, "Assign to sprint") { |v| options[:sprint_id] = v }
    end
    parser.parse!(ARGV)
    unless options[:id]
      puts "Missing --id"
      puts parser
      exit 1
    end
    ds.update_entity(options[:id], 'epic_id' => options[:epic_id]) if options[:epic_id]
    ds.update_entity(options[:id], 'story_id' => options[:story_id]) if options[:story_id]
    ds.update_entity(options[:id], 'sprint_id' => options[:sprint_id]) if options[:sprint_id]
    puts "#{type.capitalize} #{options[:id]} linked successfully."

  when 'assign'
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: agile #{type} assign --id ID --to ASSIGNEE"
      opts.on("--id ID", Integer, "ID of the #{type}") { |v| options[:id] = v }
      opts.on("--to ASSIGNEE", "User to assign to") { |v| options[:assigned_to] = v }
    end
    parser.parse!(ARGV)
    unless options[:id] && options[:assigned_to]
      puts "Missing --id or --to"
      puts parser
      exit 1
    end
    ds.update_entity(options[:id], 'assigned_to' => options[:assigned_to])
    puts "#{type.capitalize} #{options[:id]} assigned to #{options[:assigned_to]}"
  when 'archive'
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: agile #{type} archive --id ID"
      opts.on("--id ID", Integer, "ID of the #{type}") { |v| options[:id] = v }
    end
    parser.parse!(ARGV)
    unless options[:id]
      puts "Missing --id"
      puts parser
      exit 1
    end
    ds.archive_entity(options[:id])
    puts "#{type.capitalize} archived."

  when 'delete'
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: agile #{type} delete --id ID"
      opts.on("--id ID", Integer, "ID of the #{type}") { |v| options[:id] = v }
    end
    parser.parse!(ARGV)
    unless options[:id]
      puts "Missing --id"
      puts parser
      exit 1
    end
    ds.delete_entity(options[:id])
    puts "#{type.capitalize} deleted."

  else
    puts "Unknown action '#{action}' for #{type}."
    puts "Available actions: create, list, show, start, complete, link, archive, delete"
    exit 1
  end

when 'report'
  action = ARGV.shift
  ds = DataStore.new
  case action
  when 'metrics'
    metrics = ds.report_metrics
    puts "Entity Stats:"
    metrics[:entity_stats].each do |type, stat|
      puts "  #{type.capitalize}s: total #{stat[:total]} (to do: #{stat[:to_do]}, doing: #{stat[:doing]}, done: #{stat[:done]}, archived: #{stat[:archived]})"
      puts "    Story Points: #{stat[:story_points]}, Avg Difficulty: #{stat[:average_difficulty]}"
    end
    puts "\nTasks per Sprint:"
    metrics[:tasks_per_sprint].each do |id, info|
      puts "  [#{id}] #{info[:title]}: #{info[:count]}"
    end
    puts "\nTasks per Assignee:"
    metrics[:tasks_per_assignee].each do |assignee, count|
      puts "  #{assignee}: #{count}"
    end
  when 'export'
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: agile report export --format [json|csv] --output FILE"
      opts.on("--format FORMAT", "Export format (json or csv)") { |v| options[:format] = v }
      opts.on("--output FILE", "Output file path") { |v| options[:output] = v }
    end
    parser.parse!(ARGV)
    unless options[:format] && options[:output]
      puts "Missing --format or --output"
      puts parser
      exit 1
    end
    ds.export_data(format: options[:format], output: options[:output])
    puts "Data exported to #{options[:output]}"
  else
    puts "Unknown report action '#{action}'."
    puts "Available report actions: metrics, export"
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
  puts "Usage: agile [epic|story|task|sprint|comment|report] [action] [options]"
  exit 1
end