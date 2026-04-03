# Terminal Commands Reference

## List Project Folders

```bash
# List all directories in current location
ls -la

# List only directories (folders)
ls -d */

# List directories with details
ls -ld */

# Tree view of directory structure
tree

# List directories in /var/www (web server projects)
ls -la /var/www/

# List directories in home folder
ls -la ~/
```

## Move and Rename Directories

```bash
# Move a directory to another location
mv source_dir/ /path/to/destination/

# Move directory into another directory
mv my-project/ /var/www/

# Move multiple directories
mv dir1/ dir2/ /path/to/destination/

# Rename a directory
mv old_name/ new_name/

# Move and rename at the same time
mv old_dir/ /path/to/destination/new_name/

# Force move (overwrite without prompting)
mv -f source_dir/ /path/to/destination/

# Interactive mode (ask before overwriting)
mv -i source_dir/ /path/to/destination/

# Verbose mode (show what's being done)
mv -v source_dir/ /path/to/destination/
```

**Examples:**
```bash
# Rename folder from "brewapps-dev" to "brewapps-stage"
mv brewapps-dev/ brewapps-stage/

# Move project folder into /var/www/
mv my-project/ /var/www/

# Move and rename folder in one command
mv old-project/ /var/www/new-project/
```

**Important:** Use trailing slashes on directories to avoid accidents. The `mv` command can overwrite files without warning!

## Rename Files

```bash
# Rename a file in the current directory
mv old_name.txt new_name.txt

# Rename with full paths
mv /path/to/old_name.txt /path/to/new_name.txt

# Move file to another directory (keeps same name)
mv file.txt /path/to/destination/

# Move and rename at the same time
mv old.txt /path/to/destination/new.txt

# Rename multiple files (requires loop or other tools)
for file in *.txt; do mv "$file" "${file%.txt}.bak"; done
```

**Examples:**
```bash
# Rename config file
mv config.example.yml config.yml

# Rename with backup extension
mv index.html index.html.bak

# Move to parent directory and rename
mv data.json ../backup-data.json
```

**Tip:** Same as directories - use `mv` command. Files don't need trailing slashes.

## Remove Directories

```bash
# Remove empty directory
rmdir empty_dir/

# Remove directory and all contents (recursive)
rm -r my_dir/

# Force remove directory without prompting (DANGEROUS!)
rm -rf my_dir/

# Interactive mode - ask before removing each file
rm -ri my_dir/

# Verbose mode - show what's being removed
rm -rv my_dir/

# Remove directory and contents, but ask once
rm -rI my_dir/
```

**Examples:**
```bash
# Remove empty directory
rmdir old_project/

# Remove directory and all files inside
rm -r /var/www/old-project/

# Remove with confirmation for each file
rm -ri /var/www/my-project/

# Remove multiple directories
rm -r dir1/ dir2/ dir3/
```

**⚠️ DANGER - BE CAREFUL!**

- `rm -rf /` - Will delete your entire system!
- `rm -rf /var/www/` - Will delete all websites!
- Always double-check the path before pressing Enter
- Use `ls` first to verify what you're deleting
- Consider moving to trash instead: `mv my_dir/ ~/.Trash/`

**Safe deletion workflow:**
```bash
# 1. First, see what's inside
ls -la my_dir/

# 2. Remove with interactive flag (asks for each file)
rm -ri my_dir/

# 3. Or move to a trash folder first
mkdir -p ~/.trash
mv my_dir/ ~/.trash/
```
