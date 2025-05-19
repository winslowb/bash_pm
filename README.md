# bash_pm: Agile/Scrum CLI Tool

This repository provides a simple command-line interface (CLI) for creating and managing Agile epics, stories, tasks, and comments. Data is stored locally in JSON format.

## Prerequisites
- Ruby (>= 2.5)
- Standard Ruby libraries: `json`, `optparse`, `date`

## Installation
1. Clone this repository and change into the project directory:
   ```bash
   git clone <repo-url>
   cd bash_pm
   ```
2. Make the main script executable:
   ```bash
   chmod +x agile.rb
   ```
3. (Optional) Add to your PATH for global use:
   ```bash
   ln -s $(pwd)/agile.rb /usr/local/bin/agile
   ```

## Usage
Run the `agile` command (or `ruby agile.rb`) with the following structure:
```bash
./agile.rb <entity> <action> [options]
```

### Entities and Actions
- **entity**: `epic`, `story`, `task`, `sprint`, `comment`
- **action** for `epic|story|task|sprint`:
  - `create`   Create a new item
  - `list`     List all items of that type
  - `show`     Show details for a single item
  - `start`    Mark the item as started (sets status to `doing`)
  - `complete` Mark the item as completed (sets status to `done`)
  - `link`     Link an item to an epic, story, or sprint
  - `archive`  Archive an item (it will be hidden from lists)
  - `delete`   Permanently delete an item
- **action** for `comment`:
  - `add`      Add a comment to an existing epic/story/task
  - `list`     List comments for a given entity

### Examples

#### Create an Epic
```bash
./agile.rb epic create \
  --title "Launch Website" \
  --description "Design and deploy corporate site" \
  --points 8 \
  --difficulty 5
```

#### List Epics
```bash
./agile.rb epic list
```

#### Show Epic Details
```bash
./agile.rb epic show --id 1
```

#### Start a Story
```bash
./agile.rb story start --id 2
```

#### Complete a Task
```bash
./agile.rb task complete --id 3
```

#### Add a Comment
```bash
./agile.rb comment add --id 2 --content "Needs UX review"
```

#### List Comments
```bash
./agile.rb comment list --id 2
```

#### Create a Sprint

```bash
./agile.rb sprint create \
  --title "Sprint 1" \
  --description "First development sprint" \
  --start 2025-05-01 \
  --end 2025-05-15
```

#### List Sprints

```bash
./agile.rb sprint list
```

#### Show Sprint Details

```bash
./agile.rb sprint show --id 1
```

#### Link a Story to an Epic/Sprint

```bash
./agile.rb story link --id 5 --epic 2 --sprint 1
```

#### Archive a Task

```bash
./agile.rb task archive --id 3
```

#### Delete an Epic

```bash
./agile.rb epic delete --id 4
```

#### View Backlog

Items not linked to a sprint will remain in the backlog. To view backlog items, list stories or tasks:

```bash
./agile.rb story list
./agile.rb task list
```

## Data Storage
- All data is saved to `agile_data.json` in the current working directory.
- The file is auto-generated on first run.

## Contributing & License
Feel free to fork and submit pull requests! No explicit license is set; add one if you wish to open-source this tool.